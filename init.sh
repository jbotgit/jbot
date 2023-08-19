#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Update and upgrade the system
apt update && apt upgrade -y

# Install necessary packages
apt install -y hostapd dnsmasq

# Stop the services
systemctl stop hostapd
systemctl stop dnsmasq

# Configure static IP for the Wi-Fi interface
echo -e "\ninterface wlan0\nstatic ip_address=192.168.4.1/24\nnohook wpa_supplicant" >> /etc/dhcpcd.conf

# Configure hostapd
cat <<EOL > /etc/hostapd/hostapd.conf
interface=wlan0
ssid=YourNetworkName
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=YourPassword
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOL

# Update DAEMON_CONF in hostapd
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Configure dnsmasq
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
echo -e "interface=wlan0\ndhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h" > /etc/dnsmasq.conf

# Enable IP forwarding
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf

# Set up NAT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat"
sed -i 's|^exit 0|iptables-restore < /etc/iptables.ipv4.nat\n\nexit 0|' /etc/rc.local

# Start and enable services
systemctl start hostapd
systemctl start dnsmasq
systemctl enable hostapd
systemctl enable dnsmasq

echo "Setup complete. Please reboot for changes to take effect."
