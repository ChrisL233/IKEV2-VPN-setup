#!/bin/bash
# This script will manage the iKev2 server on an Ubuntu 20.04 LTS system.

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Function to add a user
add_user() {
    read -p "Enter the new client's name: " CLIENT_NAME
    read -s -p "Enter the new client's password: " CLIENT_PASSWORD
    echo

    # Add the user to ipsec.secrets
    echo "$CLIENT_NAME : EAP \"$CLIENT_PASSWORD\"" >> /etc/ipsec.secrets

    # Restart the IPsec service
    systemctl restart strongswan-starter

    echo "User $CLIENT_NAME added."
}

# Function to remove a user
remove_user() {
    read -p "Enter the client's name to remove: " CLIENT_NAME

    # Remove the user from ipsec.secrets
    sed -i "/$CLIENT_NAME/d" /etc/ipsec.secrets

    # Restart the IPsec service
    systemctl restart strongswan-starter

    echo "User $CLIENT_NAME removed."
}

# Function to list users
list_users() {
    echo "Existing users:"
    grep : /etc/ipsec.secrets | cut -d':' -f1
}

# Function to reboot the server
reboot_server() {
    echo "Rebooting the server..."
    reboot
}

# Function to reinstall the VPN server
reinstall_vpn() {
    echo "Reinstalling the VPN server..."

    # Download the setup script from the GitHub repository
    wget -O setup_ikev2_server.sh https://github.com/ChrisL233/IKEV2-VPN-setup/raw/main/setup_ikev2_server.sh

    # Make the setup script executable
    chmod +x setup_ikev2_server.sh

    # Run the setup script
    ./setup_ikev2_server.sh
}

while true
do
    echo "1. Add a user"
    echo "2. Remove a user"
    echo "3. List users"
    echo "4. Reboot the server"
    echo "5. Reinstall the VPN server"
    echo "6. Exit"
    read -p "Choose an option: " OPTION

    case $OPTION in
        1)
            add_user
            ;;
        2)
            remove_user
            ;;
        3)
            list_users
            ;;
        4)
            reboot_server
            ;;
        5)
            reinstall_vpn
            ;;
        6)
            exit 0
            ;;
        *)
            echo "Invalid option. Try again."
            ;;
    esac
done

