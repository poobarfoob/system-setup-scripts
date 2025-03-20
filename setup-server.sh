#!/bin/bash
set -e

echo "Step 1: Editing GRUB configuration..."
sudo sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& amd_iommu=on iommu=pt hugepagesz=2M hugepages=4096 isolcpus=2-5,8-11/' /etc/default/grub
sudo update-grub

echo "Step 2: Installing required packages..."
sudo apt update
sudo apt install -y lsb-release libvirt-daemon-system libvirt-clients virt-manager qemu-kvm \
bridge-utils flatpak neofetch figlet

echo "Step 3: Creating system update script..."
sudo tee /usr/local/bin/update_system.sh > /dev/null <<'EOF'
#!/bin/bash
set -e

echo "Stopping libvirt services..."
sudo systemctl stop libvirtd.service || true
sudo systemctl stop virtlogd.service || true
sudo systemctl stop virtlockd.service || true

echo "Updating system packages..."
sudo apt update
sudo apt full-upgrade -y

echo "Recording last update timestamp..."
date +"%Y-%m-%d %H:%M:%S" | sudo tee /var/log/last_system_update > /dev/null

if [ -f /var/run/reboot-required ]; then
    echo "A reboot is required. Rebooting now..."
    sudo reboot
fi

echo "Cleaning up..."
sudo apt autoremove -y
sudo apt clean

echo "Restarting libvirt services..."
sudo systemctl start virtlockd.service || true
sudo systemctl start virtlogd.service || true
sudo systemctl start libvirtd.service || true

echo "Update completed."
EOF

sudo chmod +x /usr/local/bin/update_system.sh

echo "Step 4: Creating systemd service and timer..."
sudo tee /etc/systemd/system/system-update.service > /dev/null <<EOF
[Unit]
Description=Weekly System Update
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update_system.sh
EOF

sudo tee /etc/systemd/system/system-update.timer > /dev/null <<EOF
[Unit]
Description=Weekly System Update Timer

[Timer]
OnCalendar=Sun 05:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now system-update.timer

echo "Step 5: Creating MOTD countdown..."
sudo mkdir -p /etc/update-motd.d
sudo tee /etc/update-motd.d/20-update-countdown > /dev/null <<'EOF'
#!/bin/bash
HOSTNAME=$(hostname)
DISTRO=$(lsb_release -ds)
UPTIME=$(uptime -p)
KERNEL=$(uname -r)

if [ -f /var/log/last_system_update ]; then
    LAST_UPDATE=$(cat /var/log/last_system_update)
    NEXT_UPDATE=$(date -d "$LAST_UPDATE + 7 days" +"%Y-%m-%d")
    DAYS_LEFT=$(( ( $(date -d "$NEXT_UPDATE" +%s) - $(date +%s) )/(60*60*24) ))
else
    LAST_UPDATE="Never run"
    NEXT_UPDATE="Not scheduled"
    DAYS_LEFT="N/A"
fi

echo "#########################################################"
echo "   Welcome to $HOSTNAME - $DISTRO"
echo "#########################################################"
echo "Uptime:          $UPTIME"
echo "Kernel:          $KERNEL"
echo ""
echo "Last update run: $LAST_UPDATE"
echo "Next update due: $NEXT_UPDATE (in $DAYS_LEFT days)"
echo "#########################################################"
EOF

sudo chmod +x /etc/update-motd.d/20-update-countdown

# Ensure PAM uses dynamic MOTD
if ! grep -q "/run/motd.dynamic" /etc/pam.d/sshd; then
    echo "session optional pam_motd.so motd=/run/motd.dynamic" | sudo tee -a /etc/pam.d/sshd
    echo "session optional pam_motd.so noupdate" | sudo tee -a /etc/pam.d/sshd
fi
if ! grep -q "/run/motd.dynamic" /etc/pam.d/login; then
    echo "session optional pam_motd.so motd=/run/motd.dynamic" | sudo tee -a /etc/pam.d/login
    echo "session optional pam_motd.so noupdate" | sudo tee -a /etc/pam.d/login
fi

echo "Step 6: Generate initial MOTD..."
sudo run-parts /etc/update-motd.d > /run/motd.dynamic

echo "All done! System configuration and automatic updates setup are complete."
echo "A reboot is recommended to apply GRUB changes."
