#!/bin/bash

# must be root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi
base=0
# check if arch set 1 or debian set 2
if [ -f /etc/arch-release ]; then
    base=1
elif [ -f /etc/debian_version ]; then
    base=2
fi

check_crt() {
    if [ $(hostname) = "mailsurfer" ]; then
        cert="/smtpsurfer/cert/mitmproxy-ca-cert.pem"
        if [[ ! -f "$cert" ]]; then
            echo "________________________________________________________"
            echo "Server certificate not found!"
            echo "Contacting server for certificate..."
            for i in {1..4}; do
                if [ ! -f "$cert" ]; then
                    request_crt
                    sleep 5
                else
                    echo ""
                    echo "Server certificate received!"
                    echo "Installing certificate..."
                    echo ""
                    if [ $base -eq 1 ]; then
                        sudo trust anchor --store "$cert"
                    elif [ $base -eq 2 ]; then
                        sudo mkdir -p /usr/local/share/ca-certificates
                        sudo cp /smtpsurfer/cert/server.crt /usr/local/share/ca-certificates/server.crt
                        sudo update-ca-certificates
                    fi
                    echo "---> Certificate installed!"
                    echo "________________________________________________________"
                    return 0
                fi
            done
            echo "Server certificate not received!"
            echo "Is the server already installed?"
            echo "________________________________________________________"
            exit 1
        fi
    fi
}

request_crt(){
    echo -e "REQUEST_CRT: SERVER CERT NOT FOUND!" >> /smtpsurfer/log.sh
    mapping="REQUEST_CRT"
    body=""
    mailtext='MAPPING=\n'"$mapping"'\nBODY=\n'"$body"
    echo -e "$mailtext" | sendmail -i smtpsurfer@mailproxy
    echo -e "REQUEST_CRT: REQUESTING SERVER CERT..." >> /smtpsurfer/log.sh
}

kill_processes() {
    killall -9 smtpsurfer
    killall -9 nc
    killall -9 socat
    killall -9 chromium
    killall -9 sendmail
    killall -9 python3
    killall -9 mitmdump
    rm -rf /smtpsurfer/temp/*
    chmod -R 777 /smtpsurfer
}

chromium=''
if [[ $1 == "run" ]];
then
    if [ $(hostname) = "mailsurfer" ]; then
        chmod -R 777 /smtpsurfer
        check_crt
        bash -c "konsole --tabs-from-file /smtpsurfer/konsole.tabs" &
        socat tcp-l:8080,fork SYSTEM:"python3 /smtpsurfer/python/client_socat.py | /smtpsurfer/shell/client_tunnel.sh" &
        chromium --no-sandbox --proxy-server=http://localhost:8080
        if [[ $? -eq 0 ]]; 
        then
            kill_processes
        fi
    elif [ $(hostname) = "mailproxy" ]; then
        chmod -R 777 /smtpsurfer
        bash -c "konsole --tabs-from-file /smtpsurfer/konsole.tabs" &
        socat tcp-l:8080,fork SYSTEM:"/smtpsurfer/shell/server_tunnel.sh" 2>&1 &
        mitmdump -p 9090 --ssl-insecure
        if [[ $? -eq 0 ]]; 
        then
            kill_processes
        fi
    fi
elif [[ $1 == "kill" ]]; 
then
    kill_processes
else
    echo "Usage: smtpsurfer [run|kill]"
fi
