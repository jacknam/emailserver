#!/bin/bash

rspamd_local_setup() {
 [ ! -d "/etc/rspamd/local.d" ] && return 1

 local local_path="/var/mail/rspamd/local.d"
 mkdir -p $local_path
 chown -R _rspamd:_rspamd $local_path
 chmod 750 $local_path

 echo "#Local from blacklist" > $local_path/local_bl_from.map.inc
 echo "#Local ip blacklist" > $local_path/local_bl_ip.map.inc
 echo "#Local rcpt blacklist" > $local_path/local_bl_rcpt.map.inc
 echo "#Local from whitelist" > $local_path/local_wl_from.map.inc
 echo "#Local ip whitelist" > $local_path/local_wl_ip.map.inc
 echo "#Local rcpt whitelist" > $local_path/local_wl_rcpt.map.inc
 chmod o+w $local_path/local_bl_from.map.inc
 chmod o+w $local_path/local_bl_ip.map.inc
 chmod o+w $local_path/local_bl_rcpt.map.inc
 chmod o+w $local_path/local_wl_from.map.inc
 chmod o+w $local_path/local_wl_ip.map.inc
 chmod o+w $local_path/local_wl_rcpt.map.inc

 return 0
}

redis_setup() {
 [ ! -f "/etc/redis/redis.conf" ] && return 1

 if [ -d "/var/mail/redis" ]; then
  rm -rf /var/lib/redis
 else
  if [ -d "/var/lib/redis" ]; then
   mv /var/lib/redis /var/mail/redis
  else
   mkdir -p /var/mail/redis
  fi
 fi

 rm -rf /var/lib/redis
 ln -s /var/mail/redis /var/lib/redis
 touch /var/lib/redis/appendonly.aof
 chown -R redis:redis /var/mail/redis
 redis-check-aof --fix /var/lib/redis/appendonly.aof

 return 0
}

mariadb_setup() {
 [ ! -f "/etc/mysql/mariadb.cnf" ] && return 1

 if [ -d "/var/mail/mysql" ]; then
  rm -rf /var/lib/mysql
 else
  if [ -d "/var/lib/mysql" ]; then
   mv /var/lib/mysql /var/mail/mysql
  else
   mkdir -p /var/mail/mysql
  fi
 fi

 rm -rf /var/lib/mysql
 ln -s /var/mail/mysql /var/lib/mysql
 chown -R mysql:mysql /var/mail/mysql

 if [ ! -d "/var/mail/mysql/mysql" ]; then
  local installArgs=( --datadir="/var/mail/mysql" --rpm )
  if { mysql_install_db --help || :; } | grep -q -- '--auth-root-authentication-method'; then
   installArgs+=( --auth-root-authentication-method=normal )
  fi
  mysql_install_db "${installArgs[@]}"
 fi

cat > /etc/mysql/mariadb.conf.d/51-mysqld-docker.cnf <<EOF
[mysqld]
port = 3306
datadir = /var/mail/mysql
EOF

 return 0
}

phpmyadmin_setup() {
 [ ! -f "/etc/phpmyadmin/public/index.php" ] && return 1
 mkdir -p /var/mail/phpmyadmin/public

 local files="php.ini config.user.inc.php"
 for file in ${files}; do
  if [ -f "/var/mail/phpmyadmin/${file}" ]; then
   rm -f "/etc/phpmyadmin/${file}"
  else
   if [ -f "/etc/phpmyadmin/${file}" ]; then
    mv "/etc/phpmyadmin/${file}" "/var/mail/phpmyadmin/${file}"
   else
    touch "/var/mail/phpmyadmin/${file}"
   fi
  fi
  ln -s "/var/mail/phpmyadmin/${file}" "/etc/phpmyadmin/${file}"
 done

 local folders="upload save public/themes public/locale"
 for folder in ${folders}; do
  if [ -d "/var/mail/phpmyadmin/${folder}" ]; then
   rm -rf "/etc/phpmyadmin/${folder}"
  else
   if [ -d "/etc/phpmyadmin/${folder}" ]; then
    mv "/etc/phpmyadmin/${folder}" "/var/mail/phpmyadmin/${folder}"
   else
    mkdir -p "/var/mail/phpmyadmin/${folder}"
   fi
  fi
  ln -s "/var/mail/phpmyadmin/${folder}" "/etc/phpmyadmin/${folder}"
  chown -R phpmyadmin:phpmyadmin "/var/mail/phpmyadmin/${folder}"
 done

 return 0
}

rainloop_setup() {
 [ ! -f "/etc/rainloop/public/index.php" ] && return 1
 local VERSION=$(cat /etc/rainloop/VERSION 2>/dev/null | xargs)
 [ -z "${VERSION}" ] && return 1
 mkdir -p /var/mail/rainloop

 local files="php.ini VERSION .admin"
 for file in ${files}; do
  if [ -f "/var/mail/rainloop/${file}" ]; then
   rm -f "/etc/rainloop/${file}"
  else
   if [ -f "/etc/rainloop/${file}" ]; then
    mv "/etc/rainloop/${file}" "/var/mail/rainloop/${file}"
   else
    touch "/var/mail/rainloop/${file}"
   fi
  fi
  ln -s "/var/mail/rainloop/${file}" "/etc/rainloop/${file}"
 done

 local folders="data"
 for folder in ${folders}; do
  if [ -d "/var/mail/rainloop/${folder}" ]; then
   rm -rf "/etc/rainloop/${folder}"
  else
   if [ -d "/etc/rainloop/${folder}" ]; then
    mv "/etc/rainloop/${folder}" "/var/mail/rainloop/${folder}"
   else
    mkdir -p "/var/mail/rainloop/${folder}"
   fi
  fi
  ln -s "/var/mail/rainloop/${folder}" "/etc/rainloop/${folder}"
  chown -R rainloop:rainloop "/var/mail/rainloop/${folder}"
 done

 local static_folders="themes static"
 for folder in ${static_folders}; do
  if [ -d "/var/mail/rainloop/${folder}/${VERSION}" ]; then
   rm -rf "/etc/rainloop/public/rainloop/v/${VERSION}/${folder}"
  else
   if [ -d "/etc/rainloop/public/rainloop/v/${VERSION}/${folder}" ]; then
    mkdir -p "/var/mail/rainloop/${folder}"
    mv "/etc/rainloop/public/rainloop/v/${VERSION}/${folder}" "/var/mail/rainloop/${folder}/${VERSION}"
   else
    mkdir -p "/var/mail/rainloop/${folder}/${VERSION}"
   fi
  fi
  ln -s "/var/mail/rainloop/${folder}/${VERSION}" "/etc/rainloop/public/rainloop/v/${VERSION}/${folder}"
  chown -R rainloop:rainloop "/var/mail/rainloop/${folder}"
 done

 if [ ! -f /etc/rainloop/public/include.php ]; then
cat > /etc/rainloop/public/include.php <<EOF
<?php
function __get_custom_data_full_path() {
 return '/etc/rainloop/data';
}

function __get_additional_configuration_name() {
 return 'docker.ini';
}
EOF
 fi

 return 0
}

if [ ! -f "/etc/configuration_built_extra" ]; then
 touch "/etc/configuration_built_extra"
 rspamd_local_setup
 redis_setup
 mariadb_setup
 phpmyadmin_setup
 rainloop_setup
fi

echo "[INFO] Finished extra setup"
