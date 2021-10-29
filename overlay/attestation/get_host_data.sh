#!/bin/sh
DIR=`dirname "$0"`
host_data=`${DIR}/get-snp-report | sed -n '15,16p' | xargs | sed 's/ //g'`
index=0
while [ $index -lt 64 ]
do
  echo -n ${host_data:$index:2}
  index=$(($index+2))
done
echo
