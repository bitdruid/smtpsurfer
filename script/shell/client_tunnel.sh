#!/bin/bash

send_request() {
    body=$(cat "$request_mapping_file")
    body_preview=$(cat "$request_mapping_file" | head -n 1)
    mailtext='MAPPING=\n'"$mapping"'\nBODY=\n'"$body"
    echo -e "$mailtext" | sendmail -i smtpsurfer@mailproxy
    echo -e "$mapping: SENT REQUEST TO SERVER: --- $body_preview" >> /smtpsurfer/log.sh 
}

get_response() {
    # read input from the response_mapping_file and cat it to socat
    # response_mapping_file has to be truncated to prevent reading old data again
    echo -e "$mapping: WAITING FOR RESPONSE FROM SERVER: --- $response_mapping_file" >> /smtpsurfer/log.sh
    while true; do
        sleep 0.1
        if [ -s "$response_mapping_file" ]; then
            break
        fi
    done
    response=$(base64 "$response_mapping_file")
    response_pure_preview=$(cat "$response_mapping_file" | head -c 25)
    echo -e "===========================================" >> /smtpsurfer/log.sh
    echo -e "$mapping: CLIENT_TUNNEL @ $timedate" >> /smtpsurfer/log.sh
    echo -e "===========================================" >> /smtpsurfer/log.sh
    cat "$response_mapping_file"
    echo -e "$mapping: RECEIVED RESPONSE FROM SERVER: --- preview: $response_pure_preview" >> /smtpsurfer/log.sh
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
    echo -e "$response" >> /smtpsurfer/log.sh
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
    truncate -s 0 "$response_mapping_file"
}

check_orphaned_process () {
    ##### unstable #####
    # count time for the last access to the request_mapping_file
    # if the request_mapping_file is older than XX seconds, the processes are orphaned
    # all subprocess pids are stored and then killed
    pids=$(pgrep -P $$)
    for pid in $pids; do
        pids="$pids $(pgrep -P $pid)"
    done
    pid=$1
    max_time=10
    while true; do
        sleep $max_time
        if [ $(wc -l < /smtpsurfer/log.sh) -gt 5000 ]; then
            sed -i '1,1000d' /smtpsurfer/log.sh
        fi
        if [ -e "$request_mapping_file" ]; then
            # last modified time of the request_mapping_file
            # difference between current time and last modified time
            last_modified=$(stat -c %Y "$request_mapping_file")
            current_time=$(date +%s)
            time_diff=$((current_time - last_modified))
            if [ $time_diff -gt $max_time ]; then
                echo -e "$mapping: CLIENT PORT DIED: --- PID $pid" >> /smtpsurfer/log.sh
                rm "$request_mapping_file"
                for pid in $pids; do
                    echo -e "$mapping: CLIENT PORT DIED: --- $pid" >> /smtpsurfer/log.sh
                    kill -9 $pid
                done
                kill -9 $pid
                kill -9 $BASHPID
            fi
        else
            echo -e "$mapping: CLIENT PORT DIED: --- PID $pid" >> /smtpsurfer/log.sh
            rm "$request_mapping_file"
            rm "$response_mapping_file"
            for pid in $pids; do
                echo -e "$mapping: CLIENT PORT DIED: --- $pid" >> /smtpsurfer/log.sh
                kill -9 $pid
            done
            kill -9 $pid
            kill -9 $BASHPID
        fi
    done
}

# 1. prepare the needed mapping files
# mapping is the client connected port
# - .request declares the file for the request from machine1
# - .response declares the file for the response from machine2
# the mapping is used to identify the process
request=""
pid=$SOCAT_PID
mapping=$SOCAT_PEERPORT
request_mapping="$mapping.request"
response_mapping="$mapping.response"
request_mapping_file="/smtpsurfer/temp/$request_mapping"
response_mapping_file="/smtpsurfer/temp/$response_mapping"
touch "$request_mapping_file"
touch "$response_mapping_file"
chmod -R 777 /smtpsurfer
timedate=$(date +"%Y-%m-%d %H:%M:%S")
echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "INIT: CLIENT_TUNNEL @ $timedate" >> /smtpsurfer/log.sh
echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "$mapping: REQUEST_MAPPING CREATED: --- $request_mapping" >> /smtpsurfer/log.sh
echo -e "$mapping: RESPONSE_MAPPING CREATED: --- $response_mapping" >> /smtpsurfer/log.sh

# 2. read the request from socat pipe
# it comes from the client, gets into a python script
# the python script encodes the request as base64
# the base64 encoded request is received here
while IFS= read -r line; do
    sleep 0.01
    if [[ $line == *">>>EOF<<<"* ]]; then
        echo -e "$mapping: INIT: RECEIVED REQUEST FROM CLIENT: --- $request_mapping_file" >> /smtpsurfer/log.sh
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
        echo -e "$request" >> /smtpsurfer/log.sh
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
        echo -e "$request" > "$request_mapping_file"
        request=""
        send_request &
        get_response &
        check_orphaned_process "$pid" &
    else
        request+="$line"$'\n'
    fi
done