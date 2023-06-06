#!/bin/bash

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Ask the user for the file path
read -p "Enter the file path: " FILE_PATH

# Create a directory for the web server if it does not exist
mkdir -p /var/www/html

# Copy the file to the web server's directory
cp $FILE_PATH /var/www/html

# Get the file name
FILE_NAME=$(basename $FILE_PATH)

# Install necessary Python package for generating QR codes
pip install qrcode[pil]

# Generate the QR code
python3 -c "import qrcode; img = qrcode.make('http://YOUR_SERVER_IP_ADDRESS/$FILE_NAME'); img.save('/var/www/html/$FILE_NAME.png')"

# Start the web server
python3 -m http.server --directory /var/www/html 8000
