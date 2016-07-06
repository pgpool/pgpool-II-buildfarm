#!/bin/bash

TIMEOUT=1000
DEBUG=
if [ $PGPOOL_BRANCH = master -o `echo "$POOLVER >= 3.5" | bc` == 1 ];then
	DEBUG=-d
fi

if [ `echo "$POOLVER >= 3.4" | bc` == 1 ];then
	CONFIGURE_OPTS="--with-openssl --with-pgsql=/usr/pgsql-${PGSQL_VERSION} --with-memcached=/usr"
	TEST_DIR=src/test
else
	CONFIGURE_OPTS="--with-openssl --with-pgsql=/usr/pgsql-${PGSQL_VERSION}"
	TEST_DIR=test
fi

if [ $OS = CentOS7 -a $PGSQL_VERSION = 9.4 ];then
	PGSOCKET_DIR=/var/run/postgresql
	mkdir -p $PGSOCKET_DIR
	chown postgres.postgres $PGSOCKET_DIR
else
	PGSOCKET_DIR=/tmp
fi

#cd /tmp
#gcc test.c
#./a.out
cd $PGHOME/pgpool2
git pull
git checkout $PGPOOL_BRANCH
rm -fr /var/volum/$DIRNAME/*
tar cf - .|(cd /var/volum/$DIRNAME;tar xfp -)
cd /var/volum/$DIRNAME
./configure $CONFIGURE_OPTS
#cd $TEST_DIR/regression
#./regress.sh -p /usr/pgsql-${PGSQL_VERSION}/bin -j /usr/share/$JDBC_DRIVER -s $PGSOCKET_DIR -t $TIMEOUT $DEBUG


if [ $PGPOOL_BRANCH = master -o `echo "$POOLVER >= 3.3" | bc` == 1 ];then
    cd $TEST_DIR/regression
    #./regress.sh -p /usr/pgsql-${PGSQL_VERSION}/bin -j /usr/share/$JDBC_DRIVER -s $PGSOCKET_DIR -t $TIMEOUT $DEBUG
    ./regress.sh -p /usr/pgsql-${PGSQL_VERSION}/bin -j /usr/share/$JDBC_DRIVER -s $PGSOCKET_DIR -t $TIMEOUT

else

    echo "creating pgpool-II temporary installation ..."
    dir=`pwd`
    PGPOOL_PATH=$dir/temp/installed

    make install -e prefix=${PGPOOL_PATH}
    #make && make install

    rtn=$?
    if [ $rtn = 0 ];then
        echo "install ok"
    else
        echo "install failed"
    fi
fi
