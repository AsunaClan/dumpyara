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

# Install packages depending on the operating system
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if hash apt 2>/dev/null; then
        packages=(
            unace
            unrar
            zip
            unzip
            p7zip-full
            p7zip-rar
            sharutils
            rar
            uudeview
            mpack
            arj
            cabextract
            device-tree-compiler
            liblzma-dev
            python3-pip
            brotli
            liblz4-tool
            axel
            gawk
            aria2
            detox
            cpio
            rename
            liblz4-dev
            curl
        )
        $sudo_cmd apt install "${packages[@]}" -y
    elif hash dnf 2>/dev/null; then
        packages=(
            unace
            unrar
            zip
            unzip
            sharutils
            uudeview
            arj
            cabextract
            file-roller
            dtc
            python3-pip
            brotli
            axel
            aria2
            detox
            cpio
            lz4
            python3-devel
            xz-devel
            p7zip
            p7zip-plugins
        )
        $sudo_cmd dnf install "${packages[@]}" -y
    elif hash pacman 2>/dev/null; then
        packages=(
            unace
            unrar
            zip
            unzip
            p7zip
            sharutils
            uudeview
            arj
            cabextract
            file-roller
            dtc
            python-pip
            brotli
            axel
            gawk
            aria2
            detox
            cpio
            lz4
        )
        $sudo_cmd pacman -Sy --noconfirm --needed "${packages[@]}"
    fi
    PIP=pip3
elif [[ "$OSTYPE" == "darwin"* ]]; then
    packages=(
        protobuf
        xz
        brotli
        lz4
        aria2
        detox
        coreutils
        p7zip
        gawk
    )
    brew install "${packages[@]}"
    PIP=pip
fi

# Create virtual environment and install packages
python3 -m venv .venv
source .venv/bin/activate
"$PIP" install backports.lzma extract-dtb protobuf pycrypto docopt zstandard twrpdtgen
