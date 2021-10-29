#!/bin/sh
DIR=`dirname "$0"`
# Swap 4th and 5th line(1 based index).
# Retrieve the 4th and 5th line.
# Remove redundant space.

${DIR}/get-snp-report | sed '4{h;d};5{G}' | sed -n '4,5p' | xargs | sed 's/ //g'
