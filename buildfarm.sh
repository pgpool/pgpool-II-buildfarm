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
MAILTO=pgpool-hackers@pgpool.net
REPLYTO=$MAILTO
#FROM=buildfarm@your.hostname
FROM=buildfarm@pgpool.net
SUBJECT="pgpool-II buildfarm results"

# directories
SRCDIR=/var/buildfarm

VOLUM=$SRCDIR/volum
GITROOT=$SRCDIR/docker-pgpool-II-regression
LOGDIR=$SRCDIR/log

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
PGSQL_LIST=(9.3 9.4)
BRANCH_LIST=(master V3_5_STABLE V3_4_STABLE V3_3_STABLE V3_2_STABLE V3_1_STABLE)

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

./$SRCDIR/clean.sh > $TMPLOG 2>&1

ntpdate $NTP_SERVER > /dev/null

if [ -e $LOGDIR ]; then
    rm -rf $LOGDIR;
fi
mkdir $LOGDIR

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

        if [ $# -gt 1 ];then
            if [ $1 = "-p" ];then
                proxy=$2
                proxy_set=y
                echo "inserting proxy address $2."
            else
                echo "wrong parameter $1".
                exit 1
            fi
        else
            proxy_set=n
        fi

        echo "======= Start docker build ======="
        if [ $proxy_set = "y" ];then
            cp $DOCKERFILE_NAME $DOCKERFILE_NAME.orig
            cat Dockerfile|sed -e "/FROM/ aENV https_proxy $proxy" -e "/FROM/ aENV http_proxy $proxy" > $DOCKERFILE_NAME.proxy
            cp $DOCKERFILE_NAME.proxy $DOCKERFILE_NAME
        fi

        docker build -t $TAG -f $DOCKERFILE_NAME $NO_CACHE . > $TMPLOG 2>&1
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
                continue
            fi

            MAKE_ERROR=`awk '/^make: \*\*\*/' $LOG`
            if [ ! -z "$MAKE_ERROR" ]; then
                echo "Error" >> $RESULT
                echo "$MAKE_ERROR" >> $RESULT
                echo >> $RESULT
                continue
	        else
                echo "make...ok" >> $RESULT
            fi


	        TEST_ERROR=`awk '/\.failed\.$/' $LOG`
	        TEST_TIMEOUT=`awk '/\.timeout\.$/' $LOG`
            if [ ! -z "$TEST_ERROR" -o ! -z "$TEST_TIMEOUT" -o ! -z "$MAKE_ERROR" ]; then
            	echo "* $BRANCH  PostgreSQL $PGSQL  $OS" >> $SUMMARY
            	if [ ! -z "$TEST_ERROR" ]; then
            	    echo "$TEST_ERROR" >> $SUMMARY
            	elif [ ! -z "$TEST_TIMEOUT" ]; then
            	    echo "$TEST_TIMEOUT" >> $SUMMARY
	    	    elif [ ! -z "$MAKE_ERROR" ]; then
            	    echo "$MAKE_ERROR" >> $SUMMARY
		        fi
		        $ERROR=1
            fi

            awk '/^testing/,EOF' $LOG >> $RESULT
            echo >> $RESULT
        done
    done
done

if [ $ERROR -eq 0 ]; then
    echo "All tests succeeded." >> $SUMMARY
    echo "=========================================================================" >> $SUMMARY
    echo >> $SUMMARY
fi

echo "end: " `LANG=en date`>> $RESULT

if [ -n $SEND_MAIL ]; then
    cat $SUMMARY $RESULT | mail -s "$SUBJECT" -a "From: $FROM" -a "Reply-To: $REPLYTO" $MAILTO
fi
