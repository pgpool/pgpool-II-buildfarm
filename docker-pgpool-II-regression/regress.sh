#!/bin/bash

TIMEOUT=600
DEBUG=
if [ $PGPOOL_BRANCH = master -o `echo "$POOLVER >= 3.5" | bc` == 1 ];then
	DEBUG=-d
fi

if [ `echo "$POOLVER >= 3.4" | bc` == 1 ];then
	CONFIGURE_OPTS="--with-openssl --with-pam --with-pgsql=/usr/pgsql-${PGSQL_VERSION} --with-memcached=/usr"
	TEST_DIR=src/test
	EXTENSION_DIR=src/sql
else
	CONFIGURE_OPTS="--with-openssl --with-pgsql=/usr/pgsql-${PGSQL_VERSION}"
	TEST_DIR=test
	EXTENSION_DIR=sql
fi

if [ `echo "$PGSQL_VERSION >= 9.4" | bc` == 1 ];then
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
autoreconf
./configure $CONFIGURE_OPTS

if [ $PGPOOL_BRANCH = master -o `echo "$POOLVER >= 3.3" | bc` == 1 ];then
	
	cd /var/volum/$DIRNAME/${EXTENSION_DIR}
	make install
	if [ $? = 0 ];then
		echo "make extension ok"
	else
		echo "make extension failed"
		exit 1
	fi

	cd /var/volum/$DIRNAME
	make clean

	cd /var/volum/${DIRNAME}/$TEST_DIR/regression
	#./regress.sh -p /usr/pgsql-${PGSQL_VERSION}/bin -j /usr/share/$JDBC_DRIVER -s $PGSOCKET_DIR -t $TIMEOUT $DEBUG 001
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
