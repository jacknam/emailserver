#!/bin/bash

DBDRIVER=${DBDRIVER:-mysql}
DBNAME=${DBNAME:-postfix}
DBUSER=${DBUSER:-postfix}
DBHOST=${DBHOST:-mariadb}
DBPORT=${DBPORT:-3306}
DBPASS=${DBPASS:-postfix}
DOMAIN=${DOMAIN:-$(hostname -d)}

if [ ! -d "/etc/rainloop/public" ] || [ ! -d "/etc/rainloop/data" ]; then
 echo "[Error] Rainloop is not installed properly"
 exit 1
fi

DATA_VERSION=$(cat /etc/rainloop/data/VERSION 2>/dev/null | xargs)
VERSION=$(cat /etc/rainloop/VERSION 2>/dev/null | xargs)

if [ -z "${VERSION}" ] || [ "${VERSION}" != "${DATA_VERSION}" ] || [ ! -d "/etc/rainloop/public/rainloop/v/${VERSION}" ]; then
 echo "[Error] Rainloop version is invalid"
 exit 1
fi


mkdir -p /etc/rainloop/data/_data_/_default_/configs /etc/rainloop/data/_data_/_default_/domains

if [ ! -f /etc/rainloop/data/_data_/_default_/configs/application.ini ]; then
 if [ -f /etc/rainloop/config.php ]; then
  php -r "include '/etc/rainloop/config.php';"
 fi
fi

if [ -f /etc/rainloop/data/_data_/_default_/configs/application.ini ]; then
 if [ ! -e /etc/rainloop/data/_data_/_default_/configs/application.ini.fixed ]; then
  touch /etc/rainloop/data/_data_/_default_/configs/application.ini.fixed
  rand_pw=$(openssl rand -base64 32 | md5sum | awk '{ print $1; }')
  sed -i -r -e "s/^admin_login(\s?)=.*/admin_login = \"_admin_fixed_\"/" \
   -e "s/^admin_password(\s?)=.*/admin_password = \"${rand_pw}\"/" \
   -e "s/^allow_admin_panel(\s?)=.*/allow_admin_panel = Off/" \
   /etc/rainloop/data/_data_/_default_/configs/application.ini
 fi
fi

ADMIN_SET="allow_admin_panel = Off"
if [ -f /etc/rainloop/.admin ]; then
 source /etc/rainloop/.admin
 if [ -n "${admin_login}" ] && [ -n "${admin_password}" ]; then
read -r -d '' ADMIN_SET <<-EOL || true
admin_login = '${admin_login}'
admin_password = '${admin_password}'
allow_admin_panel = On
EOL
 fi
fi

cat > /etc/rainloop/data/_data_/_default_/configs/docker.ini <<EOF
[webmail]
title = "$(echo ${DOMAIN} | awk '{ print toupper($0); }') Webmail"
loading_description = "Loading"
theme = "Clear"
language = "ko_KR"
language_admin = "en"

[contacts]
enable = ON
pdo_dsn = "${DBDRIVER}:host=${DBHOST};port=${DBPORT};dbname=rainloop"
pdo_user = "rainloop"
pdo_password = "${DBPASS}"

[security]
${ADMIN_SET}

[login]
default_domain = "${DOMAIN}"
forgot_password_link_url = ""

[plugins]
enable = ON
enabled_list = "postfixadmin-change-password"

[logs]
enable = ON
write_on_error_only = ON
write_on_php_error_only = ON
auth_logging = ON
auth_logging_filename = "fail2ban/auth-{date:Y-m-d}.txt"
auth_logging_format = "[{date:Y-m-d H:i:s}] Auth failed: ip={request:ip} user={imap:login} host={imap:host} port={imap:port}"
EOF

cat > /etc/rainloop/data/_data_/_default_/domains/${DOMAIN}.ini <<EOF
imap_host = "localhost"
imap_port = 993
imap_short_login = Off
sieve_use = On
sieve_allow_raw = On
sieve_host = "localhost"
sieve_port = 4190
smtp_host = "localhost"
smtp_port = 587
smtp_short_login = Off
smtp_auth = On
smtp_php_mail = Off
EOF

if [[ "${DBDRIVER}" == "mysql"* ]]; then
 DBENGINE="MySQL"
elif [ "${DBDRIVER}" = "pgsql" ]; then
 DBENGINE="PostgreSQL"
fi

if [ -n "${DBENGINE}" ]; then
cat > /etc/rainloop/data/_data_/_default_/configs/plugin-postfixadmin-change-password.ini <<EOF
[plugin]
engine = "${DBENGINE}"
host = "${DBHOST}"
port = ${DBPORT}
database = "${DBNAME}"
table = "mailbox"
usercol = "username"
passcol = "password"
user = "${DBUSER}"
password = "${DBPASS}"
encrypt = "md5crypt"
allowed_emails = "*"
EOF
fi

mkdir -p /etc/rainloop/sessions
chown -R rainloop:rainloop /etc/rainloop/public /etc/rainloop/data /etc/rainloop/sessions /var/mail/rainloop/data /var/mail/rainloop/static /var/mail/rainloop/themes

exit 0
