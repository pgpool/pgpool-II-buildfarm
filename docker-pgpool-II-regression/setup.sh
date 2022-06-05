#!/bin/bash

case $PGPOOL_BRANCH in
    "master" ) POOLVER=4.3; POOL_REL_RPM=pgpool-II-release-4.3-1.noarch.rpm; ;;
    "V4_3_STABLE" ) POOLVER=4.3; POOL_REL_RPM=pgpool-II-release-4.3-1.noarch.rpm; ;;
    "V4_2_STABLE" ) POOLVER=4.2; POOL_REL_RPM=pgpool-II-release-4.2-1.noarch.rpm; ;;
    "V4_1_STABLE" ) POOLVER=4.1; POOL_REL_RPM=pgpool-II-release-4.1-1.noarch.rpm; ;;
    "V4_0_STABLE" ) POOLVER=4.0; POOL_REL_RPM=pgpool-II-release-4.0-1.noarch.rpm; ;;
    "V3_7_STABLE" ) POOLVER=3.7; POOL_REL_RPM=pgpool-II-release-3.7-1.noarch.rpm; ;;
    "V3_6_STABLE" ) POOLVER=3.6; POOL_REL_RPM=pgpool-II-release-3.6-1.noarch.rpm; ;;
    "V3_5_STABLE" ) POOLVER=3.5; POOL_REL_RPM=pgpool-II-release-3.5-1.noarch.rpm; ;;
    "V3_4_STABLE" ) POOLVER=3.4; POOL_REL_RPM=pgpool-II-release-3.4-1.noarch.rpm; ;;
    "V3_3_STABLE" ) POOLVER=3.3; POOL_REL_RPM=pgpool-II-release-3.3-1.noarch.rpm; ;;
    *) echo unknown branch $PGPOOL_BRANCH ;;
esac

chown -R postgres /usr/pgsql-${PGSQL_VERSION}

# Install pgpool-II extension for PostgreSQL
rpm -ihv http://www.pgpool.net/yum/rpms/${POOLVER}/redhat/${ARCH}/${POOL_REL_RPM}
#yum install -y pgpool-II-pg${PGVER}-extensions

# Setup postgres account
PATH=/usr/pgsql-${PGSQL_VERSION}/bin:$PATH

# Set test directory
if [ `echo "$POOLVER >= 3.4" | bc` == 1 ];then
    TEST_DIR=src/test
else
    TEST_DIR=test
fi

export POOLVER PATH TEST_DIR
if [ ${OS} = "CentOS6" ]; then
    export PGGSSENCMODE=disable
fi
