#!/bin/sh
# Get the dir of scripts
DIR=`dirname "$0"`

measurement=`${DIR}/get-snp-report | sed -n '12,14p' | xargs | sed 's/ //g'`
index=96
while [ $index -gt 0 ]
do
  echo -n ${measurement:$(($index-2)):2}
  index=$(($index-2))
done
echo
