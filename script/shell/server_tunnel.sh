#!/bin/bash

get_request () {
    # doesnt matter if there is a new request or a further one
    # the function loops infinitely and waits for a new request at its request_mapping_file
    while true; do
        sleep 0.1
        if [ -s "$request_mapping_file" ]; then
            request=$(cat "$request_mapping_file")
            request_preview=${request:0:25}
            echo -e "$mapping: RECEIVED REQUEST FROM CLIENT: --- preview:" >> /smtpsurfer/log.sh
            echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
            echo -e "$request_preview" >> /smtpsurfer/log.sh
            echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
            echo -e "$mapping: SENDING REQUEST INTO PROXY_PIPE..." >> /smtpsurfer/log.sh
            cat "$request_mapping_file" | base64 --decode >&3
            truncate --size 0 "$request_mapping_file"
            echo -e "$mapping: TRUNCATED REQUEST_MAPPING_FILE: --- $request_mapping_file" >> /smtpsurfer/log.sh
        fi
    done
}

get_response () {
    # wait until ipc_pipe exists
    # ipc_pipe is streaming the request to the proxy and the response into the response_mapping_file
    while [ ! -p "$ipc_pipe" ]; do
        sleep 1
    done
    echo -e "$mapping: PREPARE: CONNECTING TO PROXY..." >> /smtpsurfer/log.sh
    <&3 nc localhost 9090 > "$response_mapping_file"
    echo -e "$mapping: PREPARE: CONNECTION TO PROXY ESTABLISHED..." >> /smtpsurfer/log.sh
}

send_response() {
    # after the proxy has sent the response, it is stored into the response_mapping_file
    # the loop picks up the response and sends it to the client
    while true; do
        sleep 0.1
        if [ -s "$response_mapping_file" ]; then
            response_pure=$(cat "$response_mapping_file")
            response_pure_preview=${response_pure:0:25}
            response=$(base64 "$response_mapping_file")
            echo -e "$mapping: RECEIVED RESPONSE FROM PROXY: --- preview: $response_pure_preview" >> /smtpsurfer/log.sh
            mailtext='MAPPING=\n'"$mapping"'\nBODY=\n'"$response"
            echo -e "$mailtext" | sendmail -i smtpsurfer@mailsurfer
            echo -e "$mapping: SENT RESPONSE TO CLIENT: --- preview: $response_pure_preview" >> /smtpsurfer/log.sh
            echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
            echo -e "$response" >> /smtpsurfer/log.sh
            echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> /smtpsurfer/log.sh
            truncate --size 0 "$response_mapping_file"
            echo -e "$mapping: TRUNCATED RESPONSE_MAPPING_FILE: --- $response_mapping_file" >> /smtpsurfer/log.sh
        fi
    done
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
    max_time=10
    while true; do
        sleep $max_time
        if [ $(wc -l < /smtpsurfer/log.sh) -gt 5000 ]; then
            sed -i '1,1000d' /smtpsurfer/log.sh
        fi
        if [ -e "$request_mapping_file" ]; then
            current_time=$(date +%s)
            time_diff=$((current_time - last_modified))
            if [ $time_diff -gt $max_time ]; then
                rm "$request_mapping_file"
                rm "$response_mapping_file"
                rm "$ipc_pipe"
                for pid in $pids; do
                    echo -e "$mapping: CLIENT PORT DIED: --- $pid" >> /smtpsurfer/log.sh
                    kill -9 $pid
                done
                proxypid=$(ps aux | grep "ncat" | grep "$mapping" | awk '{print $2}')
                kill -9 $proxypid
                kill -9 $BASHPID
            fi
        else
            rm "$request_mapping_file"
            rm "$response_mapping_file"
            rm "$ipc_pipe"
            for pid in $pids; do
                echo -e "$mapping: CLIENT PORT DIED: --- $pid" >> /smtpsurfer/log.sh
                kill -9 $pid
            done
            proxypid=$(ps aux | grep "ncat" | grep "$mapping" | awk '{print $2}')
            kill -9 $proxypid
            kill -9 $BASHPID
        fi
    done
}

# SCRIPT STARTS HERE
# mapping represents the port number of the client
# each mapping gets a request and a response file
# ipc_pipe is used for communication between the request and response loop
# 1. if a mail arrives, server_mail.sh has 2 possible handlings:
# 1.1. if the mapping is new, there is no request and response file
#      the mapping is sent via netcat to socat, which forks a new process
#      the request itself is stored into the request_mapping_file
#      the subprocess of this script takes the request_mapping_file and handles the request
# 1.2. if the mapping is already known (request and response file exists) mapping is not sent
#      only the request itself is stored into the request_mapping_file
# the script works as follows:
# mapping arrives and the according files are associated
# request data is already stored in the request_mapping_file
# get_request loops infinitely, takes the request, decodes base64, puts it into the ipc_pipe
# get_response loops infinitely, it reads the response from the ipc_pipe, sends to proxy, stores into response_mapping_file
# send_response loops infinitely, it reads the response from the response_mapping_file, encodes base64, sends to client
# check_orphaned_process loops infinitely, it checks if the request_mapping_file is older than XX seconds and kills all processes
timedate=$(date +"%Y-%m-%d %H:%M:%S")
mapping=""
read -r mapping
echo -e "===========================================" >> /smtpsurfer/log.sh
echo -e "INIT: SERVER_TUNNEL @ $timedate" >> /smtpsurfer/log.sh
echo -e "===========================================" >> /smtpsurfer/log.sh
request_mapping="$mapping.request"
response_mapping="$mapping.response"
request_mapping_file="/smtpsurfer/temp/$request_mapping"
response_mapping_file="/smtpsurfer/temp/$response_mapping"
ipc_pipe="/smtpsurfer/temp/$mapping.ipc"
mkfifo "$ipc_pipe"
exec 3<> "$ipc_pipe"
chmod -R 777 /smtpsurfer
echo -e "$mapping: INIT: REQUEST_MAPPING RECEIVED: --- $request_mapping" >> /smtpsurfer/log.sh
echo -e "$mapping: INIT: RESPONSE_MAPPING CREATED: --- $response_mapping" >> /smtpsurfer/log.sh
echo -e "$mapping: INIT: PROXY_PIPE CREATED: --- $ipc_pipe" >> /smtpsurfer/log.sh
get_request &
get_response &
send_response &
check_orphaned_process
