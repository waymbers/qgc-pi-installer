## QGroundControl Raspberry Pi Installer

Automated installation script for QGroundControl on Raspberry Pi 4 with 4G/LTE support.

## Features

- One-command installation of QGroundControl
- Automatic dependency management
- 4G/LTE modem support
- System optimization for best performance
- Progress tracking and logging
- Error handling with detailed tracebacks
- Headless installation support
- Autostart configuration

## Requirements

- Raspberry Pi 4 Model B
- Raspbian OS (latest version)
- Internet connection
- 4G/LTE USB modem (optional)

## Quick Install

```bash
wget -O install_qgc.sh https://raw.githubusercontent.com/waymbers/qgc-pi-installer/main/install_qgc.sh
chmod +x install_qgc.sh
./install_qgc.sh
