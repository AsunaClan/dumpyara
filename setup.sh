#!/bin/bash

# Determine which command to use for privilege escalation
if hash sudo 2>/dev/null; then
    sudo_cmd="sudo"
elif hash doas 2>/dev/null; then
    sudo_cmd="doas"
else
    echo "Neither sudo nor doas found. Please install one of them."
    exit 1
fi

# Define package lists for different operating systems
declare -A package_lists=(
    ["linux-gnu"]="unace unrar zip unzip p7zip-full p7zip-rar sharutils rar uudeview mpack arj cabextract device-tree-compiler liblzma-dev python3-pip brotli liblz4-tool axel gawk aria2 detox cpio rename liblz4-dev curl"
    ["darwin"]="protobuf xz brotli lz4 aria2 detox coreutils p7zip gawk"
)

# Install packages depending on the operating system
if [[ "${package_lists[$OSTYPE]+exists}" ]]; then
    packages="${package_lists[$OSTYPE]}"
    if hash apt-get 2>/dev/null; then
        $sudo_cmd apt-get update
        $sudo_cmd apt-get install -y "${packages}"
    elif hash dnf 2>/dev/null; then
        $sudo_cmd dnf install -y "${packages}"
    elif hash pacman 2>/dev/null; then
        $sudo_cmd pacman -Sy --noconfirm --needed "${packages}"
    fi
else
    echo "Unsupported operating system."
    exit 1
fi

# Determine pip version
if hash pip3 2>/dev/null; then
    PIP=pip3
else
    PIP=pip
fi

# Create virtual environment and install packages
python3 -m venv .venv
source .venv/bin/activate
"$PIP" install backports.lzma extract-dtb protobuf pycrypto docopt zstandard twrpdtgen
