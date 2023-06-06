#!/bin/bash

# Update the system
sudo apt update
sudo apt upgrade -y

# Install strongSwan
sudo apt install -y strongswan

# Configure IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Enable IP forwarding on boot
sudo sed -i '/^#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sudo sed -i '/^#net.ipv6.conf.all.forwarding=1/c\net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf

# Generate a strongSwan configuration
sudo bash -c 'cat > /etc/ipsec.conf << EOL
config setup
  uniqueids=never
  charondebug="cfg 2, dmn 2, ike 2, net 2"

conn ikev2-vpn
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
  left=%any
  leftid=%any
  leftcert=server-cert.pem
  leftsendcert=always
  leftsubnet=0.0.0.0/0
  right=%any
  rightid=%any
  rightauth=eap-mschapv2
  rightsourceip=10.10.10.0/24
  rightsendcert=never
  eap_identity=%identity
EOL'

# Generate a strongSwan secrets file
read -p "Enter VPN username: " vpn_username
read -s -p "Enter VPN password: " vpn_password

sudo bash -c "echo -n \"$vpn_username : EAP : \"$vpn_password > /etc/ipsec.secrets"

# Generate a self-signed server certificate
sudo ipsec pki --gen --type rsa --size 4096 --outform pem > server-key.pem
sudo ipsec pki --self --ca --lifetime 3650 --in server-key.pem --type rsa --dn "CN=VPN Server" --outform pem > server-cert.pem

# Update permissions for the private key
sudo chmod 600 /etc/ipsec.secrets /etc/ipsec.d/private/server-key.pem

# Restart strongSwan service
sudo systemctl restart strongswan

echo "IKEv2 VPN server is now set up."
