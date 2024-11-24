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

# Display prerequisites and information
cat << 'EOF'
QGroundControl ARM64 Installation Prerequisites:

- ARM64-based system (Raspberry Pi 4, Pi 3, Jetson Nano, etc.)
- Internet connection for package download
- Minimum 2GB RAM recommended
- USB/Serial ports for device connections
- Sufficient storage space (at least 2GB free)

This installation will:
1. Install Flatpak package manager
2. Add required Flatpak repositories
3. Install KDE Platform dependencies
4. Install QGroundControl for ARM64
5. Configure device permissions

Note: This method is specifically designed for ARM64 systems where the standard
AppImage cannot be executed due to architecture incompatibility.

EOF

# Prompt for continuation
read -p "Would you like to proceed with the installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Create log file
touch qgc_install.log || { log "ERROR: Cannot create log file"; exit 1; }

# Add Flatpak repository
log "Adding Flatpak repository..."
progress 20
add-apt-repository -y ppa:alexlarsson/flatpak || { log "ERROR: Failed to add Flatpak repository"; exit 1; }
apt update || { log "ERROR: Failed to update package list"; exit 1; }

# Install Flatpak
log "Installing Flatpak..."
progress 30
apt install -y flatpak || { log "ERROR: Failed to install Flatpak"; exit 1; }

# Add required Flatpak repositories
log "Adding Flathub and thopiekar repositories..."
progress 40
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || { log "ERROR: Failed to add Flathub repository"; exit 1; }
flatpak remote-add --if-not-exists thopiekar.eu https://dl.thopiekar.eu/flatpak/_.flatpakrepo || { log "ERROR: Failed to add thopiekar repository"; exit 1; }

# Install KDE Platform
log "Installing KDE Platform..."
progress 60
flatpak install -y flathub org.kde.Platform/aarch64/5.15-21.08 || { log "ERROR: Failed to install KDE Platform"; exit 1; }

# Install QGroundControl
log "Installing QGroundControl..."
progress 80
flatpak install -y thopiekar.eu org.mavlink.qgroundcontrol || { log "ERROR: Failed to install QGroundControl"; exit 1; }

# Configure USB permissions
log "Setting up USB permissions..."
progress 90
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="*", ATTR{idProduct}=="*", MODE="0666"' | tee /etc/udev/rules.d/99-qgroundcontrol.rules || { log "ERROR: Failed to set USB permissions"; exit 1; }
udevadm control --reload-rules || { log "ERROR: Failed to reload udev rules"; exit 1; }

# Installation complete
progress 100
echo ""
log "Installation complete! QGroundControl has been installed successfully."
log "To start QGroundControl, run: flatpak run --device=all org.mavlink.qgroundcontrol"
log "The --device=all option is required for accessing devices like serial ports."
log "You can also find QGroundControl in your applications menu."

cat << 'EOF'

Additional Notes:
- This installation has been tested on various ARM64 platforms including Raspberry Pi and Jetson Nano
- If you experience any device access issues, ensure you're using the --device=all flag
- For mission planning and execution, ensure all required permissions are granted when prompted

EOF
