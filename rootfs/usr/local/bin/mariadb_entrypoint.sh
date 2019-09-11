#!/bin/bash

DBNAME=${DBNAME:-postfix}
DBUSER=${DBUSER:-postfix}
DBPASS=${DBPASS:-postfix}
ADMINIP=${ADMINIP:-}
SQLPATH=/etc/mysql/docker
CLIENT_CNF=/etc/mysql/debian.cnf
ROOTPASS=""
EXECSQL=""
DUMPDB=""

get_config() {
 local conf="$1"
 mysqld --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" && /^[^ \t]/ { sub(/^[^ \t]+[ \t]+/, ""); print; exit }'
}

get_rootpass() {
 ROOTPASS=$(cat ${CLIENT_CNF} 2>/dev/null | grep "^password\s*=" | head -1 | cut -d"=" -f2- | xargs)
 if [ -z "${ROOTPASS}" ]; then
  ROOTPASS=$(openssl rand -base64 32)
cat > "${CLIENT_CNF}" <<EOF
[client]
host     = localhost
user     = root
password = "${ROOTPASS}"
socket   = /var/run/mysqld/mysqld.sock
[mysql_upgrade]
host     = localhost
user     = root
password = "${ROOTPASS}"
socket   = /var/run/mysqld/mysqld.sock
basedir  = /usr
EOF
 fi

 return 0
}

secure_installation() {
 [ -e "${SQLPATH}/mysql_secure_installation" ] && return 0
 touch "${SQLPATH}/mysql_secure_installation"

 local tmp_sql=""
read -r -d '' tmp_sql <<-EOSQL || true
DELETE FROM mysql.user WHERE USER='root' AND HOST NOT IN ('localhost') ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${ROOTPASS}') ;
GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
DROP DATABASE IF EXISTS test ;
DELETE FROM mysql.user WHERE User NOT IN ('mysql.sys', 'mysqlxsys', 'root') AND (User='' OR Password='') ;
EOSQL

 EXECSQL+="${tmp_sql}"$'\n'
 return 0
}

admin_access() {
 local PWFILE="${SQLPATH}/admin_pw_setup"
 local admin_pw=$(cat "${PWFILE}" 2>/dev/null | xargs)
 rm -rf "${PWFILE}"

 local IDFILE="${SQLPATH}/admin_id"
 local admin_id=$(cat "${IDFILE}" 2>/dev/null | xargs)
 if [ -z "${admin_id}" ]; then
  echo "[Error] Admin ID is not set!"
  return 1
 fi

 if [ -n "${admin_pw}" ]; then
read -r -d '' pw_sql <<-EOSQL || true
CREATE USER IF NOT EXISTS '${admin_id}'@'localhost' IDENTIFIED BY '${admin_pw}' ;
UPDATE mysql.user SET authentication_string=PASSWORD('${admin_pw}') WHERE User='${admin_id}' AND Host='localhost' ;
GRANT ALL ON *.* TO '${admin_id}'@'localhost' WITH GRANT OPTION ;
EOSQL
  EXECSQL+="${pw_sql}"$'\n'
 fi

 local tmp_sql=""
 local IPFILE="${SQLPATH}/admin_ip"
 local admin_ip=$(cat "${IPFILE}" 2>/dev/null | xargs)

 if [ -z "${ADMINIP}" ]; then
  if [ -n "${admin_ip}" ]; then
   tmp_sql="DROP USER '${admin_id}'@'${admin_ip}' ;"
   rm -f "${IPFILE}"
  fi
 else
  ADMINIP=$([ "${ADMINIP}" = "%" ] && echo "%" || echo "${ADMINIP}" | grep -oE "[1-9]{1}[0-9]{0,2}\.([0-9]{1,3}\.){2}[1-9%]{1}[0-9]{0,2}")
  if [ -z "${ADMINIP}" ]; then
   echo "[Error] Admin Remote IP is invalid!"
   return 1
  fi

  if [ -n "${admin_pw}" ]; then
read -r -d '' pw_sql <<-EOSQL || true
CREATE USER IF NOT EXISTS '${admin_id}'@'${ADMINIP}' IDENTIFIED BY '${admin_pw}' ;
UPDATE mysql.user SET authentication_string=PASSWORD('${admin_pw}') WHERE User='${admin_id}' AND Host='${ADMINIP}' ;
GRANT ALL ON *.* TO '${admin_id}'@'${ADMINIP}' WITH GRANT OPTION ;
EOSQL
  EXECSQL+="${pw_sql}"$'\n'
  fi

  if [ -z "${admin_ip}" ]; then
   if [ -n "${admin_pw}" ]; then
    echo "${ADMINIP}" > "${IPFILE}"
   fi
  else
   if [ "${admin_ip}" != "${ADMINIP}" ]; then
    tmp_sql="RENAME USER '${admin_id}'@'${admin_ip}' TO '${admin_id}'@'${ADMINIP}' ;"
    echo "${ADMINIP}" > "${IPFILE}"
   fi
  fi
 fi

 if [ -n "${tmp_sql}" ]; then
  EXECSQL+="${tmp_sql}"$'\n'
 fi

 return 0
}

