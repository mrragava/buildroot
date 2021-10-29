#!/bin/sh

#sudo apt update
#sudo apt install jq
#sudo apt install gridsite-clients

# Input
reportfile=$1
userjson=$2

# Output
maatokenfile=$3

#optional configuration
maaurl=${4:-"sharedeus.eus.attest.azure.net"}
includesigntime=${5:-"true"}

# Helper functions

function get_hex_data {
    local offset=$1
    local length=$2
    local reverse=$3
    local valuestring=$(xxd -p -l $length -s $offset -c $length $reportfile)
    if [ "$reverse" = true ] ; then
        valuestring=$(echo $valuestring | fold -w2 | tac | tr -d "\n")
    fi

    valuestring=${valuestring//$'\n'/}
    local value="${valuestring// /}"
    echo -n "$valuestring"
}

function url_encode {
    local input=$1
    local output=$(echo -n "$input" | base64 | sed 's/+/-/g; s/\//_/g;' | tr -d \\n | tr -d "=")
    echo -n "$output"
}

function url_encode_file {
    local inputfile=$1
    local output=$(cat "$inputfile" | base64 | sed 's/+/-/g; s/\//_/g;' | tr -d \\n | tr -d "=")
    echo -n "$output"
}

_decode_base64_url() {
  local len=$((${#1} % 4))
  local result="$1"
  if [ $len -eq 2 ]; then result="$1"'=='
  elif [ $len -eq 3 ]; then result="$1"'=' 
  fi
  echo "$result" | tr '_-' '/+' | base64 -d
}

# $1 => JWT to decode
# $2 => either 1 for header or 2 for body (default is 2)
decode_jwt() { _decode_base64_url $(echo -n $1 | cut -d "." -f ${2:-2}) | jq .; }

# Get SnpReport as Base64url
snpreport_base64=$(cat $reportfile | base64 )
snpreport_baseurl=$(url_encode_file $reportfile)

# Extract parameters from report
report_data=$(get_hex_data 80 64 false)
launch_measurement=$(get_hex_data 144 48 false)
host_data=$(get_hex_data 192 32 false)
reported_tcb=$(get_hex_data 384 8 true)
chip_id=$(get_hex_data 416 64 false)

# Fetch VCEK certificate, encode as Base64url
vcek_cert_url="https://global.acccache.azure.net/SevSnpVM/certificates/$chip_id/$reported_tcb?api-version=2020-10-15-preview"
vcek_cert_chain=$(curl -k -X GET -s "$vcek_cert_url")
vcek_cert_chain_baseurl=$(url_encode "$vcek_cert_chain")

# Generate Request.json for MAA request

reportjson="{ \"SnpReport\": \"$snpreport_baseurl\", \"VcekCertChain\": \"$vcek_cert_chain_baseurl\" }"
reportjson_baseurl=$(url_encode "$reportjson")

userdata=$(cat $userjson)
userdata_baseurl=$(url_encode_file $userjson)

printf "\nMAA Request: Include signtime configuration: $includesigntime"
if [ $includesigntime == "true" ]; then
    requestjson="{ \"report\": \"$reportjson_baseurl\", \"runtimeData\": { \"data\": \"$userdata_baseurl\", \"dataType\": \"JSON\" }, \"signTimeData\": { \"data\": \"$userdata_baseurl\", \"dataType\": \"JSON\" }, \"nonce\": \"$(date)\" }"
else
    requestjson="{ \"report\": \"$reportjson_baseurl\", \"runtimeData\": { \"data\": \"$userdata_baseurl\", \"dataType\": \"JSON\" }, \"nonce\": \"$(date)\" }"
fi

echo $requestjson | jq '.' > maarequest.json

printf "\n"
printf "===================================\n"
printf "Hash of TEE defined report: $report_data\n"
printf "Hash of application's config.json : $host_data\n"
printf "Hash of Guest Kernel/OS at launch : $launch_measurement\n"
printf "===================================\n"
#printf "Chip Id: $chip_id\n"
#printf "Platform TCB: $reported_tcb_display\n"
#printf "\n"
#printf "VCEK uri: $vcek_cert_url\n"
#printf "\n"
#printf "Certificate chain:\n $vcek_cert_chain\n"

# "maarequest.json" has the request params
# Post request to MAA

maarequest=$(cat maarequest.json)

printf "\nSending token request to MAA: $maaurl"
maaresponse=$(curl -s --header "Content-Type: application/json" --data "$maarequest" http://$maaurl/attest/SevSnpVm?api-version=2020-10-01)

# Extract token from response, write to output file, print
maatoken=$( echo -n "$maaresponse" | jq '.token' )
echo "$maatoken" > $maatokenfile
printf "\n"
printf "MAA token: "
decode_jwt "$maatoken"
printf "\n"
