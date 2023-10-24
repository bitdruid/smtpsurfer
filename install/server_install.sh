#!/bin/bash

# force sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

ownip=""
clientip=""
cidr=""
network=""
networkcidr=""

get_network () {
    ownip=$(ip addr show | grep -E "inet.*brd" | grep -v "inet6" | awk '{print $2}' | awk -F "/" '{print $1}' | head -n 1)
    cidr=$(ip addr show | grep -E "inet.*brd" | grep -v "inet6" | awk '{print $2}' | awk -F "/" '{print $2}' | head -n 1)
    network=$(ip addr show | grep -E "inet.*brd" | grep -v "inet6" | awk '{print $2}' | awk -F "/" '{print $1}' | awk -F "." '{print $1"."$2"."$3".0"}' | head -n 1)
    # network cidr
    networkcidr="$network/$cidr"
}

echo "________________________________________________________"
echo "Auto determine network settings? (y/n)"
read auto
echo ""
if [ $auto == "y" ]; then
    echo "Auto determine network settings..."
    get_network
    echo ""
    echo "Insert client-IP:"
    read clientip
    echo "Your server-IP is: $ownip"
    echo "Your network CIDR is: $networkcidr"
    echo "You set client-IP: $serverip"
    echo ""
    echo "Is this correct? (y/n)"
    read correct
    echo ""
    while [ $correct != "y" ]; do
        echo "Auto determine network settings..."
        get_network
        echo ""
        echo "Insert client IP:"
        read clientip
        echo "Your server-IP is: $ownip"
        echo "Your network CIDR is: $networkcidr"
        echo "You set client-IP: $serverip"
        echo ""
        echo "Is this correct? (y/n)"
        read correct
        echo ""
    done
elif [ $auto == "n" ]; then
    echo "Insert server IP:"
    read serverip
    echo "Insert client IP:"
    read clientip
    echo "Insert network CIDR:"
    read networkcidr
    echo ""
    echo "You set serverip: $serverip"
    echo "You set clientip: $clientip"
    echo "You set network CIDR: $networkcidr"
    echo ""
    echo "Is this correct? (y/n)"
    read correct
    echo ""
    while [ $correct != "y" ]; do
        echo "Insert server IP:"
        read serverip
        echo "Insert client IP:"
        read clientip
        echo "Insert network CIDR:"
        read networkcidr
        echo ""
        echo "You set serverip: $serverip"
        echo "You set clientip: $clientip"
        echo "You set network CIDR: $networkcidr"
        echo ""
        echo "Is this correct? (y/n)"
        read correct
        echo ""
    done
else
    echo "Wrong input!"
    exit 1
fi
echo ""
echo "________________________________________________________"

# set hostname for server // set DNS for Client
echo "mailproxy" > /etc/hostname
echo "$clientip mailsurfer" >> /etc/hosts

# set editor to nano
echo "export EDITOR=nano" >> /etc/bash.bashrc
source /etc/bash.bashrc

# set directory for smtpsurfer
mkdir -p /smtpsurfer/{shell,python,temp,cert}
chmod -R 777 /smtpsurfer

base=0
# check if arch set 1 or debian set 2
if [ -f /etc/arch-release ]; then
    base=1
elif [ -f /etc/debian_version ]; then
    base=2
fi

# update system
if [ $base -eq 1 ]; then
    pamac update --no-confirm
elif [ $base -eq 2 ]; then
    apt-get update
    apt-get upgrade -y
fi

# install konsole
if [ $base -eq 1 ]; then
    pamac install konsole --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install konsole -y
fi
# move konsole tabs to /smtpsurfer
cp config/konsole.tabs /smtpsurfer/konsole.tabs

# install postfix / sendmail
if [ $base -eq 1 ]; then
    pamac install postfix mailutils --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install postfix mailutils -y
fi
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections

# configure postfix for server
mkdir -p /etc/postfix
cat config/mailproxy_postfix.conf > /etc/postfix/main.cf
echo "/.*/ root" >> /etc/postfix/virtual
postmap /etc/postfix/virtual
echo 'smtpsurfer: "|/smtpsurfer/shell/server_mail.sh"' >> /etc/aliases
echo "somebody: root" >> /etc/aliases
sed -i "s/mynetworks = $networkcidr/mynetworks = $networkcidr/g" /etc/postfix/main.cf
postalias /etc/aliases
systemctl enable --now postfix

