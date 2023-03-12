#!/bin/bash

# Based on the installer found here: https://github.com/Sygil-Dev/sygil-webui
# This script will install git and conda (if not found on the PATH variable)
# using micromamba (an 8mb static-linked single-file binary, conda replacement).
# This enables a user to install this project without manually installing conda and git.

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "What is your GPU?"
echo
echo "A) NVIDIA"
echo "B) AMD"
echo "C) None (I want to run in CPU mode)"
echo
echo -n "Input> "
read gpuchoice
gpuchoice=${gpuchoice:0:1}
gpuchoice=${gpuchoice^^}

if [ "$gpuchoice" == "A" ]; then
    PACKAGES_TO_INSTALL="torchvision torchaudio pytorch-cuda=11.7 conda git"
    CHANNEL="-c nvidia"
elif [ "$gpuchoice" == "B" ]; then
    PACKAGES_TO_INSTALL="conda git"
    CHANNEL=""
elif [ "$gpuchoice" == "C" ]; then
    PACKAGES_TO_INSTALL="torchvision torchaudio pytorch conda git"
    CHANNEL=""
else
    echo "Invalid choice. Exiting..."
    exit
fi

OS_ARCH=$(uname -m)
case "${OS_ARCH}" in
    x86_64*)    OS_ARCH="64";;
    arm64*)     OS_ARCH="aarch64";;
    *)          echo "Unknown system architecture: $OS_ARCH! This script runs only on x86_64 or arm64" && exit
esac

# config
export MAMBA_ROOT_PREFIX="$(pwd)/installer_files/mamba"
INSTALL_ENV_DIR="$(pwd)/installer_files/env"
MICROMAMBA_DOWNLOAD_URL="https://micro.mamba.pm/api/micromamba/linux-${OS_ARCH}/latest"
umamba_exists="F"

# figure out whether git and conda needs to be installed
if [ -e "$INSTALL_ENV_DIR" ]; then export PATH="$INSTALL_ENV_DIR/bin:$PATH"; fi

if "$MAMBA_ROOT_PREFIX/micromamba" --version &>/dev/null; then umamba_exists="T"; fi

# (if necessary) install git and conda into a contained environment
if [ "$PACKAGES_TO_INSTALL" != "" ]; then
    # download micromamba
    if [ "$umamba_exists" == "F" ]; then
        echo "Downloading micromamba from $MICROMAMBA_DOWNLOAD_URL to $MAMBA_ROOT_PREFIX/micromamba"

        mkdir -p "$MAMBA_ROOT_PREFIX"
        curl -L "$MICROMAMBA_DOWNLOAD_URL" | tar -xvj bin/micromamba -O > "$MAMBA_ROOT_PREFIX/micromamba"

        chmod u+x "$MAMBA_ROOT_PREFIX/micromamba"

        # test the mamba binary
        echo "Micromamba version:"
        "$MAMBA_ROOT_PREFIX/micromamba" --version
    fi

    # create the installer env
    if [ ! -e "$INSTALL_ENV_DIR" ]; then
        "$MAMBA_ROOT_PREFIX/micromamba" create -y --prefix "$INSTALL_ENV_DIR"
    fi

    echo "Packages to install: $PACKAGES_TO_INSTALL"

    "$MAMBA_ROOT_PREFIX/micromamba" install -y --prefix "$INSTALL_ENV_DIR" -c conda-forge -c pytorch $CHANNEL $PACKAGES_TO_INSTALL
    "$MAMBA_ROOT_PREFIX/micromamba" install -y --prefix "$INSTALL_ENV_DIR" -c conda-forge -c pytorch $CHANNEL $PACKAGES_TO_INSTALL

    if [ ! -e "$INSTALL_ENV_DIR" ]; then
        echo "There was a problem while initializing micromamba. Cannot continue."
        exit
    fi
fi

if [ -e "$INSTALL_ENV_DIR" ]; then export PATH="$INSTALL_ENV_DIR/bin:$PATH"; fi

CONDA_BASEPATH=$(conda info --base)
source "$CONDA_BASEPATH/etc/profile.d/conda.sh" # otherwise conda complains about 'shell not initialized' (needed when running in a script)

conda activate

if [ -d text-generation-webui ]; then
  cd text-generation-webui
  git pull
else
  git clone https://github.com/oobabooga/text-generation-webui.git
  cd text-generation-webui
fi

# AMD installation
if [ "$gpuchoice" == "B" ]; then
    pip3 install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm5.2
fi
python -m pip install -r requirements.txt
python -m pip install -r extensions/google_translate/requirements.txt
python -m pip install -r extensions/silero_tts/requirements.txt

echo
echo "Done!"
