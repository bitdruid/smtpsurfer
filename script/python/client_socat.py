
import base64
import sys
import os
import time
import threading
import datetime

def write_log(message):
    with open('/smtpsurfer/log.sh', 'a') as f:
        f.write('<<<<<<<<<<<<<<START LOGLINE BY PYTHON BRIDGE START>>>>>>>>>>>>>>\n')
        f.write('<<<<<<<<<<<<<<<<<<<INPUT BEFORE BASE64 ENCODE>>>>>>>>>>>>>>>>>>>\n')
        f.write(message)
        f.write('<<<<<<<<<<<<<<<<END LOGLINE BY PYTHON BRIDGE END>>>>>>>>>>>>>>>>\n')

def write_logpy(input_data):
    output_str = str(input_data)
    with open('/smtpsurfer/logpy.sh', 'a') as f:
        f.write(output_str + '\n')
    with open('/smtpsurfer/logpy.sh', 'r') as f:
        lines = f.readlines()
        if len(lines) > 20000:
            with open('/smtpsurfer/logpy.sh', 'w') as f:
                f.writelines(lines[1000:])

def stdout (message):
    currently=datetime.datetime.now().strftime('%H:%M:%S')
    write_logpy('=== ' + currently + ' ===')
    write_logpy('SENDING BASE64 TO STDOUT:')
    write_logpy(message)
    sys.stdout.write(message)
    sys.stdout.write('\n>>>EOF<<<\n')
    sys.stdout.flush()

# read from stdin and set >>>EOF<<< as end of the received data
# if the received data starts with a http method, we need to
# wait for the end of the request. the end of the request is
# determined by \r\n\r\n
# if the received data does not start with a http method, it is binary data
# binary data in this use case musst be TLS encrypted data
# it will be encoded to base64 like the http request and sent to stdout
# 
# the main loop checks every data_stdin_interval seconds if data was received
# data is buffered as bytearray
# a second thread is started to monitor the bytearray
# if the bytearray did not receive any data
# or did not receive for data_stdin_timeout seconds we consider receiving
# as finished and send the data to stdout
#
# to determine the end of data, the tls-header needs to be analyzed
# for a simpler loop i decided to use a timeout instead
data_stdin_timeout = 0.1
data_stdin_interval = 0.005
http_methods = ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'CONNECT', 'TRACE', 'PATCH']
input_data = bytearray()

input_data_lock = threading.Lock()

def manage_stdout ():
    global input_data
    currently=datetime.datetime.now().strftime('%H:%M:%S')
    while True:
        input_data_len = len(input_data)
        time.sleep(data_stdin_timeout)
        with input_data_lock:
            #write_logpy('=== CHECK START ===')
            # verify that input_data is > 0 (has actually received data)
            if len(input_data) > 0:
                #write_logpy('CHECK - data received on stdin')
                # also verify if the size of the data received by stdin did not change
                if input_data_len == len(input_data):
                    write_logpy('CHECK - no new data since last check')
                    data_str = input_data.decode('ISO-8859-1')
                    if any(data_str.startswith(method) for method in http_methods):
                        write_logpy('=== HTTP REQUEST:')
                        write_logpy(data_str)
                        if b'\r\n\r\n' in input_data:
                            input_str = input_data.decode('ISO-8859-1')
                            write_logpy('=== ' + currently + ' ===')
                            write_logpy('=== END REQUEST - sending to stdout')
                            base64_str = base64.b64encode(input_str.encode('ISO-8859-1')).decode('ISO-8859-1')
                            stdout(base64_str)
                            input_data = bytearray()
                    # if the data received by stdin is not a http request
                    # it must be binary data. its encoded to base64
                    # and send it to stdout
                    else:
                        write_logpy('=== ' + currently + ' ===')
                        write_logpy('=== END BIN - sending to stdout')
                        write_logpy(input_data.decode('ISO-8859-1'))
                        base64_bin = base64.b64encode(input_data).decode('ISO-8859-1')
                        stdout(base64_bin)
                        input_data = bytearray()
            #else:
                #write_logpy('CHECK - INPUT DATA IS EMPTY')
            #write_logpy('=== CHECK END ===')

stdout_thread = threading.Thread(target=manage_stdout)
stdout_thread.start()

while True:
    time.sleep(data_stdin_interval)
    char = os.read(sys.stdin.fileno(), 1)
    if char:
        input_data.extend(char)
        write_logpy('current input:')
        write_logpy(str(input_data))
    else:
        continue