#!/bin/bash
# This script will set up an iKev2 server on an Ubuntu 20.04 LTS system.

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Get the server's public IP address
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

# Ask the user for the server name and the first client's credentials
read -p "Enter your server name: " SERVER_NAME
read -p "Enter your first client's name: " CLIENT_NAME
read -s -p "Enter your first client's password: " CLIENT_PASSWORD
echo

# Install the necessary packages
apt update && apt upgrade -y
apt install -y strongswan strongswan-pki libcharon-extra-plugins strongswan-pkcs11 openssl

# Create the CA certificate
mkdir -p ~/pki/{cacerts,certs,private}
chmod 700 ~/pki
cd ~/pki

ipsec pki --gen --type rsa --size 4096 --outform pem > private/ca.key.pem
ipsec pki --self --ca --lifetime 3650 --in private/ca.key.pem --type rsa --dn "CN=VPN CA" --outform pem > cacerts/ca.cert.pem

# Create the Server certificate
ipsec pki --gen --type rsa --size 4096 --outform pem > private/vpn-server.key.pem
ipsec pki --pub --in private/vpn-server.key.pem --type rsa | ipsec pki --issue --lifetime 1825 --cacert cacerts/ca.cert.pem --cakey private/ca.key.pem --dn "CN=$PUBLIC_IP" --san "$SERVER_NAME" --flag serverAuth --flag ikeIntermediate --outform pem > certs/vpn-server.cert.pem

# Create the Client certificate
ipsec pki --gen --type rsa --size 2048 --outform pem > private/vpn-client.key.pem
ipsec pki --pub --in private/vpn-client.key.pem --type rsa | ipsec pki --issue --lifetime 1825 --cacert cacerts/ca.cert.pem --cakey private/ca.key.pem --dn "CN=$CLIENT_NAME" --outform pem > certs/vpn-client.cert.pem

# Move the keys to /etc/ipsec.d/
cp -r ~/pki/* /etc/ipsec.d/

# Configure ipsec
echo "
config setup
    charondebug=\"ike 1, knl 1, cfg 0\"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    ike=aes256-sha1-modp1024,3des-sha1-modp1024!
    esp=aes256-sha1,3des-sha1!
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@$SERVER_NAME
    leftcert=/etc/ipsec.d/certs/vpn-server.cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
" > /etc/ipsec.conf

# Configure strongswan
echo "
charon {
    load_modular = yes
    duplicheck.enable = no
    compress = yes
    plugins {
        include strongswan.d/charon/*.conf
    }
}
include strongswan.d/*.conf
" > /etc/strongswan.conf

# Set the VPN credentials
echo "$CLIENT_NAME : EAP \"$CLIENT_PASSWORD\"" > /etc/ipsec.secrets

# Restart IPsec service
systemctl restart strongswan-starter

# Enable IPsec service at startup
systemctl enable strongswan-starter

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
sysctl -p

# Update the firewall rules
ufw allow OpenSSH
ufw enable
ufw allow 500,4500/udp

# Export client certificate and private key to p12
openssl pkcs12 -export -out /etc/ipsec.d/p12/$CLIENT_NAME.p12 -inkey /etc/ipsec.d/private/vpn-client.key.pem -in /etc/ipsec.d/certs/vpn-client.cert.pem -certfile /etc/ipsec.d/cacerts/ca.cert.pem -passout pass:strongSwan

# Generate mobileconfig file for iOS
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>IKEv2</key>
            <dict>
                <key>AuthName</key>
                <string>$CLIENT_NAME</string>
                <key>AuthPassword</key>
                <string>$CLIENT_PASSWORD</string>
                <key>AuthenticationMethod</key>
                <string>None</string>
                <key>ChildSecurityAssociationParameters</key>
                <dict>
                    <key>DiffieHellmanGroup</key>
                    <integer>2</integer>
                    <key>EncryptionAlgorithm</key>
                    <string>AES-256</string>
                    <key>IntegrityAlgorithm</key>
                    <string>SHA2-256</string>
                </dict>
                <key>DeadPeerDetectionRate</key>
                <string>Medium</string>
                <key>DisableMOBIKE</key>
                <integer>0</integer>
                <key>DisableRedirect</key>
                <integer>0</integer>
                <key>EnableCertificateRevocationCheck</key>
                <integer>0</integer>
                <key>EnablePFS</key>
                <integer>0</integer>
                <key>IKESecurityAssociationParameters</key>
                <dict>
                    <key>DiffieHellmanGroup</key>
                    <integer>2</integer>
                    <key>EncryptionAlgorithm</key>
                    <string>AES-256</string>
                    <key>IntegrityAlgorithm</key>
                    <string>SHA2-256</string>
                    <key>LifeTimeInMinutes</key>
                    <integer>1440</integer>
                </dict>
                <key>LocalIdentifier</key>
                <string>$CLIENT_NAME</string>
                <key>PayloadCertificateUUID</key>
                <string>$SERVER_NAME</string>
                <key>RemoteAddress</key>
                <string>$PUBLIC_IP</string>
                <key>RemoteIdentifier</key>
                <string>$SERVER_NAME</string>
                <key>UseConfigurationAttributeInternalIPSubnet</key>
                <integer>0</integer>
                <key>UserDefinedName</key>
                <string>$SERVER_NAME</string>
            </dict>
            <key>IPv4</key>
            <dict>
                <key>OverridePrimary</key>
                <integer>1</integer>
            </dict>
            <key>PayloadDescription</key>
            <string>Adds VPN settings</string>
            <key>PayloadDisplayName</key>
            <string>VPN</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.vpn.managed.$CLIENT_NAME</string>
            <key>PayloadOrganization</key>
            <string>$SERVER_NAME</string>
            <key>PayloadType</key>
            <string>com.apple.vpn.managed</string>
            <key>PayloadUUID</key>
            <string>$SERVER_NAME</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>Proxies</key>
            <dict/>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>$SERVER_NAME</string>
    <key>PayloadIdentifier</key>
    <string>com.$SERVER_NAME.vpn.managed</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>$SERVER_NAME</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>" > /etc/ipsec.d/mobileconfig/$CLIENT_NAME.mobileconfig

# Print the location of the files
echo "The .p12 file for Android is available at /etc/ipsec.d/p12/$CLIENT_NAME.p12"
echo "The .mobileconfig file for iOS is available at /etc/ipsec.d/mobileconfig/$CLIENT_NAME.mobileconfig"