# install gnu-netcat
if [ $base -eq 1 ]; then
    pamac install gnu-netcat --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install netcat -y
fi

# install socat
if [ $base -eq 1 ]; then
    pamac install socat --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install socat -y
fi

#####                                         #####
##### different configs for server and client #####
#####                                         #####

# copy scripts for server
cp script/shell/server_mail.sh /smtpsurfer/shell/server_mail.sh && chmod +x /smtpsurfer/shell/server_mail.sh
cp script/shell/server_tunnel.sh /smtpsurfer/shell/server_tunnel.sh && chmod +x /smtpsurfer/shell/server_tunnel.sh
cp run/smtpsurfer.sh /usr/bin/smtpsurfer && chmod +x /usr/bin/smtpsurfer

# install mitmproxy
if [ $base -eq 1 ]; then
    pamac install mitmproxy --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install mitmproxy -y
fi

# set mitmproxy ca-cert
sudo mitmdump -p 9090 &
sleep 2
wget -e use_proxy=yes -e http_proxy=localhost:9090 http://mitm.it/cert/pem -O /smtpsurfer/cert/mitmproxy-ca-cert.pem
if [ $base -eq 1 ]; then
    sudo trust anchor --store /smtpsurfer/cert/mitmproxy-ca-cert.pem
elif [ $base -eq 2 ]; then
    sudo mkdir -p /usr/local/share/ca-certificates
    sudo cp /smtpsurfer/cert/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.pem
    sudo update-ca-certificates
fi
killall mitmdump

# # build nginx with connect and perl module
# wget http://nginx.org/download/nginx-1.24.0.tar.gz
# git clone https://github.com/chobits/ngx_http_proxy_connect_module
# tar -xvzf nginx-1.24.0.tar.gz
# cd nginx-1.24.0
# patch -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch
# ./configure --add-module=../ngx_http_proxy_connect_module --with-http_ssl_module --with-http_perl_module
# make && make install && cd .. && rm -rf nginx-1.24.0 nginx-1.24.0.tar.gz ngx_http_proxy_connect_module

# # configure nginx for server
# mkdir -p /etc/nginx/conf.d /var/log/nginx
# cp config/mailproxy_nginx.conf /etc/nginx/nginx.conf
# cp config/mailproxy_nginx_confd.conf /etc/nginx/conf.d/mailproxy.conf
# sudo /usr/local/nginx/sbin/nginx -s stop
# sleep 2
# sudo /usr/local/nginx/sbin/nginx -c /etc/nginx/nginx.conf

# # install squid
# if [ $base -eq 1 ]; then
#     pamac install squid --no-confirm
# elif [ $base -eq 2 ]; then
#     apt-get install squid -y
# fi

# # configure squid for server
# sed -i "s/http_port 3128/http_port 9090/g" /etc/squid/squid.conf
# sed -i "s/# http_access allow localnet/http_access allow localnet/g" /etc/squid/squid.conf # allow localnet
# systemctl enable --now squid

# # create certificate for forward proxy
# FILENAME="/smtpsurfer/cert/server"
# openssl genrsa -out $FILENAME.key 2048
# openssl req -new -key $FILENAME.key -x509 -days 3653 -out $FILENAME.crt -subj "/CN=localhost"
# cat $FILENAME.key $FILENAME.crt >$FILENAME.pem
# chmod 600 $FILENAME.key $FILENAME.pem
# if [ $base -eq 1 ]; then
#     sudo trust anchor --store $FILENAME.crt
# elif [ $base -eq 2 ]; then
#     sudo mkdir -p /usr/local/share/ca-certificates
#     sudo cp $FILENAME.crt /usr/local/share/ca-certificates/server-ca-cert.crt
#     sudo update-ca-certificates
# fi

touch /smtpsurfer/log.sh
touch /smtpsurfer/logpy.sh
chmod -R 777 /smtpsurfer

echo '
    ______ _____ _   _  _____ 
    |  _  \  _  | \ | ||  ___|
    | | | | | | |  \| || |__  
    | | | | | | | . ` ||  __| 
    | |/ /\ \_/ / |\  || |___ 
    |___/  \___/\_| \_/\____/ 

        REBOOT REQUIRED

reboot now? [y/n]'
read reboot
if [ $reboot == "y" ]; then
    reboot
fi