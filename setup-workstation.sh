#!/bin/bash
set -e

# Update system and install prerequisites
echo "Updating system and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl software-properties-common flatpak gnome-software-plugin-flatpak dconf-cli

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

# Install Human theme for MATE (for old Ubuntu look), classic icon sets, cursors, and fonts
echo "Installing Human theme, classic icons, cursor themes, and fonts for MATE..."
sudo apt install -y mate-themes human-icon-theme gnome-icon-theme dmz-cursor-theme fonts-ubuntu fonts-liberation

# Ensure mate-settings-daemon is running before applying changes
if ! pgrep -x "mate-settings-daemon" > /dev/null; then
    echo "Starting mate-settings-daemon..."
    nohup mate-settings-daemon &
    sleep 3
fi

# Set Human theme, icons, cursors, and fonts as default
gsettings set org.mate.interface gtk-theme "Human"
gsettings set org.mate.Marco.general theme "Human"
gsettings set org.mate.interface icon-theme "human"
gsettings set org.mate.background picture-filename "/usr/share/backgrounds/warty-final-ubuntu.png"
gsettings set org.mate.interface cursor-theme "DMZ-White"
gsettings set org.mate.interface font-name "Ubuntu 11"
gsettings set org.mate.desktop.interface document-font-name "Liberation Sans 10"
gsettings set org.mate.desktop.interface monospace-font-name "Ubuntu Mono 12"

# Configure a classic two-panel layout with applets
dconf load /org/mate/panel/ < /usr/share/mate-panel/layouts/classic.layout

# Edit GRUB to boot Xanmod kernel entry by default with 7s timeout
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=7/' /etc/default/grub
sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub
sudo update-grub

echo "Setup completed. Rebooting in 5 seconds..."
sleep 5
sudo reboot
