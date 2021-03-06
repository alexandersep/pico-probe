#!/bin/bash

# Exit on error
set -e

# Number of cores when running make (default number of threads you have, can be replaced with a number (not in quotation marks))
#example 
#JNUM=4
JNUM=`nproc`
JNUM=$((JNUM / 2)) # Usually the amount of cores is half the threads. Assuming this is a multithreaded computer

# Where will the output go, (YOUR_CURRENT_LOCATION/pico) e.g. /home/user/Downloads/pico (if current location is Downloads)
OUTDIR="$(pwd)/pico"

# Install dependencies
GIT_DEPS="git"
SDK_DEPS="cmake gcc-arm-none-eabi gcc g++"
OPENOCD_DEPS="gdb-multiarch automake autoconf build-essential texinfo libtool libftdi-dev libusb-1.0-0-dev libncurses5" # added libncurses5, as not present in linuxmint by default
# Wget to download the deb and also gcc-arm-none-eabi toolchain specifically the arm-none-eabi-gdb binary
VSCODE_DEPS="wget" 
UART_DEPS="minicom"

# Build full list of dependencies
DEPS="$GIT_DEPS $SDK_DEPS $OPENOCD_DEPS $VSCODE_DEPS $UART_DEPS"
echo "Installing Dependencies"
sudo apt update
sudo apt install -y $DEPS

echo "Creating $OUTDIR"
# Create pico directory to put everything in
mkdir -p $OUTDIR
cd $OUTDIR

# Clone sw repos
GITHUB_PREFIX="https://github.com/raspberrypi/"
GIT_SUFFIX=".git"
SDK_BRANCH="master"

#for REPO in sdk #examples extras playground (this might be useless)
echo "Attempting to install pico-sdk"
REPO="sdk"
DEST="$OUTDIR/pico-$REPO"
# perhaps it's in downloads or documents
cd 
SDK_IN_BASHRC=$(cat .bashrc | grep "PICO_SDK_PATH" | cut -d ' ' -f 2 | cut -d '=' -f 1)
cd $OUTDIR

if [[ -d $DEST ]]; then 
	echo "$DEST already exists so skipping"
else
	REPO_URL="${GITHUB_PREFIX}pico-${REPO}${GIT_SUFFIX}"
	echo "Cloning $REPO_URL"
	git clone -b $SDK_BRANCH $REPO_URL

	# Any submodules
	cd $DEST
	git submodule update --init
	cd $OUTDIR

	# Define PICO_SDK_PATH in ~/.bashrc
	VARNAME="PICO_${REPO^^}_PATH"
	echo "Adding $VARNAME to ~/.bashrc"
	if [[ "$SDK_IN_BASHRC" != "" ]]; then
		echo "$SDK_IN_BASHRC has been found in the bashrc file so skipping"
	else
		echo "export $VARNAME=$DEST" >> ~/.bashrc
		# Pick up new variables we just defined
		source ~/.bashrc
	fi
	export ${VARNAME}=$DEST
fi

cd $OUTDIR

# Picoprobe and picotool
for REPO in picoprobe picotool
do
    DEST="$OUTDIR/$REPO"
    if [[ -d "$OUTDIR/$REPO" ]]; then 
	    echo "$REPO already exists skipping"
    else 
	    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
	    git clone $REPO_URL

	    # Build both
	    cd $DEST
	    mkdir build
	    cd build
	    cmake ../
	    make -j$JNUM

	    if [[ "$REPO" == "picotool" ]]; then
		echo "Attempting to install picotool to /usr/local/bin/picotool"
		DEST_LOCAL="/usr/local/bin/picotool"
		DEST="/usr/bin/picotool"
		if [[ -e $DEST_LOCAL ]]; then 
			echo "picotool already exists and can be found in $DEST_LOCAL"
		elif [[ -e $DEST ]]; then
			echo "picotool already exists and can be found in $DEST"
		else
			sudo cp picotool /usr/local/bin/
		fi
	    fi

	    cd $OUTDIR
    fi
done

# Build OpenOCD
echo "Building OpenOCD"
cd $OUTDIR
# Should we include picoprobe support (which is a Pico acting as a debugger for another Pico)
INCLUDE_PICOPROBE=1
OPENOCD_BRANCH="rp2040"
OPENOCD_CONFIGURE_ARGS="--enable-ftdi --enable-sysfsgpio --enable-bcm2835gpio"
if [[ "$INCLUDE_PICOPROBE" == 1 ]]; then
    OPENOCD_CONFIGURE_ARGS="$OPENOCD_CONFIGURE_ARGS --enable-picoprobe"
fi
git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b $OPENOCD_BRANCH --depth=1
cd openocd
./bootstrap
./configure $OPENOCD_CONFIGURE_ARGS
sudo make install -j$JNUM

cd $OUTDIR

# Install the arm-none-eabi-gdb binary for builing of C and ARM files for the pico
echo "Attempting to install arm-none-eabi-gdb"
GCC_ARM="arm-none-eabi.tar.bz2"
GCC_BIN_LOCAL_EXISTS="/usr/local/bin/arm-none-eabi-gdb"
if  [[ -e $GCC_BIN_LOCAL_EXISTS ]]; then
	echo "Binary already installed it is found in $GCC_BIN_LOCAL_EXISTS"
else
	echo "Installing gcc-arm-none-eabi"
	ARM_NONE_EABI_TAR="https://developer.arm.com/-/media/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2"

	sudo mkdir -p $(pwd)/gcc-arm-none-eabi-for-pico
	cd $(pwd)/gcc-arm-none-eabi-for-pico
	sudo wget -O $GCC_ARM $ARM_NONE_EABI_TAR
	sudo tar -jxvf $GCC_ARM 
	cd gcc*/bin/
	sudo cp arm-none-eabi-gdb /usr/local/bin
	cd ../../../
	sudo rm -rf gcc-arm-none-eabi-for-pico
