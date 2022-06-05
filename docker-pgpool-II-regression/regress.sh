#!/bin/bash

TIMEOUT=600
DEBUG=""
TEST_SAMPLES=""

if [ $PGPOOL_BRANCH = master -o `echo "$POOLVER >= 3.5" | bc` == 1 ];then
    DEBUG=-d
fi

if [ `echo "$PGSQL_VERSION >= 9.4" | bc` == 1 ];then
    PGSOCKET_DIR=/var/run/postgresql
    mkdir -p $PGSOCKET_DIR
    chown postgres.postgres $PGSOCKET_DIR
else
    PGSOCKET_DIR=/tmp
fi

if [ $BUILD_RPM -eq 1 ]; then
    INSTALL_MODE=noinstall
    TEST_SAMPLES=-c
    PGPOOL_PATH=/usr
else
    INSTALL_MODE=install
    PGPOOL_PATH=/usr/local
fi

cd /var/volum/$DIRNAME
make clean
cd /var/volum/${DIRNAME}/$TEST_DIR/regression
./regress.sh -p /usr/pgsql-${PGSQL_VERSION}/bin -j /usr/share/${JDBC_DRIVER} -s ${PGSOCKET_DIR} -t ${TIMEOUT} -i ${PGPOOL_PATH} -m ${INSTALL_MODE} ${TEST_SAMPLES}
