#!/bin/bash
data_stdin_timeout=0.1
data_stdin_interval=0.005
data_stdin_counter=5
#data_stdin_counter=$(bc <<< "$data_stdin_timeout / $data_stdin_interval")
http_methods=(/0x47/0x45/0x54 /0x50/0x4F/0x53/0x54 /0x50/0x55/0x54 /0x44/0x45/0x4C/0x45/0x54/0x45 /0x48/0x45/0x41/0x44 /0x4F/0x50/0x54/0x49/0x4F/0x4E/0x53 /0x43/0x4F/0x4E/0x4E/0x45/0x43/0x54 /0x54/0x52/0x41/0x43/0x45 /0x50/0x41/0x54/0x43/0x48)
# == GET, POST, PUT, DELETE, HEAD, OPTIONS, CONNECT, TRACE, PATCH
input_data=""
input_current_size=0
input_last_size=1

function send_stdout() {
    input_to_base64=$1
    if [[ -z $input_to_base64 ]]; then return; fi
    base64_string=$(base64 -w 0 <<< "$input_to_base64")
    echo -e "$base64_string\n>>>EOF<<<"
}

function read_stdin() {
    local char
    local count=0
    while true; do
        char=$(dd if=/dev/stdin bs=1 count=1 status=none | xxd -ps)
        if [[ -n $char ]]; then
            input_data+="/0x"$char
            echo -e "Current input: $input_data"
        fi
        if [[ $count -gt $data_stdin_counter ]]; then
            count=0
            input_current_size=$(wc -c <<< "$input_data" | awk '{print $1-1}')
            #echo "Input current size: $input_current_size"
            #echo "Input last size: $input_last_size"
            # if input_data is not empty then there was received data on stdin
            if ! [[ $input_data == "" ]]; then
                #echo "=== INPUT NOT EMPTY"
                # if input_data size did not change it means stdin is complete
                if [[ $input_current_size -eq $input_last_size ]]; then 
                    #echo "=== STDIN COMPLETE"
                    for method in "${http_methods[@]}"; do
                        echo -e "Method: $method"
                        echo -e "Compare to: $input_data"
                        if [[ "$input_data" == "$method"* ]]; then is_http_method=1; fi; 
                    done
                    if [[ $is_http_method == 1 ]]; then
                        if [[ "$input_data" == *$'/0x5c/0x72/0x5c/0x6e/0x5c/0x72/0x5c/0x6e'* ]]; then # == \r\n\r\n
                            echo "=== HTTP ==="; send_stdout "$input_data"; input_data=""
                        else
                            echo "=== HTTP ERROR ==="; input_data="";
                            input_data="";
                        fi
                    else
                        echo "=== BIN ==="; send_stdout "$input_data"; input_data=""
                    fi
                fi
                input_last_size=$input_current_size
                input_current_size=0
            fi
        fi
        count=$((count + 1))
        sleep $data_stdin_interval
    done
}

read_stdin