fi

# UDEV rules for use of openocd debugging permissions (assuming plugdev is a part groups (in linux mint it is))
echo "Attempting to give permissions to plugdev group for openocd debugging"
OPENOCD_RULES_60="/etc/udev/rules.d/60-openocd.rules"
OPENOCD_RULES_98="/etc/udev/rules.d/98-openocd.rules"
if [[ -e $OPENOCD_RULES_60 ]]; then
	echo "$OPENOCD_RULES_60 already exists, assuming it's configured already"	
else
	echo "Raspberry Pi Picoprobe" | sudo tee --append $OPENOCD_RULES_60
	echo "ATTRS{idVendor}==\"2e8a\", ATTRS{idProduct}==\"0004\", MODE=\"660\", GROUP=\"plugdev\", TAG+=\"uaccess\"" | sudo tee --append $OPENOCD_RULES_60
	
	# Reload to prevent rebooting, but might still be necesary
	sudo udevadm control --reload
fi

# This may not be needed
if [[ -e $OPENOCD_RULES_98 ]]; then
	echo "$OPENOCD_RULES_98 already exists, assuming it's configured already"
else
	echo "ACTION!=\"add|change\", GOTO=\"openocd_rules_end\"" | sudo tee --append $OPENOCD_RULES_98
	
	echo "SUBSYSTEM!=\"usb|tty|hidraw\", GOTO=\"openocd_rules_end\"" | sudo tee --append $OPENOCD_RULES_98
	echo "SUBSYSTEM!=\"usb|tty|hidraw\", GOTO=\"openocd_rules_end\"" | sudo tee --append $OPENOCD_RULES_98
	echo "ATTRS{product}==\"*CMSIS-DAP*\", MODE=\"664\", GROUP=\"plugdev\"" | sudo tee --append $OPENOCD_RULES_98
	echo "LABEL=\"openocd_rules_end\"" | sudo tee --append $OPENOCD_RULES_98

	# Reload to prevent rebooting, but might still be necessary
	sudo udevadm control --reload
fi

# Install VSCODE 
#
EXTRA_VSCODE_DEPS="libx11-xcb1 libxcb-dri3-0 libdrm2 libgbm1 libegl-mesa0"
read -p "Do you want to install the latest version of vscode? y/n: " ANSWER
echo
echo "Preparing installation of vscode"
VSCODE_LOCATION="/usr/share/code/"
VSCODE="code"
if [[ -f vscode.deb ]]; then
        echo "Skipping vscode as vscode.deb exists"
	VSCODE="code"
elif [[ -d  $VSCODE_LOCATION ]]; then
	echo "Skipping vscode" 
	echo "Make sure you have these extensions installed"
	echo "marus25.cortex-debug"
	echo "ms-vscode.cmake-tools"
	echo "ms-vscode.cpptools"
elif [[ "$ANSWER" == "y" ]] || [[ "$ANSWER" == "yes" ]]; then
   	echo "Installing VSCODE"
	VSCODE_DEB="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"

	wget -O vscode.deb $VSCODE_DEB
	sudo apt install -y ./vscode.deb
	sudo apt install -y $EXTRA_VSCODE_DEPS

	# Get some of the extensions needed
	$VSCODE --install-extension marus25.cortex-debug
	$VSCODE --install-extension ms-vscode.cmake-tools
	$VSCODE --install-extension ms-vscode.cpptools
else
	echo "Assuming, no installation wanted of vscode"
fi

echo "Here is the list of extensions"
echo "----------------------------------"
EX=("dan-c-underwood.arm" "jeff-hykin.better-cpp-syntax" "ms-vscode.cpptools" "ms-vscode.cpptools-extension-pack"
    "ms-vscode.cpptools-themes" "twxs.cmake" "marus25.cortex-debug" "cschlosser.doxdocgen" "betwo.vscode-doxygen-runner"
    "betwo.vscode-doxygen-runner" "mhutchie.git-graph" "eamodio.gitlens")

for num in {1..11}
do
	echo "$num.${EX[$((num-1))]}"
done

read -p "Do you want to install the some or all extensions that are given in the module lectures? y/n: " ANSWER
echo
if [[ "$ANSWER" == "n" ]] || [[ "$ANSWER" == "no" ]]; then
	echo "You have selected no to installing the extensions"
elif [[ "$ANSWER" == "y" ]] || [[ "$ANSWER" == "yes" ]]; then
	echo "You have selected yes"
	read -p "What extension do you want to install? (type exit to stop, or list to list the extensions again): " ANSWER
	echo 
	while [[ "$ANSWER" != "exit" ]];
	do
		# List of extensions that we were told to install (if already installed, it will skip unless specify --force which I don't)
		# 
		if [[ "$ANSWER" == "list" ]]; then
			for num in {1..11}
			do
				echo "$num.${EX[$((num-1))]}"
			done
		elif [[ "$ANSWER" -ge "1" ]] && [[ "$ANSWER" -le "11" ]]; then
			$VSCODE --install-extension "${EX[$((ANSWER-1))]}" 
		else
			echo "Error: try again, input a number betwen 1-11"
		fi

		read -p "What extension do you want to install? (type exit to stop, or list to list the extensions again): " ANSWER
		echo
	done
	echo "Installed extensions"
else
	echo "Error: Assuming no, exiting"
fi
