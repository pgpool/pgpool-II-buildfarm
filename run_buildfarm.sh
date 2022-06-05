#!/bin/sh

OS_LIST=(CentOS7 RockyLinux8)

# Check if builfarm.sh process is running.
PID1=`pgrep -o -f "buildfarm.sh"`
PID2=$$
PID3="$PPID"
if [ "x${PID1}" != "x${PID2}" -a "x${PID1}" != "x${PID3}"  ] ; then
  echo `LANG=en date` ': The previous builfarm.sh process exists yet'
  exit 1
fi

systemctl restart docker || exit 1

/var/buildfarm/clean.sh

for OS in ${OS_LIST[@]}
do
	rm -rf volum-${OS}/*
	/var/buildfarm/buildfarm.sh ${OS}
done
