#!/bin/bash

# mail is piped to this script
# the script extracts the mapping and the body
# mapping = port of client
# body = data (request, response, binary)
# sed removes the mailheader and splits the mail into mapping and body
[ $# -ge 1 -a -f "$1" ] && input="$1" || input="-"
data=$(cat "$input" | sed '1,/From:/d')
mapping=$(sed -n '/MAPPING=/ {n;p}' <<< "$data")                   
body=$(sed -n '/BODY=/ {n; p; :a; n; p; ba;}' <<< "$data")
body_preview=$(echo "$body" | head -n 1)
response="$body"

# if server sent the proxy cert, store it
if [[ "$mapping" == "SERVER_CRT" ]]; then
    echo -e "SERVER_CRT: RECEIVED SERVER CERT" >> /smtpsurfer/log.sh
    echo -e "$body" | base64 --decode > /smtpsurfer/cert/mitmproxy-ca-cert.pem
    echo -e "SERVER_CRT: STORED SERVER CERT" >> /smtpsurfer/log.sh
    exit 0
fi

# responses are handled here, decoded and stored inside the response_mapping_file
timedate=$(date +"%Y-%m-%d %H:%M:%S")
response_mapping="$mapping.response"
response_mapping_file="/smtpsurfer/temp/$response_mapping"

echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "CLIENT_MAIL @ $timedate" >> /smtpsurfer/log.sh
echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "$mapping: RECEIVED MAPPING: --- $mapping" >> /smtpsurfer/log.sh
echo -e "$mapping: RECEIVED BODY: --- $body_preview" >> /smtpsurfer/log.sh
echo -e "$mapping: STORED RESPONSE IN FILE: --- $response_mapping_file" >> /smtpsurfer/log.sh
echo -e "$response" | base64 --decode > "$response_mapping_file"