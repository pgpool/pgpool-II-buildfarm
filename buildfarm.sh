#!/bin/bash

TIMEOUT=8000

# Do docker build?
DOCKER_BUILD=1

NO_CACHE="--no-cache"
#NO_CACHE=""

# day of the week to build docker images for git pull (0 means Sunday)
BUILD_DAY=0

# Send mail?
SEND_MAIL=1

# test_error
ERROR=0

# mail address
MAILTO=pgpool-buildfarm@your.hostname
REPLYTO=$MAILTO
FROM=buildfarm@your.hostname
SUBJECT="pgpool-II buildfarm results"

# directories
SRCDIR=/var/buildfarm

VOLUM=$SRCDIR/volum
GITROOT=$SRCDIR/docker-pgpool-II-regression
LOGDIR=$SRCDIR/log
WORKDIR=$GITROOT/work

# backup regression test log to other host
REGRESSIONLOG=$SRCDIR/regression-log
REGRESSIONLOGDIR=regression-log
REGRESSIONLOGFILE=`date +%Y%m%d`-buildfarm.tar.gz
LOG_BACKUP=log_backup_host
LOG_BACKUP_DIR=log_backup_dir

TMPLOG=$LOGDIR/tmp.log
RESULT=$LOGDIR/result
SUMMARY=$LOGDIR/summary

# sed command
COLOR='\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]'
NOCOLOR='\x1B\(B'
SEDPTN="s/($COLOR|$NOCOLOR)//g" 
SED="sed -r $SEDPTN"

# targets
OS_LIST=(CentOS6 CentOS7)
PGSQL_LIST=(9.5 9.6 10)
BRANCH_LIST=(master V3_7_STABLE V3_6_STABLE V3_5_STABLE V3_4_STABLE V3_3_STABLE)

#ntp server
NTP_SERVER=sranhm

# functions

## get tag for docker image of specified branch
function getTag()
{
    local os=`echo $1 | tr [A-Z] [a-z]`
    echo buildfarm_$os
}

function getName()
{
    OS=$1
    BRANCH=$2
    PGSQL_VERSION=$3
	
    local os=`echo $OS | tr [A-Z] [a-z]`
    local POOLVER=`getPoolVer $BRANCH`
    local PGVER=`echo $PGSQL_VERSION | tr -d . | cut -c 1-2`

    echo "${os}_${POOLVER}_pg${PGVER}"
}

## get path to dockerfile directory of specified branch
function getDockerfileDir()
{
    local OS=$1
    echo "${GITROOT}/${OS}"
}

## get pgpool version number (e.g. 34) for tag and dockerfile
function getPoolVer()
{
    local BRANCH=$1

    case $BRANCH in
    "master" ) 
        echo master ;;
    *)  
        echo $BRANCH | tr -d V_STABLE ;;
    esac
}


## print environment info
function printEnvInfo()
{
    local TAG=$1
    local PGSQL=$2

    local PGVER_OF_IMAGE=`docker run --rm $TAG /usr/pgsql-${PGSQL}/bin/postmaster --version 2>/dev/null | sed "s/[^0-9.]//g"`
    local OS_OF_IMAGE=`docker run --rm $TAG cat /etc/redhat-release 2>/dev/null`
    local KERNEL_OF_IMAGE=`docker run --rm $TAG uname -r 2>/dev/null`
    echo "PostgreSQL: $PGVER_OF_IMAGE"
    echo "OS: $OS_OF_IMAGE ($KERNEL_OF_IMAGE)"
}

# main

$SRCDIR/clean.sh

ntpdate $NTP_SERVER > /dev/null

if [ -e $LOGDIR ]; then
    rm -rf $LOGDIR;
