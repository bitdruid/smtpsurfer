#!/bin/bash

# mail is piped to this script
# the script extracts the mapping and the body
# mapping = port of client
# body = data (request, response, binary)
# sed removes the mailheader and splits the mail into mapping and body
[ $# -ge 1 -a -f "$1" ] && input="$1" || input="-"
data=$(cat "$input" | sed '1,/From:/d')
data=$(sed '/^$/d' <<< "$data")
mapping=$(sed -n '/MAPPING=/ {n;p}' <<< "$data")
body=$(sed -n '/BODY=/ {n; p; :a; n; p; ba;}' <<< "$data")
request="$body"

# if client requests the proxy cert, send it
if [[ "$mapping" == "REQUEST_CRT" ]]; then
    echo -e "REQUEST_CRT: RECEIVED REQUEST FOR SERVER CERT" >> /smtpsurfer/log.sh
    mapping="SERVER_CRT"
    body=$(base64 /smtpsurfer/cert/mitmproxy-ca-cert.pem)
    mailtext='MAPPING=\n'"$mapping"'\nBODY=\n'"$body"
    echo -e "$mailtext" | sendmail -i smtpsurfer@mailsurfer
    echo -e "REQUEST_CRT: SENT SERVER CERT TO CLIENT" >> /smtpsurfer/log.sh
    exit 0
fi

##### RESPONSE WITH FORKING
timedate=$(date +"%Y-%m-%d %H:%M:%S")
echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "SERVER_MAIL @ $timedate" >> /smtpsurfer/log.sh
echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "RECEIVED MAPPING: --- $mapping" >> /smtpsurfer/log.sh
echo -e "RECEIVED BODY: --- $body" >> /smtpsurfer/log.sh

# fork a process if there is no mapping_file
# no mapping_file means, its the first request by this client-port (browser machine1)
# create the mapping_files and send the request to socat to fork a new process
request_mapping="$mapping.request"
response_mapping="$mapping.response"
request_mapping_file="/smtpsurfer/temp/$request_mapping"
response_mapping_file="/smtpsurfer/temp/$response_mapping"
# if new client, create mapping_file and send mapping to socat
if [ ! -e "$request_mapping_file" ]; then
    echo -e "MAPPING_FILE MISSING: --- $request_mapping" >> /smtpsurfer/log.sh
    touch "$request_mapping_file"
    touch "$response_mapping_file"
    echo -e "MAPPING_FILE CREATED: --- $request_mapping_file" >> /smtpsurfer/log.sh
    echo -e "$request" > "$request_mapping_file"
    echo -e "$mapping" | nc localhost 8080
# if mapping_file exists, send request to mapping_file
elif [ -e "$request_mapping_file" ]; then
    echo -e "MAPPING_FILE EXISTS: --- $request_mapping" >> /smtpsurfer/log.sh
    echo -e "$request" > "$request_mapping_file"
fi

