#!/bin/bash
# 1GB shared memory
umount /dev/shm
mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=256M tmpfs /dev/shm
sysctl -w kernel.shmmax=1063256064
sysctl -w kernel.shmall=259584
ipcs -l
service sshd start
export DIRNAME=${OS}/${PGSQL_VERSION}/${PGPOOL_BRANCH}
if [ ! -d /var/volum/${DIRNAME} ];then
    mkdir -p /var/volum/${DIRNAME}
fi
chown -R postgres /var/volum/*
. /tmp/setup.sh
if [ `echo "$POOLVER >= 3.4" | bc` -eq 1 ];then
	service memcached start
fi
su  postgres < /tmp/regress.sh
