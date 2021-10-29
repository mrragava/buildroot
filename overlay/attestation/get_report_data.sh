#!/bin/sh
report_data=`/get-snp-report | sed -n '8,11p' | xargs | sed 's/ //g'`
index=128
while [ $index -gt 0 ]
do
  echo -n ${report_data:$(($index-2)):2}
  index=$(($index-2))
done
echo
