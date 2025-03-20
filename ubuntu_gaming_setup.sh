#!/bin/bash
set -e

# Disable unattended upgrades
echo "Disabling unattended-upgrades..."
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades
sudo apt remove -y unattended-upgrades

# Update system and install prerequisites
echo "Updating system and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl software-properties-common flatpak gnome-software-plugin-flatpak

# Add Flatpak repository
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Xanmod Kernel (linux-xanmod-x64v3)
curl -s https://dl.xanmod.org/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/xanmod.gpg
echo "deb [arch=$(dpkg --print-architecture)] https://deb.xanmod.org releases main" | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
sudo apt update && sudo apt install -y linux-xanmod-x64v3

# Install Steam, Discord, MATE DE, Libvirt, Virt-Manager, Python 3.12+, git, Wine stable
sudo apt install -y steam
sudo flatpak install -y flathub com.discordapp.Discord
sudo apt install -y ubuntu-mate-desktop
sudo apt install -y libvirt-daemon-system libvirt-clients virt-manager qemu-kvm bridge-utils
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update && sudo apt install -y python3.12 python3.12-venv python3.12-dev
git --version || sudo apt install -y git
sudo apt install -y wine64 wine32

# Install 010 Editor (Official .deb download)
echo "Installing 010 Editor..."
curl -L -o /tmp/010editor.deb "https://www.sweetscape.com/download/010EditorLinux64.deb"
sudo dpkg -i /tmp/010editor.deb || sudo apt --fix-broken install -y
rm /tmp/010editor.deb

# Edit GRUB to boot Xanmod kernel entry by default with 7s timeout
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=7/' /etc/default/grub
sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub
sudo update-grub

# Create custom updater script
cat << 'EOF' | sudo tee /usr/local/bin/system_auto_update.sh
#!/bin/bash
set -e

# Stop libvirtd gracefully if running
if systemctl is-active --quiet libvirtd; then
  systemctl stop libvirtd
fi

apt update && apt full-upgrade -y
if [ -f /var/run/reboot-required ]; then
  reboot
fi
EOF
sudo chmod +x /usr/local/bin/system_auto_update.sh

# Create systemd service for updater
sudo tee /etc/systemd/system/system-auto-update.service > /dev/null << 'EOF'
[Unit]
Description=System Auto Update
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/system_auto_update.sh
EOF

# Create systemd timer to run at every boot
sudo tee /etc/systemd/system/system-auto-update.timer > /dev/null << 'EOF'
[Unit]
Description=Run system auto-update at boot

[Timer]
OnBootSec=2min
Unit=system-auto-update.service

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now system-auto-update.timer

echo "Setup completed. Rebooting in 5 seconds..."
sleep 5
sudo reboot