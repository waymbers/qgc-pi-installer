#!/bin/bash

# Enable error tracing and exit on error
set -e

# Function for progress bar
progress() {
    local width=50
    local percent=$1
    local filled=$(printf "%.0f" $(echo "$width * $percent / 100" | bc -l))
    local empty=$((width - filled))
    printf "\rProgress: [%${filled}s%${empty}s] %d%%" | tr ' ' '=' | tr ' ' ' ' "$percent"
}

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a qgc_install.log
}

# Create log file
touch qgc_install.log

# Trap errors
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then log "ERROR: Command \"${last_command}\" failed with exit code $?"; fi' EXIT

log "Starting QGroundControl installation..."

# System update and upgrade
log "Updating system packages..."
progress 10
sudo apt-get update &>> qgc_install.log
sudo apt-get upgrade -y &>> qgc_install.log

# Install dependencies
log "Installing dependencies..."
progress 20
sudo apt-get install -y git build-essential cmake libsdl2-dev libsdl1.2-dev \
    libudev-dev libasound2-dev libflite1 speech-dispatcher libspeechd-dev \
    flite1-dev qt5-default qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    qtdeclarative5-dev qtpositioning5-dev qtlocation5-dev libqt5svg5-dev \
    libqt5webkit5-dev libqt5serialport5-dev libqt5opengl5-dev libqt5charts5-dev \
    libgps-dev libusb-1.0-0-dev &>> qgc_install.log

# Install 4G/LTE support
log "Installing 4G/LTE support..."
progress 30
sudo apt-get install -y usb-modeswitch wvdial network-manager modemmanager &>> qgc_install.log

# Optimize system settings for QGC
log "Optimizing system settings..."
progress 40
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf &>> qgc_install.log
echo "net.core.rmem_max=2097152" | sudo tee -a /etc/sysctl.conf &>> qgc_install.log
echo "net.core.wmem_max=2097152" | sudo tee -a /etc/sysctl.conf &>> qgc_install.log

# Clone and build QGC
log "Cloning QGroundControl repository..."
progress 50
mkdir -p ~/src &>> qgc_install.log
cd ~/src
git clone --recursive https://github.com/mavlink/qgroundcontrol.git &>> qgc_install.log

log "Building QGroundControl..."
progress 60
cd qgroundcontrol
mkdir build && cd build
cmake .. &>> qgc_install.log

# Determine optimal number of cores for compilation
CORES=$(nproc)
log "Compiling with $CORES cores..."
progress 70
make -j$CORES &>> qgc_install.log

# Create desktop and autostart entries
log "Creating desktop entries..."
progress 80
echo "[Desktop Entry]
Type=Application
Name=QGroundControl
Comment=Ground Control Station
Path=/home/pi/src/qgroundcontrol/build
Exec=/home/pi/src/qgroundcontrol/build/QGroundControl
Terminal=false
Categories=Utility;" | sudo tee /usr/share/applications/qgroundcontrol.desktop &>> qgc_install.log

mkdir -p ~/.config/autostart
cp /usr/share/applications/qgroundcontrol.desktop ~/.config/autostart/

# Enable and start services
log "Enabling required services..."
progress 90
sudo systemctl enable ModemManager &>> qgc_install.log
sudo systemctl start ModemManager &>> qgc_install.log
sudo systemctl enable NetworkManager &>> qgc_install.log
sudo systemctl start NetworkManager &>> qgc_install.log

# Configure USB permissions
log "Setting up USB permissions..."
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="*", ATTR{idProduct}=="*", MODE="0666"' | sudo tee /etc/udev/rules.d/99-qgroundcontrol.rules &>> qgc_install.log
sudo udevadm control --reload-rules &>> qgc_install.log

# Final optimization
log "Performing final optimizations..."
progress 95
sudo systemctl disable bluetooth # Disable unnecessary services
sudo systemctl disable cups
sync # Ensure all disk writes are complete

# Installation complete
progress 100
echo ""
log "Installation complete! QGroundControl has been installed and configured."
log "You can find the full installation log in: $(pwd)/qgc_install.log"
log "QGroundControl will start automatically on next boot."
