#!/bin/bash

# Enable error tracing
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
    log "- The application may run slower"
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

# Create log file
touch qgc_install.log || { log "ERROR: Cannot create log file"; exit 1; }

# Download QGroundControl
log "Downloading QGroundControl..."
progress 10
wget https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage -O /usr/local/bin/QGroundControl || { log "ERROR: Failed to download QGroundControl"; exit 1; }
chmod +x /usr/local/bin/QGroundControl || { log "ERROR: Failed to set executable permissions"; exit 1; }

# Install required dependencies
log "Installing dependencies..."
progress 30
apt-get install -y \
    libsdl2-dev \
    libusb-1.0-0-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    network-manager \
    modemmanager \
    usb-modeswitch || { log "ERROR: Failed to install dependencies"; exit 1; }

# Create desktop entry
log "Creating desktop entry..."
progress 60
cat > /usr/share/applications/qgroundcontrol.desktop << EOF || { log "ERROR: Failed to create desktop entry"; exit 1; }
[Desktop Entry]
Type=Application
Name=QGroundControl
Comment=Ground Control Station
Exec=/usr/local/bin/QGroundControl
Terminal=false
Categories=Utility;
EOF

# Configure USB permissions
log "Setting up USB permissions..."
progress 80
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="*", ATTR{idProduct}=="*", MODE="0666"' | tee /etc/udev/rules.d/99-qgroundcontrol.rules || { log "ERROR: Failed to set USB permissions"; exit 1; }
udevadm control --reload-rules || { log "ERROR: Failed to reload udev rules"; exit 1; }

# Enable required services
log "Enabling required services..."
progress 90
systemctl enable ModemManager || { log "ERROR: Failed to enable ModemManager"; exit 1; }
systemctl start ModemManager || { log "ERROR: Failed to start ModemManager"; exit 1; }
systemctl enable NetworkManager || { log "ERROR: Failed to enable NetworkManager"; exit 1; }
systemctl start NetworkManager || { log "ERROR: Failed to start NetworkManager"; exit 1; }

# Installation complete
progress 100
echo ""
log "Installation complete! QGroundControl has been installed successfully."
log "You can start QGroundControl by running: /usr/local/bin/QGroundControl"
log "Or find it in your applications menu."
