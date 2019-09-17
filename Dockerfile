FROM debian:buster-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_CORES

ARG SKALIBS_VER=2.8.1.0
ARG EXECLINE_VER=2.5.1.0
ARG S6_VER=2.8.0.1
ARG RSPAMD_VER=1.9.4
ARG GUCCI_VER=1.2.1
ARG PFA_VER=3.2
ARG PMA_VER=4.9.0.1
ARG MARIADB_VER=10.4
ARG RAINLOOP_VER=1.13.0

ARG SKALIBS_SHA256_HASH="431c6507b4a0f539b6463b4381b9b9153c86ad75fa3c6bfc9dc4722f00b166ba"
ARG EXECLINE_SHA256_HASH="b1a756842947488404db8173bbae179d6e78b6ef551ec683acca540ecaf22677"
ARG S6_SHA256_HASH="dbe08f5b76c15fa32a090779b88fb2de9a9a107c3ac8ce488931dd39aa1c31d8"
ARG RSPAMD_SHA256_HASH="e4720c1f45defd07dd17b9563d0ddc480c70beadbc1a833235c077960092e030"
ARG GUCCI_SHA256_HASH="7068df83688dd892c77dd961bb80049b0bc20a33a6dd50f2478152b0373e08ab"
ARG PFA_SHA256_HASH="866d4c0ca870b2cac184e5837a4d201af8fcefecef09bc2c887a6e017a00cefe"
ARG PMA_SHA256_HASH="6494e2172354a6621d0accf3445dcc3db3d17c4274fb5a94c9159590f6978bad"
ARG RAINLOOP_SHA256_HASH="80f4ab4982311154781d31060d3a591600ef5040eb9c8c5c1724a06497c17cea"

LABEL description "Dokcer all-in-one email server modified from Hardware/mailserver (Copyright (c) 2016 Hardware <contact@meshup.net>)" \
      maintainer="Jack Nam <jacknam@ellucy.com>" \
      credit_to="Hardware <contact@meshup.net>" \
      rspamd_version="Rspamd v$RSPAMD_VER built from source" \
      s6_version="s6 v$S6_VER built from source"

ENV LC_ALL=C PYTHONUNBUFFERED=1

