#!/bin/bash

SMTPHOST=postfixadmin
DOMAIN=${DOMAIN:-$(hostname -d)}
DBDRIVER=${DBDRIVER:-mysql}
DBHOST=${DBHOST:-mariadb}
DBPORT=${DBPORT:-3306}
DBUSER=${DBUSER:-postfix}
DBNAME=${DBNAME:-postfix}
DBPASS=${DBPASS:-}
ENCRYPTION=${ENCRYPTION:-"dovecot:SHA512-CRYPT"}
FETCHMAIL_EXTRA_OPTIONS=${FETCHMAIL_EXTRA_OPTIONS:-"NO"}
PASSVAL_MIN_LEN=${PASSVAL_MIN_LEN:-5}
PASSVAL_MIN_CHAR=${PASSVAL_MIN_CHAR:-3}
PASSVAL_MIN_DIGIT=${PASSVAL_MIN_DIGIT:-2}
PAGE_SIZE=${PAGE_SIZE:-10}
QUOTA_MULTIPLIER=${QUOTA_MULTIPLIER:-1024000}

if [ ! -d "/etc/postfixadmin" ]; then
 echo "[Error] Postfixadmin is not installed properly"
 exit 1
fi

if [ -z "$DBPASS" ]; then
 echo "[Error] MariaDB/PostgreSQL database password must be set!"
 exit 1
fi

if [ "$DBDRIVER" = "mysql" ]; then
 DBDRIVER=mysqli;
fi

# Local postfixadmin configuration file
cat > /etc/postfixadmin/config.local.php <<EOF
<?php
\$CONF['configured'] = true;
\$CONF['database_type'] = '${DBDRIVER}';
\$CONF['database_host'] = '${DBHOST}';
\$CONF['database_user'] = '${DBUSER}';
\$CONF['database_password'] = '${DBPASS}';
\$CONF['database_name'] = '${DBNAME}';
\$CONF['database_port'] = '${DBPORT}';
\$CONF['encrypt'] = '${ENCRYPTION}';
\$CONF['dovecotpw'] = "/usr/bin/doveadm pw";
\$CONF['smtp_server'] = '${SMTPHOST}';
\$CONF['domain_path'] = 'YES';
\$CONF['domain_in_mailbox'] = 'NO';
\$CONF['fetchmail'] = 'YES';
\$CONF['fetchmail_extra_options'] = '${FETCHMAIL_EXTRA_OPTIONS}';
\$CONF['sendmail'] = 'YES';
\$CONF['admin_email'] = 'postfixadmin@${DOMAIN}';
\$CONF['footer_text'] = 'Return to ${DOMAIN}';
\$CONF['footer_link'] = 'http://${DOMAIN}';
\$CONF['default_aliases'] = array (
 'abuse'      => 'abuse@${DOMAIN}',
 'hostmaster' => 'hostmaster@${DOMAIN}',
 'postmaster' => 'postmaster@${DOMAIN}',
 'webmaster'  => 'webmaster@${DOMAIN}'
);
\$CONF['quota'] = 'YES';
\$CONF['domain_quota'] = 'YES';
\$CONF['quota_multiplier'] = '${QUOTA_MULTIPLIER}';
\$CONF['used_quotas'] = 'YES';
\$CONF['new_quota_table'] = 'YES';
\$CONF['aliases'] = '0';
\$CONF['mailboxes'] = '0';
\$CONF['maxquota'] = '0';
\$CONF['domain_quota_default'] = '0';
\$CONF['password_validation'] = array(
 '/.{${PASSVAL_MIN_LEN}}/' => 'password_too_short ${PASSVAL_MIN_LEN}',
 '/([a-zA-Z].*){${PASSVAL_MIN_CHAR}}/' => 'password_no_characters ${PASSVAL_MIN_CHAR}',
 '/([0-9].*){${PASSVAL_MIN_DIGIT}}/' => 'password_no_digits ${PASSVAL_MIN_DIGIT}',
);
\$CONF['page_size'] = '${PAGE_SIZE}';
?>
EOF

mkdir -p /etc/postfixadmin/templates_c /etc/postfixadmin/sessions
chown -R postfixadmin:postfixadmin /etc/postfixadmin/templates_c /etc/postfixadmin/sessions /etc/postfixadmin/public

exit 0
