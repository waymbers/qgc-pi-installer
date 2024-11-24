#!/bin/bash

# Enable error tracing and exit on error
set -e

# Function for progress bar
progress() {
    local width=50
    local percent=$1
    local filled=$(printf "%.0f" $(echo "$width * $percent / 100" | bc -l))
    local empty=$((width - filled))
    printf "\rProgress: ["
    printf "%${filled}s" "" | tr ' ' '='
    printf "%${empty}s" "" | tr ' ' ' '
    printf "] %d%%" "$percent"
}

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a qgc_install.log
}

# Function to check command status
check_status() {
    if [ $? -ne 0 ]; then
        log "ERROR: $1 failed"
        exit 1
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check RAM and provide warnings if below 2GB
mem_total=$(free -m | awk '/^Mem:/{print $2}')
if [ "$mem_total" -lt 2048 ]; then
    log "WARNING: Your system has less than 2GB RAM (${mem_total}MB detected)"
    log "Important notes for running with limited RAM:"
    log "- The compilation process will take longer"
    log "- Close other applications while using QGroundControl"
    log "- The interface may be less responsive"
    log "- Consider increasing your swap space"
    log ""
    printf "Would you like to proceed with the installation? (y/n): "
    read answer
    case "$answer" in
        [Yy]*)
            log "Proceeding with installation..."
            ;;
        *)
            log "Installation cancelled by user"
            exit 1
            ;;
    esac
fi

# Check for minimum disk space
disk_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$disk_space" -lt 10 ]; then
    log "ERROR: Insufficient disk space. Minimum 10GB free space required"
    exit 1
fi

# Create log file
touch qgc_install.log || { log "ERROR: Cannot create log file"; exit 1; }

# Download QGroundControl
log "Downloading QGroundControl..."
progress 5
wget https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage -O /usr/local/bin/QGroundControl || { log "ERROR: Failed to download QGroundControl"; exit 1; }
chmod +x /usr/local/bin/QGroundControl || { log "ERROR: Failed to set executable permissions"; exit 1; }

# System update and upgrade
log "Updating system packages..."
progress 10
apt-get update || { log "ERROR: apt-get update failed"; exit 1; }
apt-get upgrade -y || { log "ERROR: apt-get upgrade failed"; exit 1; }

# Install dependencies
log "Installing dependencies..."
progress 20
apt-get install -y git build-essential cmake libsdl2-dev libsdl1.2-dev \
    libudev-dev libasound2-dev libflite1 speech-dispatcher libspeechd-dev \
    flite1-dev qt5-default qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    qtdeclarative5-dev qtpositioning5-dev qtlocation5-dev libqt5svg5-dev \
    libqt5webkit5-dev libqt5serialport5-dev libqt5opengl5-dev libqt5charts5-dev \
    libgps-dev libusb-1.0-0-dev || { log "ERROR: Failed to install dependencies"; exit 1; }

# Install 4G/LTE support
log "Installing 4G/LTE support..."
progress 30
apt-get install -y usb-modeswitch wvdial network-manager modemmanager || { log "ERROR: Failed to install 4G support"; exit 1; }

# Optimize system settings
log "Optimizing system settings..."
progress 40
echo "vm.swappiness=10" | tee -a /etc/sysctl.conf || { log "ERROR: Failed to set swappiness"; exit 1; }
echo "net.core.rmem_max=2097152" | tee -a /etc/sysctl.conf || { log "ERROR: Failed to set rmem_max"; exit 1; }
echo "net.core.wmem_max=2097152" | tee -a /etc/sysctl.conf || { log "ERROR: Failed to set wmem_max"; exit 1; }

# Create desktop entry
log "Creating desktop entry..."
progress 80
cat > /usr/share/applications/qgroundcontrol.desktop << EOF || { log "ERROR: Failed to create desktop entry"; exit 1; }
[Desktop Entry]
Type=Application
Name=QGroundControl
Comment=Ground Control Station
Exec=/usr/local/bin/QGroundControl
Terminal=false
Categories=Utility;
EOF

mkdir -p ~/.config/autostart || { log "ERROR: Failed to create autostart directory"; exit 1; }
cp /usr/share/applications/qgroundcontrol.desktop ~/.config/autostart/ || { log "ERROR: Failed to copy desktop entry"; exit 1; }

# Enable and start services
log "Enabling required services..."
progress 90
systemctl enable ModemManager || { log "ERROR: Failed to enable ModemManager"; exit 1; }
systemctl start ModemManager || { log "ERROR: Failed to start ModemManager"; exit 1; }
systemctl enable NetworkManager || { log "ERROR: Failed to enable NetworkManager"; exit 1; }
systemctl start NetworkManager || { log "ERROR: Failed to start NetworkManager"; exit 1; }

# Configure USB permissions
log "Setting up USB permissions..."
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="*", ATTR{idProduct}=="*", MODE="0666"' | tee /etc/udev/rules.d/99-qgroundcontrol.rules || { log "ERROR: Failed to set USB permissions"; exit 1; }
udevadm control --reload-rules || { log "ERROR: Failed to reload udev rules"; exit 1; }

# Final optimization
log "Performing final optimizations..."
progress 95
systemctl disable bluetooth || log "WARNING: Failed to disable bluetooth"
systemctl disable cups || log "WARNING: Failed to disable cups"
sync

# Installation complete
progress 100
echo ""
log "Installation complete! QGroundControl has been installed and configured."
log "You can find the full installation log in: $(pwd)/qgc_install.log"
log "QGroundControl will start automatically on next boot."
