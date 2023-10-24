#!/bin/bash

# force sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

ownip=""
serverip=""
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
    echo "Insert server-IP:"
    read serverip
    echo "Your client-IP is: $ownip"
    echo "Your network CIDR is: $networkcidr"
    echo "You set server-IP: $serverip"
    echo ""
    echo "Is this correct? (y/n)"
    read correct
    echo ""
    while [ $correct != "y" ]; do
        echo "Auto determine network settings..."
        get_network
        echo ""
        echo "Insert server-IP:"
        read serverip
        echo "Your client-IP is: $ownip"
        echo "Your network CIDR is: $networkcidr"
        echo "You set server-IP: $serverip"
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

# set hostname for client // set DNS for Server
echo "mailsurfer" > /etc/hostname
echo "$serverip mailproxy" >> /etc/hosts

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

# configure postfix for client
mkdir -p /etc/postfix
cat config/mailsurfer_postfix.conf > /etc/postfix/main.cf
echo "/.*/ root" >> /etc/postfix/virtual
echo 'smtpsurfer: "|/smtpsurfer/shell/client_mail.sh"' >> /etc/aliases
echo "somebody: root" >> /etc/aliases
# set mynetwork to cidr
sed -i "s/mynetworks = $networkcidr/mynetworks = $networkcidr/g" /etc/postfix/main.cf
postalias /etc/aliases
postmap /etc/postfix/virtual
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

# copy scripts for client
cp script/python/client_socat.py /smtpsurfer/python/client_socat.py
cp script/shell/client_mail.sh /smtpsurfer/shell/client_mail.sh && chmod +x /smtpsurfer/shell/client_mail.sh
cp script/shell/client_tunnel.sh /smtpsurfer/shell/client_tunnel.sh && chmod +x /smtpsurfer/shell/client_tunnel.sh
cp run/smtpsurfer.sh /usr/bin/smtpsurfer && chmod +x /usr/bin/smtpsurfer

# install python3
if [ $base -eq 1 ]; then
    pamac install python3 --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install python3 -y
fi

# install chromium
if [ $base -eq 1 ]; then
    pamac install chromium --no-confirm
elif [ $base -eq 2 ]; then
    apt-get install chromium-browser -y
fi

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
        
reboot now? (y/n)'
read reboot
if [ $reboot == "y" ]; then
    reboot
fi