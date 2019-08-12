#!/bin/bash

DBDRIVER=${DBDRIVER:-mysql}
DBHOST=${DBHOST:-mariadb}
DBPORT=${DBPORT:-3306}

if [ ! -d "/etc/phpmyadmin/public" ]; then
 echo "[Error] PhpMyAdmin is not installed properly"
 exit 1
fi

if [[ "${DBDRIVER}" != "mysql"* ]]; then
 echo "[Note] Not using Mysql/MariaDB!"
 exit 1
fi

if ! cat /etc/phpmyadmin/config.secret.inc.php 2>/dev/null | grep -q "blowfish_secret"; then
cat > /etc/phpmyadmin/config.secret.inc.php <<EOF
<?php
\$cfg['blowfish_secret'] = '$(openssl rand -base64 32)';
EOF
fi

PMA_DB=""
if [ -e /etc/mysql/docker/pmadb_installation ]; then
read -r -d '' PMA_DB <<-EOL || true
\$cfg['Servers'][1]['pmadb'] = 'phpmyadmin';
\$cfg['Servers'][1]['controlhost'] = '127.0.0.1';
\$cfg['Servers'][1]['controlport'] = '3306';
\$cfg['Servers'][1]['controluser'] = 'phpmyadmin';
\$cfg['Servers'][1]['controlpass'] = 'phpmyadmin';
\$cfg['Servers'][1]['relation'] = 'pma__relation';
\$cfg['Servers'][1]['table_info'] = 'pma__table_info';
\$cfg['Servers'][1]['table_coords'] = 'pma__table_coords';
\$cfg['Servers'][1]['pdf_pages'] = 'pma__pdf_pages';
\$cfg['Servers'][1]['column_info'] = 'pma__column_info';
\$cfg['Servers'][1]['bookmarktable'] = 'pma__bookmark';
\$cfg['Servers'][1]['history'] = 'pma__history';
\$cfg['Servers'][1]['recent'] = 'pma__recent';
\$cfg['Servers'][1]['favorite'] = 'pma__favorite';
\$cfg['Servers'][1]['table_uiprefs'] = 'pma__table_uiprefs';
\$cfg['Servers'][1]['tracking'] = 'pma__tracking';
\$cfg['Servers'][1]['userconfig'] = 'pma__userconfig';
\$cfg['Servers'][1]['users'] = 'pma__users';
\$cfg['Servers'][1]['usergroups'] = 'pma__usergroups';
\$cfg['Servers'][1]['navigationhiding'] = 'pma__navigationhiding';
\$cfg['Servers'][1]['savedsearches'] = 'pma__savedsearches';
\$cfg['Servers'][1]['central_columns'] = 'pma__central_columns';
\$cfg['Servers'][1]['designer_settings'] = 'pma__designer_settings';
\$cfg['Servers'][1]['export_templates'] = 'pma__export_templates';
EOL
fi

cat > /etc/phpmyadmin/config.inc.php <<EOF
<?php
require('/etc/phpmyadmin/config.secret.inc.php');

\$cfg['AllowArbitraryServer'] = false;
\$cfg['QueryHistoryDB'] = false;
\$cfg['UploadDir'] = '/etc/phpmyadmin/upload';
\$cfg['SaveDir'] = '/etc/phpmyadmin/save';
\$cfg['Servers'][1]['host'] = '${DBHOST}';
\$cfg['Servers'][1]['port'] = '${DBPORT}';
\$cfg['Servers'][1]['auth_type'] = 'cookie';
\$cfg['Servers'][1]['compress'] = false;
\$cfg['Servers'][1]['AllowNoPassword'] = false;
${PMA_DB}

if (file_exists('/etc/phpmyadmin/config.user.inc.php')) {
 include('/etc/phpmyadmin/config.user.inc.php');
}
EOF

mkdir -p /etc/phpmyadmin/sessions /etc/phpmyadmin/upload /etc/phpmyadmin/save
chown -R phpmyadmin:phpmyadmin /etc/phpmyadmin/public /etc/phpmyadmin/sessions /etc/phpmyadmin/upload /etc/phpmyadmin/save

exit 0
