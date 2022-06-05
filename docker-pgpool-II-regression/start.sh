#!/bin/bash
# 1GB shared memory
umount /dev/shm
mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=256M tmpfs /dev/shm
sysctl -w kernel.shmmax=1063256064
sysctl -w kernel.shmall=259584
ipcs -l
if [ ${OS} = "CentOS6" ]; then
    service sshd start
else
    systemctl start sshd
fi
export DIRNAME=${OS}/${PGSQL_VERSION}/${PGPOOL_BRANCH}
if [ ! -d /var/volum/${DIRNAME} ];then
    mkdir -p /var/volum/${DIRNAME}
fi
chown -R postgres /var/volum/*
. /tmp/setup.sh
if [ `echo "$POOLVER >= 3.4" | bc` -eq 1 ];then
    if [ ${OS} = "CentOS6" ]; then
        service memcached start
    else
        systemctl start memcached
    fi
fi

su  postgres < /tmp/build.sh

if [ $BUILD_RPM -eq 1 ]; then
    rpm -ivh $PGHOME/rpmbuild/RPMS/x86_64/pgpool-II-*
fi

su  postgres < /tmp/regress.sh
