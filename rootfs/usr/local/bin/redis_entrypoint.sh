#!/bin/bash

if [ ! -f "/etc/redis/redis.conf" ]; then
 exit 1
fi

chown -R redis:redis /var/mail/redis
if [ -f "/var/mail/redis/appendonly.aof" ]; then
 redis-check-aof --fix /var/mail/redis/appendonly.aof
fi

exit 0
