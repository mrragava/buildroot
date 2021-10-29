#!/bin/sh

# Input
configfile=$1

# Output
reportfile=$2

# Get the dir of the scripts
DIR=`dirname "$0"`
# Generate hash

configfilehash=$(sha256sum $configfile)
confighashbinfile="${configfile}.bin"
confighash=$configfilehash
output=$(${DIR}/hex-convert "${confighash}" 64 $confighashbinfile)

# echo "Sha256 Hash of '${configfile}': ${confighash}"

# Generate report, include config hash in report.
${DIR}/get-snp-report-with-data $confighashbinfile $reportfile

