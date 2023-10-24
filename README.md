<center><h1><b>HTTP-Proxy via SMTP-Mail tunnel</b></h1>

</center>

## info ##

This was a project for the course "Internet Security, Data-Protection and Forensics" of my university (FernUniversität in Hagen - Germany) in 2023. The goal was to transfer the whole internet traffic of a browser on the client-machine by mail to a server-machine which then forwards the traffic to the internet. The client-machine should use the server-machine as a http-proxy.

In the current state it is recommended to test smtpsurfer with curl. see below for instructions.

smtpsurfer can transport http-traffic without problems but https-traffic is not working right now. the tls-handshake seems to be corrupted on its way. i think it may be a problem on the server side (mailproxy-machine) which does indeed receive the correct client-hello but it's answer does contain some kind of error.

after terminating smtpsurfer it is recommended to run `smtpsurfer kill` to clean up processes as subprocesss-termination does not work for python right now.

## requirements ##

- 2 machines or virtual machines:
  - client to surf
  - server to proxy
- OS tested:
  - arch-2023.04.01 (manjaro)
  - debian-bullseye (ubuntu)
- define in same local network
- do either
  - set a static ipv4 for each
  - get an ipv4 by dhcp for each

## Install ##

For client or server:
```
bash script/client_install.sh
bash script/server_install.sh
```

## Run ##

After reboot you run the client or server with command:
```
smtpsurfer [run|kill]
```

## Logging

The logfiles are located in `/smtpsurfer` as `log` for tunnel and `logpy` for the initial base64 encoding python script.

# IMPORTANT #

Your DNS server may rate-limit the NXDOMAIN requests performed by postfix sendmail.

For pihole e.g. you have to turn off RATE_LIMIT in `pihole-FTL.conf` or via `UI`

# DEBUG #

## run only tunnel and debug with curl ##

open terminal and run:

client (mailsurfer):
```
sudo socat tcp-l:8080,fork SYSTEM:"python3 /smtpsurfer/python/client_socat.py | /smtpsurfer/shell/client_tunnel.sh"
```

server (mailproxy):
```
sudo socat tcp-l:8080,fork SYSTEM:"/smtpsurfer/shell/server_tunnel.sh"
sudo mitmdump -p 9090
```

client: curl tunnel for http or https url:
```
curl --verbose "https://www.google.com//" --proxy "http://localhost:8080"
```


## server mail receiving ##
```
echo -e "MAPPING=\n12345\nBODY=\nCONNECT www.google.com:443 HTTP/1.1" | sendmail -i smtpsurfer@mailproxy
```

## test request to google ##
```
GET http://www.google.com/ HTTP/1.1\nHost: www.google.com\nUser-Agent: curl/8.1.2\nAccept: */*\nProxy-Connection: Keep-Alive\r\n\r\n
```