RUN NB_CORES=${BUILD_CORES-$(getconf _NPROCESSORS_CONF)} \
    && BUILD_DEPS=" \
    cmake \
    gcc \
    make \
    ragel \
    wget \
    unzip \
    pkg-config \
    software-properties-common \
    liblua5.3-dev \
    libluajit-5.1-dev \
    libglib2.0-dev \
    libevent-dev \
    libsqlite3-dev \
    libicu-dev \
    libssl-dev \
    libhyperscan-dev \
    libjemalloc-dev \
    libmagic-dev" \
 && apt-get update && apt-get install -y -q --no-install-recommends \
    ${BUILD_DEPS} \
    libevent-2.1-6 \
    libglib2.0-0 \
    libssl1.1 \
    libmagic1 \
    liblua5.3-0 \
    libluajit-5.1-2 \
    libsqlite3-0 \
    libhyperscan5 \
    libjemalloc2 \
    sqlite3 \
    openssl \
    ca-certificates \
    gnupg \
    dirmngr \
 && cd /tmp \
 && SKALIBS_TARBALL="skalibs-${SKALIBS_VER}.tar.gz" \
 && wget -q https://skarnet.org/software/skalibs/${SKALIBS_TARBALL} \
 && CHECKSUM=$(sha256sum ${SKALIBS_TARBALL} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${SKALIBS_SHA256_HASH}" ]; then echo "${SKALIBS_TARBALL} : bad checksum" && exit 1; fi \
 && tar xzf ${SKALIBS_TARBALL} && cd skalibs-${SKALIBS_VER} \
 && ./configure --prefix=/usr --datadir=/etc \
 && make && make install \
 && cd /tmp \
 && EXECLINE_TARBALL="execline-${EXECLINE_VER}.tar.gz" \
 && wget -q https://skarnet.org/software/execline/${EXECLINE_TARBALL} \
 && CHECKSUM=$(sha256sum ${EXECLINE_TARBALL} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${EXECLINE_SHA256_HASH}" ]; then echo "${EXECLINE_TARBALL} : bad checksum" && exit 1; fi \
 && tar xzf ${EXECLINE_TARBALL} && cd execline-${EXECLINE_VER} \
 && ./configure --prefix=/usr \
 && make && make install \
 && cd /tmp \
 && S6_TARBALL="s6-${S6_VER}.tar.gz" \
 && wget -q https://skarnet.org/software/s6/${S6_TARBALL} \
 && CHECKSUM=$(sha256sum ${S6_TARBALL} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${S6_SHA256_HASH}" ]; then echo "${S6_TARBALL} : bad checksum" && exit 1; fi \
 && tar xzf ${S6_TARBALL} && cd s6-${S6_VER} \
 && ./configure --prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin \
 && make && make install \
 && cd /tmp \
 && RSPAMD_TARBALL="${RSPAMD_VER}.tar.gz" \
 && wget -q https://github.com/vstakhov/rspamd/archive/${RSPAMD_TARBALL} \
 && CHECKSUM=$(sha256sum ${RSPAMD_TARBALL} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${RSPAMD_SHA256_HASH}" ]; then echo "${RSPAMD_TARBALL} : bad checksum" && exit 1; fi \
 && tar xzf ${RSPAMD_TARBALL} && cd rspamd-${RSPAMD_VER} \
 && cmake \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCONFDIR=/etc/rspamd \
    -DRUNDIR=/run/rspamd \
    -DDBDIR=/var/mail/rspamd \
    -DLOGDIR=/var/log/rspamd \
    -DPLUGINSDIR=/usr/share/rspamd \
    -DLIBDIR=/usr/lib/rspamd \
    -DNO_SHARED=ON \
    -DWANT_SYSTEMD_UNITS=OFF \
    -DENABLE_TORCH=ON \
    -DENABLE_HIREDIS=ON \
    -DINSTALL_WEBUI=ON \
    -DENABLE_OPTIMIZATION=ON \
    -DENABLE_HYPERSCAN=ON \
    -DENABLE_JEMALLOC=ON \
    -DJEMALLOC_ROOT_DIR=/jemalloc \
    . \
 && make -j${NB_CORES} \
 && make install \
 && cd /tmp \
 && GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-amd64" \
 && wget -q https://github.com/noqcks/gucci/releases/download/${GUCCI_VER}/${GUCCI_BINARY} \
 && CHECKSUM=$(sha256sum ${GUCCI_BINARY} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${GUCCI_SHA256_HASH}" ]; then echo "${GUCCI_BINARY} : bad checksum" && exit 1; fi \
 && chmod +x ${GUCCI_BINARY} \
 && mv ${GUCCI_BINARY} /usr/local/bin/gucci \
 && rm -rf /tmp/*

RUN groupadd -r redis && useradd -r -g redis redis
RUN groupadd -r mysql && useradd -r -g mysql mysql
RUN groupadd -r postfixadmin && useradd -r -g postfixadmin postfixadmin
RUN groupadd -r phpmyadmin && useradd -r -g phpmyadmin phpmyadmin
RUN groupadd -r rainloop && useradd -r -g rainloop rainloop

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xF1656F24C74CD1D8 \
 && add-apt-repository "deb [arch=amd64] http://ftp.kaist.ac.kr/mariadb/repo/${MARIADB_VER}/debian buster main" \
 && apt-get update && apt-get install -y -q --no-install-recommends mariadb-server mariadb-backup socat

RUN apt-get install -y -q --no-install-recommends \
    postfix postfix-pgsql postfix-mysql postfix-ldap postfix-pcre libsasl2-modules \
    dovecot-core dovecot-imapd dovecot-lmtpd dovecot-pgsql dovecot-mysql dovecot-ldap dovecot-sieve dovecot-managesieved dovecot-pop3d \
    fetchmail libdbi-perl libdbd-pg-perl libdbd-mysql-perl liblockfile-simple-perl \
    clamav clamav-daemon \
    python3-setuptools python3-gpg \
    rsyslog dnsutils curl unbound jq rsync inotify-tools \
    redis-server net-tools \
 && rm -rf /var/spool/postfix \
 && ln -s /var/mail/postfix/spool /var/spool/postfix \
 && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py && rm -f get-pip.py \
 && pip3 install watchdog

RUN apt-get install -y -q --no-install-recommends \
    php7.3 php7.3-common php7.3-fpm php7.3-opcache php7.3-zip \
    php7.3-mysql php7.3-curl php7.3-mbstring \
    php7.3-json php7.3-xml php7.3-gd \
    php7.3-sqlite3 php7.3-ldap php7.3-imap \
 && cd /tmp \
 && PFA_TARBALL="postfixadmin-${PFA_VER}.tar.gz" \
 && wget -q https://downloads.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-${PFA_VER}/${PFA_TARBALL} \
 && CHECKSUM=$(sha256sum ${PFA_TARBALL} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${PFA_SHA256_HASH}" ]; then echo "${PFA_TARBALL} : bad checksum" && exit 1; fi \
 && rm -rf /etc/postfixadmin && tar xzf ${PFA_TARBALL} && mv postfixadmin-$PFA_VER /etc/postfixadmin \
 && cd /tmp \
 && PMA_TARBALL="phpMyAdmin-${PMA_VER}-english.tar.gz" \
 && wget -q https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER}/${PMA_TARBALL} \
 && CHECKSUM=$(sha256sum ${PMA_TARBALL} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${PMA_SHA256_HASH}" ]; then echo "${PMA_TARBALL} : bad checksum" && exit 1; fi \
 && rm -rf /etc/phpmyadmin && tar xzf ${PMA_TARBALL} && mkdir -p /etc/phpmyadmin && mv phpMyAdmin-$PMA_VER-english /etc/phpmyadmin/public \
 && cd /tmp \
 && RAINLOOP_ZIP="rainloop-community-${RAINLOOP_VER}.zip" \
 && wget -q https://github.com/RainLoop/rainloop-webmail/releases/download/v${RAINLOOP_VER}/${RAINLOOP_ZIP} \
 && CHECKSUM=$(sha256sum ${RAINLOOP_ZIP} | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${RAINLOOP_SHA256_HASH}" ]; then echo "${RAINLOOP_ZIP} : bad checksum" && exit 1; fi \
 && rm -rf /etc/rainloop && mkdir -p /etc/rainloop/public && unzip -q ${RAINLOOP_ZIP} -d /etc/rainloop/public && echo "${RAINLOOP_VER}" > /etc/rainloop/VERSION \
 && mv /etc/rainloop/public/data /etc/rainloop/data && rm -f /etc/rainloop/data/EMPTY \
 && PLUGIN_DIR="/etc/rainloop/data/_data_/_default_/plugins/postfixadmin-change-password" \
 && rm -rf ${PLUGIN_DIR} && mkdir -p ${PLUGIN_DIR} && cd ${PLUGIN_DIR} \
 && SOURCE_PATH="https://raw.githubusercontent.com/RainLoop/rainloop-webmail/master/plugins/postfixadmin-change-password" \
 && for SOURCE_FILE in ChangePasswordPostfixAdminDriver.php LICENSE README VERSION index.php md5crypt.php; do wget -q ${SOURCE_PATH}/${SOURCE_FILE}; done

RUN apt-get purge -y ${BUILD_DEPS} \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

RUN sed -i -r '/^appendonly no/c\appendonly yes' /etc/redis/redis.conf; \
 echo 'maxmemory 128mb\nmaxmemory-policy allkeys-lru' >> /etc/redis/redis.conf; \
 echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf; \
 echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled; \
 mkdir -p /var/lib/redis /var/run/redis; \
 chown -R redis:redis /var/lib/redis /var/run/redis; \
 chmod 777 /var/run/redis

RUN sed -ri 's/^user\s/#&/' /etc/mysql/my.cnf /etc/mysql/conf.d/*; \
 rm -rf /var/lib/mysql; \
 mkdir -p /var/lib/mysql /var/run/mysqld; \
 chown -R mysql:mysql /var/lib/mysql /var/run/mysqld; \
 chmod 777 /var/run/mysqld; \
 find /etc/mysql/ -name '*.cnf' -print0 | xargs -0 grep -lZE '^(bind-address|log)' | xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/'; \
 echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf

RUN mkdir -p /var/run/postfixadmin /etc/postfixadmin/templates_c /etc/postfixadmin/sessions /etc/postfixadmin/public; \
 chown -R postfixadmin:postfixadmin /etc/postfixadmin/templates_c /etc/postfixadmin/sessions /etc/postfixadmin/public; \
 chmod 777 /var/run/postfixadmin

RUN rm -rf /etc/phpmyadmin/public/setup/ /etc/phpmyadmin/public/doc/ /etc/phpmyadmin/public/examples/ /etc/phpmyadmin/public/test/ /etc/phpmyadmin/public/po/; \
 rm -f /etc/phpmyadmin/public/composer.json /etc/phpmyadmin/public/RELEASE-DATE-${PMA_VER}; \
 sed -i "s@define('CONFIG_DIR'.*@define('CONFIG_DIR', '/etc/phpmyadmin/');@" /etc/phpmyadmin/public/libraries/vendor_config.php; \
 mkdir -p /var/run/phpmyadmin /etc/phpmyadmin/sessions /etc/phpmyadmin/upload /etc/phpmyadmin/save; \
 chown -R phpmyadmin:phpmyadmin /etc/phpmyadmin/public /etc/phpmyadmin/sessions /etc/phpmyadmin/upload /etc/phpmyadmin/save; \
 chmod 777 /var/run/phpmyadmin

RUN mkdir -p /var/run/rainloop /etc/rainloop/sessions /etc/rainloop/data/_data_/_default_/configs; \
 chown -R rainloop:rainloop /etc/rainloop/public /etc/rainloop/data /etc/rainloop/sessions; \
 chmod 777 /var/run/rainloop

RUN sed -i 's#^/usr/sbin/logrotate /etc/logrotate.conf#su root -g root -c "/usr/sbin/logrotate /etc/logrotate.conf"#' /etc/cron.daily/logrotate

EXPOSE 25 110 143 465 587 993 995 3306 4190 8081 8083 8084 11334
COPY rootfs /
RUN chmod +x /usr/local/bin/* /services/*/run /services/.s6-svscan/finish
CMD ["run.sh"]
