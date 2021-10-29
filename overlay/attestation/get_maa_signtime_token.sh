#!/bin/sh
# Get the dir of scripts
DIR=`dirname "$0"`
# Get maa token from test maa server with signtime claims support
sh ${DIR}/get_maa_token.sh /mnt/sda2/image_config.json ~/report.bin ~/maatoken1.jwt "51.104.246.182:8080"