fi
mkdir $LOGDIR
rm -rf ${REGRESSIONLOG}/*

echo "pgpool-II buildfarm" >> $RESULT
echo "=========================================================================" >> $SUMMARY
echo "start: " `LANG=en date`>> $RESULT
echo >> $RESULT

for OS in ${OS_LIST[@]}
do

    TAG=`getTag $OS`

    # building docker image
    if [ -n "$DOCKER_BUILD" -o `date '+%w'` = $BUILD_DAY ]; then
        echo -n "** building docker image ..." >> $RESULT
        BUILD_LOG=$LOGDIR/$OS-build.log
   
        cd $GITROOT
        DOCKERFILE_DIR=`getDockerfileDir $OS`
        DOCKERFILE_NAME=Dockerfile.$OS

        docker build -t $TAG -f $DOCKERFILE_NAME $NO_CACHE . >> $TMPLOG 2>&1
        RST=$? 
        cat $TMPLOG | col -xb | $SED > $BUILD_LOG

        if [ $RST -ne 0 ]; then
            echo failure. >> $RESULT
            echo >> $RESULT
            continue >> $RESULT
        fi
        echo success. >> $RESULT
        echo >> $RESULT
    fi

    for BRANCH in ${BRANCH_LIST[@]}
    do
        for PGSQL in ${PGSQL_LIST[@]}
        do

            rm -rf $VOLUM/*
            NAME=`getName $OS $BRANCH $PGSQL`
            LOG=$LOGDIR/${OS}_${BRANCH}_${PGSQL}.log

            echo "* Target branch: $BRANCH" >> $RESULT
            echo >> $RESULT

            # print environment information
            printEnvInfo $TAG $PGSQL >> $RESULT
            echo >> $RESULT

            # Regression test
            echo "** Regression test" >> $RESULT
            echo >> $RESULT
            docker run -e PGPOOL_BRANCH=$BRANCH -e OS=$OS -e PGSQL_VERSION=$PGSQL --privileged -v $VOLUM:/var/volum --name $NAME -d $TAG > $TMPLOG 2>&1
            #docker run -e PGPOOL_BRANCH=$BRANCH -e OS=$OS -e PGSQL_VERSION=$PGSQL --privileged --name $NAME -d $TAG > $TMPLOG 2>&1
            timeout $TIMEOUT docker exec $NAME /tmp/start.sh >> $TMPLOG 2>&1
            if [ ! $? -eq 0 ]; then
                echo "buildfarm timed out" >> $TMPLOG
            fi
            docker kill $NAME
            docker rm $NAME

            cat $TMPLOG | col -xb | $SED > $LOG

            CONFIGURE_ERROR=`awk '/^configure: error/' $LOG`
            if [ ! -z "$CONFIGURE_ERROR" ]; then
                echo "Error" >> $RESULT
                echo "$CONFIGURE_ERROR" >> $RESULT
                echo >> $RESULT
                #continue
            fi

            MAKE_ERROR=`awk '/^(make: \*\*\*|make install failed)/' $LOG`
            if [ ! -z "$MAKE_ERROR" ]; then
                echo "Error" >> $RESULT
                echo "$MAKE_ERROR" >> $RESULT
                echo >> $RESULT
                #continue
	        else
                echo "make...ok" >> $RESULT
            fi

	    
	        TEST_ERROR=`awk '/\.failed\.$/' $LOG`
			TEST_TIMEOUT=`awk '/(\.timeout\.|buildfarm timed out)$/' $LOG`

            if [ ! -z "$TEST_ERROR" -o ! -z "$TEST_TIMEOUT" -o ! -z "$MAKE_ERROR" -o ! -z "$CONFIGURE_ERROR" ]; then
            	echo "* $BRANCH  PostgreSQL $PGSQL  $OS" >> $SUMMARY
            	if [ ! -z "$TEST_ERROR" ]; then
            	    echo "$TEST_ERROR" >> $SUMMARY
            	elif [ ! -z "$TEST_TIMEOUT" ]; then
            	    echo "$TEST_TIMEOUT" >> $SUMMARY
	    	    elif [ ! -z "$MAKE_ERROR" ]; then
            	    echo "$MAKE_ERROR" >> $SUMMARY
	    	    elif [ ! -z "$CONFIGURE_ERROR" ]; then
            	    echo "$CONFIGURE_ERROR" >> $SUMMARY
		        fi
		        echo >> $SUMMARY
		        ERROR=1 
            fi

            awk '/^testing/,EOF' $LOG >> $RESULT
            echo >> $RESULT

            ## move failed regression logs
            echo "copy failed test logs to regression-log" >> $LOG
            grep testing $TMPLOG | while read s; do
            if echo $s | grep -qEv '\.\.\.ok\.$'; then
                test_dir=`echo $s | cut -d ' ' -f 2 | cut -d . -f 1`
                echo "copy $VOLUM/$OS/$PGSQL/$BRANCH/src/test/regression/tests/${test_dir}.* to regression-log" >> $LOG 
                cp -r $VOLUM/$OS/$PGSQL/$BRANCH/src/test/regression/tests/${test_dir}.* ${REGRESSIONLOG}/$OS/$PGSQL/$BRANCH/ >> $LOG 2>&1
                cp $LOG ${REGRESSIONLOG}/$OS/$PGSQL/$BRANCH/
            fi
            done
        done
    done
done

if [ $ERROR -eq 0 ]; then
    echo "All tests succeeded." >> $SUMMARY
fi
echo "=========================================================================" >> $SUMMARY
echo >> $SUMMARY

echo "end: " `LANG=en date`>> $RESULT
echo >> $RESULT

# move regression test logs to log_backup_host
cd $SRCDIR
tar zcvf ${REGRESSIONLOGFILE} ${REGRESSIONLOGDIR}
scp ${REGRESSIONLOGFILE} ${LOG_BACKUP}:${LOG_BACKUP_DIR}
rm ${REGRESSIONLOGFILE}
if [ ! $? -eq 0 ]; then
	echo "moving regression result to log_backup_host ... failed" >> $RESULT
else
	echo "moving regression result to log_backup_host ... OK" >> $RESULT
fi

if [ -n $SEND_MAIL ]; then
    cat $SUMMARY $RESULT | mail -s "$SUBJECT" -a "From: $FROM" -a "Reply-To: $REPLYTO" $MAILTO
fi
