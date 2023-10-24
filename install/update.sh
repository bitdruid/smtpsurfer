# copy all scripts to dirs

if [ $(hostname) = "mailsurfer" ]; then
    cp script/python/client_socat.py /smtpsurfer/python/client_socat.py
    cp script/shell/client_mail.sh /smtpsurfer/shell/client_mail.sh && chmod +x /smtpsurfer/shell/client_mail.sh
    cp script/shell/client_tunnel.sh /smtpsurfer/shell/client_tunnel.sh && chmod +x /smtpsurfer/shell/client_tunnel.sh
    cp run/smtpsurfer.sh /usr/bin/smtpsurfer && chmod +x /usr/bin/smtpsurfer
    cp config/konsole.tabs /smtpsurfer
elif [ $(hostname) = "mailproxy" ]; then
    cp script/shell/server_mail.sh /smtpsurfer/shell/server_mail.sh && chmod +x /smtpsurfer/shell/server_mail.sh
    cp script/shell/server_tunnel.sh /smtpsurfer/shell/server_tunnel.sh && chmod +x /smtpsurfer/shell/server_tunnel.sh
    cp run/smtpsurfer.sh /usr/bin/smtpsurfer && chmod +x /usr/bin/smtpsurfer
    cp config/konsole.tabs /smtpsurfer
fi

chmod -R 777 /smtpsurfer