#!/bin/bash

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Download the scripts
wget -O setup_ikev2_server.sh https://github.com/ChrisL233/IKEV2-VPN-setup/raw/main/setup_ikev2_server.sh
wget -O vpn_manager.sh https://github.com/ChrisL233/IKEV2-VPN-setup/raw/main/vpn-manager.sh
wget -O QR_code.sh https://github.com/ChrisL233/IKEV2-VPN-setup/raw/main/QR-code.sh

# Make the scripts executable
chmod +x setup_ikev2_server.sh vpn_manager.sh QR_code.sh

# Run the server setup script
./setup_ikev2_server.sh

# Print instructions
echo "VPN server setup is complete."
echo "Use './vpn_manager.sh' to manage the server."
echo "Use './QR_code.sh' to generate a QR code for a file."

# Provide an option for a guideline of the entire program
while true
do
    echo "1. View guideline"
    echo "2. Exit"
    read -p "Choose an option: " OPTION

    case $OPTION in
        1)
            echo "Guideline:"
            echo "1. Run './setup_ikev2_server.sh' to set up the VPN server. This script will ask for a server name and the initial client name and password."
            echo "2. Run './vpn_manager.sh' to manage the server. This script allows you to add or remove users, list existing users, reboot the server, or reinstall the VPN server."
            echo "3. Run './QR_code.sh' to generate a QR code for a file. This script will ask for the file path, make a copy of the file, start a web server, and generate a QR code."
            ;;
        2)
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac
done
