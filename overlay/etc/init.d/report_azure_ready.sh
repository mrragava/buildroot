#!/bin/sh

# Initialize name of temp xml files
azure_goalstate_xml="azure_goalstate.xml"
azure_reportreadypretty_xml="azure_reportready_pretty.xml"
azure_reportready_xml="azure_reportready.xml"

# Fetch goal state
curl -X GET -H 'x-ms-version: 2012-11-30' http://168.63.129.16/machine?comp=goalstate > "$azure_goalstate_xml"

# Helper functions

function get_xml_value {
    local xmlfile=$1
    local xpath=$2
    local valuestring=$(xmllint --xpath "$xpath" "$xmlfile")
    echo -n "$valuestring"
}

# Extract xml values needed for azure handshake
az_incarnation=$(get_xml_value "$azure_goalstate_xml" "string(/GoalState/Incarnation)" )
az_containerid=$(get_xml_value "$azure_goalstate_xml" "string(/GoalState/Container/ContainerId)" )
az_instanceid=$(get_xml_value "$azure_goalstate_xml" "string(/GoalState/Container/RoleInstanceList/RoleInstance/InstanceId)" )


printf "\n"
printf "===================================\n"
printf "Azure incarnation  : $az_incarnation\n"
printf "Azure container id : $az_containerid\n"
printf "Azure instance id  : $az_instanceid\n"
printf "===================================\n"

# Prepare report ready xml

health="<Health>
  <GoalStateIncarnation>$az_incarnation</GoalStateIncarnation>
  <Container>
    <ContainerId>$az_containerid</ContainerId>
    <RoleInstanceList>
      <Role>
        <InstanceId>$az_instanceid</InstanceId>
        <Health>
          <State>Ready</State>
        </Health>
      </Role>
    </RoleInstanceList>
  </Container>
</Health>"

echo -n "$health" > "$azure_reportready_xml"

xmllint --format "$azure_reportready_xml"  >"$azure_reportreadypretty_xml"

# Post report ready to azure

report_ready_xml=$(cat "$azure_reportreadypretty_xml")

printf "Posting azure report ready xml: \n"
printf "$report_ready_xml"
printf "\n"

curl -X POST -H 'x-ms-version: 2012-11-30' -H "x-ms-agent-name: WALinuxAgent" -H "Content-Type: text/xml;charset=utf-8" -d "$report_ready_xml" http://168.63.129.16/machine?comp=health

# Set hostname using metadata

az_hostname="$(curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-02-01&format=text")"
printf "Setting hostname: $az_hostname\n"
echo "$az_hostname" > /etc/hostname
hostname -F /etc/hostname

