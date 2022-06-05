#!/bin/bash

if [ `echo "$POOLVER >= 3.4" | bc` == 1 ];then
    CONFIGURE_OPTS="--with-openssl --with-pam --with-pgsql=/usr/pgsql-${PGSQL_VERSION} --with-memcached=/usr"
    EXTENSION_DIR=src/sql
else
    CONFIGURE_OPTS="--with-openssl --with-pgsql=/usr/pgsql-${PGSQL_VERSION}"
    EXTENSION_DIR=sql
fi

if [ `echo "$PGSQL_VERSION >= 9.4" | bc` == 1 ];then
    PGSOCKET_DIR=/var/run/postgresql
    mkdir -p $PGSOCKET_DIR
    chown postgres.postgres $PGSOCKET_DIR
else
    PGSOCKET_DIR=/tmp
fi

cd $PGHOME/pgpool2
git pull
git checkout $PGPOOL_BRANCH

# check Pgpool-II version
PGPOOL_VERSION=`grep "PACKAGE_VERSION=" configure | awk  -F"[']" '{print $2}'`

rm -fr /var/volum/$DIRNAME/*
tar cf - .|(cd /var/volum/$DIRNAME;tar xfp -)
cd /var/volum/$DIRNAME
autoreconf
./configure $CONFIGURE_OPTS
make

if [ $BUILD_RPM -eq 1 ]; then
    echo -n "Building RPMs ..."

    make
    make dist
    rm -rf $PGHOME/rpmbuild
    mkdir $PGHOME/rpmbuild
    cd $PGHOME/rpmbuild
    mkdir BUILD BUILDROOT RPMS SOURCES SPECS SRPMS
    cp /var/volum/$DIRNAME/pgpool-II-$PGPOOL_VERSION.tar.gz $PGHOME/rpmbuild/SOURCES
    cp /var/volum/$DIRNAME/src/pgpool.spec $PGHOME/rpmbuild/SPECS
    cp /var/volum/$DIRNAME/src/redhat/* $PGHOME/rpmbuild/SOURCES
    sed -i -e "s/^%patch1/#%patch1/" -e "s/^Patch1/#Patch1/" $PGHOME/rpmbuild/SPECS/pgpool.spec
    PGSQL_VERSION2=`expr $PGSQL_VERSION \* 10`
    if [ ${OS} = "CentOS7" ]; then
        DIST_VERSION=.rhel7
    elif [ ${OS} = "RockyLinux8" ]; then
        DIST_VERSION=.rhel8
    fi

    rpmbuild -ba SPECS/pgpool.spec \
        --define="pgpool_version ${PGPOOL_VERSION}" \
        --define="pg_version ${PGSQL_VERSION}" \
        --define="pghome /usr/pgsql-${PGSQL_VERSION}" \
        --define="dist ${DIST_VERSION}" \
        --define="pgsql_ver ${PGSQL_VERSION2}"

        if [ $? = 0 ];then
                echo "done"
        else
                echo "failed"
                echo "error: rpmbuild failed"
                exit 1
        fi
else
    echo -n "make extension ..."

    cd /var/volum/$DIRNAME/${EXTENSION_DIR}
    make install
    if [ $? = 0 ];then
        echo "done"
    else
        echo "failed"
        echo "error: make extension failed"
        exit 1
    fi
fi
