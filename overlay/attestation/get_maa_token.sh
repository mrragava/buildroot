#!/bin/sh

# usage
# /attestation/get_maa_token.sh /mnt/sda2/image_config.json ~/report.bin ~/maatoken1.jwt "sharedeus.eus.attest.azure.net"
# /attestation/get_maa_token.sh /mnt/sda2/image_config.json ~/report.bin ~/maatoken1.jwt "51.104.246.182:8080"

configfile=$1
reportfile=$2
maatokenfile=$3

#optional configuration
maaurl=${4:-"sharedeus.eus.attest.azure.net"}
includesigntime=${5:-"true"}

# Get the dir of the scripts
DIR=`dirname "$0"`

# Get snp report, use config file as reportdata
sh ${DIR}/get_snp_report.sh "$configfile" "$reportfile"

# Get maa token, requires CVM to have access to web
sh ${DIR}/get_maa_token_from_report.sh "$reportfile" "$configfile" "$maatokenfile" "$maaurl" "$includesigntime"

