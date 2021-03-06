#!/bin/bash

case $PGSQL_VERSION in
	"9.5" ) PGVER=95; JDBC_DRIVER=$JDBC_DRIVER_95 ;; 
	"9.6" ) PGVER=96; JDBC_DRIVER=$JDBC_DRIVER_96 ;; 
	"10" ) PGVER=10; JDBC_DRIVER=$JDBC_DRIVER_10 ;; 
	*) echo unknown PGSQL $PGSQL_VERSION ;;
esac

case $PGPOOL_BRANCH in
	"master" ) POOLVER=3.7; POOL_REL_RPM=pgpool-II-release-3.7-1.noarch.rpm; ;;
	"V3_7_STABLE" ) POOLVER=3.7; POOL_REL_RPM=pgpool-II-release-3.7-1.noarch.rpm; ;;
	"V3_6_STABLE" ) POOLVER=3.6; POOL_REL_RPM=pgpool-II-release-3.6-1.noarch.rpm; ;;
	"V3_5_STABLE" ) POOLVER=3.5; POOL_REL_RPM=pgpool-II-release-3.5-1.noarch.rpm; ;;
	"V3_4_STABLE" ) POOLVER=3.4; POOL_REL_RPM=pgpool-II-release-3.4-1.noarch.rpm; ;;
	"V3_3_STABLE" ) POOLVER=3.3; POOL_REL_RPM=pgpool-II-release-3.3-1.noarch.rpm; ;;
	*) echo unknown branch $PGPOOL_BRANCH ;;
esac

yum clean all

# Install PostgreSQL packages
yum install -y postgresql${PGVER}-devel postgresql${PGVER} postgresql${PGVER}-server postgresql${PGVER}-contrib

# Install pgpool-II extension for PostgreSQL
rpm -ihv http://www.pgpool.net/yum/rpms/${POOLVER}/redhat/${ARCH}/${POOL_REL_RPM}
yum install -y pgpool-II-pg${PGVER}-extensions

# Setup postgres account
PATH=/usr/pgsql-${PGSQL_VERSION}/bin:$PATH
LD_LIBRARY_PATH=/usr/pgsql-${PGSQL_VERSION}/lib:$LD_LIBRARY_PATH

export JDBC_DRIVER POOLVER PATH LD_LIBRARY_PATH
