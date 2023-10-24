import sys
import os
import time

input_data = bytearray()

while True:
    time.sleep(0.1)
    char = os.read(sys.stdin.fileno(), 1)
    if not char:
        break
    if char:
        input_data.extend(char)

# Print the input_data bytearray
print(input_data)
