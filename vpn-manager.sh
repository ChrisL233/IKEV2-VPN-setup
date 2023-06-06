#!/bin/bash

# Function to add a new configuration
add_configuration() {
    echo "Creating a new user configuration..."
    read -p "Enter VPN username: " new_username
    read -s -p "Enter VPN password: " new_password

    sudo bash -c "echo -n \"$new_username : EAP : \"$new_password >> /etc/ipsec.secrets"

    sudo ipsec pki --gen --type rsa --size 4096 --outform pem > ${new_username}-key.pem
    sudo ipsec pki --pub --in ${new_username}-key.pem --type rsa | sudo tee ${new_username}-pub.pem

    sudo bash -c "cat > ${new_username}.conf << EOL
conn ${new_username}
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!
    dpdaction=clear
    dpddelay=300s
    rekey=no
    leftid=${new_username}
    leftcert=${new_username}-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightsendcert=never
    eap_identity=${new_username}
EOL"

    sudo ipsec reload

    echo "New user configuration created: ${new_username}"
    echo ""
}

# Function to remove an existing configuration
remove_configuration() {
    echo "Removing an existing user configuration..."
    read -p "Enter VPN username to remove: " username_to_remove

    sudo sed -i "/^${username_to_remove} /d" /etc/ipsec.secrets

    sudo rm -f ${username_to_remove}-key.pem
    sudo rm -f ${username_to_remove}-pub.pem
    sudo rm -f ${username_to_remove}.conf

    sudo ipsec reload

    echo "User configuration removed: ${username_to_remove}"
    echo ""
}

# Function to list all existing configurations
list_configurations() {
    echo "Existing Configurations:"
    echo "-----------------------"

    if ls *.conf &>/dev/null; then
        ls *.conf
    else
        echo "No configurations found."
    fi

    echo ""
}

# Function to reboot the server
reboot_server() {
    echo "Rebooting the server..."
    sudo reboot
}

# Function to reinstall the VPN server
reinstall_server() {
    echo "Reinstalling the VPN server..."
    read -p "Are you sure you want to reinstall the VPN server? This will remove all existing configurations. [Y/N]: " choice
    case $choice in
        [Yy])
            sudo rm -rf /etc/ipsec.d/*
            sudo systemctl stop strongswan
            sudo apt remove -y strongswan
            sudo apt install -y strongswan
            sudo systemctl start strongswan
            echo "VPN server reinstalled."
            ;;
        [Nn])
            echo "Reinstallation canceled."
            ;;
        *)
            echo "Invalid choice. Reinstallation canceled."
            ;;
    esac
    echo ""
}

# Main menu
while true; do
    echo "IKEv2 VPN Server Management"
    echo "---------------------------"
    echo "Select an option:"
    echo "1. Add new user configuration"
    echo "2. Remove existing user configuration"
    echo "3. List existing user configurations"
    echo "4. Reboot the server"
    echo "5. Reinstall the VPN server"
    echo "6. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            add_configuration
            ;;
        2)
            remove_configuration
            ;;
        3)
            list_configurations
            ;;
        4)
            reboot_server
            ;;
        5)
            reinstall_server
            ;;
        6)
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            echo ""
            ;;
    esac
done