create_db() {
 local PASSFILE="${SQLPATH}/db_pass"
 local pass_change=false
 local db_pass=$(cat "${PASSFILE}" 2>/dev/null | xargs)
 local md5_pass=$(echo "${DBPASS}" | md5sum | xargs)
 if [ -z "${db_pass}" ] || [ "${db_pass}" != "${md5_pass}" ]; then
  pass_change=true
  echo "${md5_pass}" > "${PASSFILE}"
  chmod 640 "${PASSFILE}"
 fi

 local changed=false
 local DBINFO=""
 local db_info=""
 local sql=""
 local tmp_sql=""
 local dump_sql="${SQLPATH}/dump_sql.sql"
 local name=""
 local user=""
 local extra_db="postfix rainloop"

 for db in ${extra_db}; do
  changed=false
  name=$([ "${db}" = "postfix" ] && echo "${DBNAME}" || echo "${db}")
  user=$([ "${db}" = "postfix" ] && echo "${DBUSER}" || echo "${db}")

  DBINFO="${SQLPATH}/${db}.db"
  db_info=($(cat "${DBINFO}" 2>/dev/null | xargs))
  if [ -z "${db_info}" ]; then
   echo "${name} ${user}" > "${DBINFO}"
read -r -d '' tmp_sql <<-EOSQL || true
CREATE DATABASE IF NOT EXISTS \`${name}\` ;
CREATE USER IF NOT EXISTS '${user}'@'localhost' IDENTIFIED BY '${DBPASS}' ;
GRANT ALL ON \`${name}\`.* TO '${user}'@'localhost' ;
EOSQL
   sql+="${tmp_sql}"$'\n'
  else
   if [ "${db}" = "postfix" ]; then
    if [ "${db_info[0]}" != "${name}" ]; then
     DUMPDB="${db_info[0]}"
read -r -d '' tmp_sql <<-EOSQL || true
CREATE DATABASE IF NOT EXISTS \`${name}\` ;
GRANT ALL ON \`${name}\`.* TO '${user}'@'localhost' ;
EOSQL
     sql+="${tmp_sql}"$'\n'
     changed=true
    fi

    if [ "${db_info[1]}" != "${user}" ]; then
     sql+="RENAME USER '${db_info[1]}'@'localhost' TO '${user}'@'localhost' ;"$'\n'
     changed=true
    fi

    if [ "${changed}" = true ]; then
     echo "${name} ${user}" > "${DBINFO}"
    fi
   fi

   if [ "$pass_change" = true ]; then
    sql+="UPDATE mysql.user SET authentication_string=PASSWORD('${DBPASS}') WHERE User='${user}' AND Host='localhost' ;"$'\n'
   fi
  fi
 done

 [ -z "${sql}" ] && return 0
 EXECSQL+="${sql}"$'\n'

 return 0
}

create_pmadb() {
 [ -e "${SQLPATH}/pmadb_installation" ] && return 0
 touch "${SQLPATH}/pmadb_installation"

 local pma_sql="/etc/phpmyadmin/public/sql/create_tables.sql"
 local tmp_sql=$(cat "${pma_sql}" 2>/dev/null | grep -v "^-" | grep -v "^$")
 [ -z "${tmp_sql}" ] && return 1

 EXECSQL+="${tmp_sql}"$'\n'

read -r -d '' tmp_sql <<-EOSQL || true
CREATE USER IF NOT EXISTS 'phpmyadmin'@'localhost' IDENTIFIED BY 'phpmyadmin' ;
GRANT ALL ON \`phpmyadmin\`.* TO 'phpmyadmin'@'localhost' ;
EOSQL
 EXECSQL+="${tmp_sql}"$'\n'

 return 0
}

[ ! -e /etc/mysql/mariadb.cnf ] && exit 1
DATADIR="$(get_config 'datadir' | sed 's/\/$//')"
[ ! -d "$DATADIR/mysql" ] && exit 1
chown -R mysql:mysql /var/mail/mysql

[ ! -d "${SQLPATH}" ] && mkdir -p "${SQLPATH}"
get_rootpass
secure_installation
admin_access
create_db
create_pmadb
[ -z "${EXECSQL}" ] && exit 0
EXECSQL+="FLUSH PRIVILEGES ;"

INITFILE="${SQLPATH}/init_file"
cat > "${INITFILE}" <<EOF
UPDATE mysql.user SET authentication_string=PASSWORD('${ROOTPASS}'),password_expired='N',plugin='mysql_native_password' WHERE User='root' AND Host='localhost' ;
FLUSH PRIVILEGES ;
EOF

SOCKET="$(get_config 'socket')"
mysqld --user=root --skip-networking --socket="${SOCKET}" --init-file="${INITFILE}" &
pid="$!"
mysql=( mysql --protocol=socket -uroot -p"${ROOTPASS}" -hlocalhost --socket="${SOCKET}" )

for i in {30..0}; do
 if echo "SELECT 1" | "${mysql[@]}" &> /dev/null; then
  break
 fi
 echo "[Info] MySQL init process in progress..."
 sleep 1
done

if [ "$i" = 0 ]; then
 echo >&2 "[Note] MySQL init process failed."
else
 echo "${EXECSQL}" | "${mysql[@]}" >/dev/null 2>&1
 if [ -n "${DUMPDB}" ]; then
  dump_sql="${SQLPATH}/${DUMPDB}_dump.sql"
  mysqldump --defaults-file="${CLIENT_CNF}" "${DUMPDB}" > "${dump_sql}"
  "${mysql[@]}" "${DBNAME}" < "${dump_sql}" >/dev/null 2>&1
  echo "DROP DATABASE IF EXISTS \`${DUMPDB}\` ;" | "${mysql[@]}"
 fi
 if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
  mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
 fi
 mysqladmin --defaults-file="${CLIENT_CNF}" --shutdown_timeout=5 shutdown 2>&1
fi

kill -s TERM "$pid" || ! wait "$pid"
rm -f "${INITFILE}"

exit 0
