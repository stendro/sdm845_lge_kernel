#!/bin/bash
#
# Stock kernel for LG Electronics msm8996 devices build script by jcadduono
# -modified by stendro
#
################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this
# file to point to the toolchain's root directory.
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh

# root directory of this kernel (this script's location)
RDIR=$(pwd)

# build dir
BDIR=build

# color codes
COLOR_N="\033[0m"
COLOR_R="\033[0;31m"
COLOR_G="\033[1;32m"
COLOR_P="\033[1;35m"

# enable ccache ?
USE_CCACHE=no

# version number
VER=$(cat "$RDIR/VERSION")

# compiler options
# requires proper cross-comiler
USE_GRAPHITE=no
if [ "$USE_GRAPHITE" = "yes" ]; then
MK_FLAGS="-fgraphite-identity \
 -ftree-loop-distribution \
 -floop-nest-optimize \
 -floop-interchange"
fi

# select cpu threads
THREADS=$(grep -c "processor" /proc/cpuinfo)

# directory containing cross-compiler
GCC_COMP=$HOME/build/toolchain/linaro7/bin/aarch64-linux-gnu-

# compiler version
GCC_VER="$(${GCC_COMP}gcc --version | head -n 1 | cut -f1 -d'~' | \
cut -f2 -d'(')+"

############## SCARY NO-TOUCHY STUFF ###############

ABORT() {
	echo -e $COLOR_R"Error: $*"
	exit 1
}

export MK_FLAGS
export ARCH=arm64
export KBUILD_BUILD_USER=stendro
export KBUILD_BUILD_HOST=github
if [ "$USE_CCACHE" = "yes" ]; then
  export CROSS_COMPILE="ccache $GCC_COMP"
else
  export CROSS_COMPILE=$GCC_COMP
fi

# selected device (Only supports lmg710)
DEVICE=LMG710

# link device name to lg config files
if [ "$DEVICE" = "LMG710" ]; then
  DEVICE_DEFCONFIG=judyln_lao_com-perf_defconfig
fi

# check for stuff
[ -f "$RDIR/arch/$ARCH/configs/${DEVICE_DEFCONFIG}" ] \
	|| ABORT "$DEVICE_DEFCONFIG not found in $ARCH configs!"

[ -x "${GCC_COMP}gcc" ] \
	|| ABORT "Cross-compiler not found at: ${GCC_COMP}gcc"

if [ "$USE_CCACHE" = "yes" ]; then
	command -v ccache >/dev/null 2>&1 \
	|| ABORT "Do you have ccache installed?"
fi

[ "$GCC_VER" ] || ABORT "Couldn't get GCC version."

# build commands
CLEAN_BUILD() {
	echo -e $COLOR_G"Cleaning build folder..."$COLOR_N
	rm -rf $BDIR && sleep 5
}

SETUP_BUILD() {
	echo -e $COLOR_G"Creating kernel config..."$COLOR_N
	mkdir -p $BDIR
	make -C "$RDIR" O=$BDIR "$DEVICE_DEFCONFIG" \
		|| ABORT "Failed to set up build."
}

BUILD_KERNEL() {
	echo -e $COLOR_G"Compiling kernel..."$COLOR_N
	TIMESTAMP1=$(date +%s)
	while ! make -C "$RDIR" O=$BDIR -j"$THREADS"; do
		read -rp "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) ABORT "Compilation discontinued." ;;
		esac
	done
	TIMESTAMP2=$(date +%s)
	BSEC=$((TIMESTAMP2-TIMESTAMP1))
	BTIME=$(printf '%02dm:%02ds' $(($BSEC/60)) $(($BSEC%60)))
}

INSTALL_MODULES() {
	grep -q 'CONFIG_MODULES=y' $BDIR/.config || return 0
	echo -e $COLOR_G"Installing kernel modules..."$COLOR_N
	make -C "$RDIR" O=$BDIR \
		INSTALL_MOD_PATH="." \
		INSTALL_MOD_STRIP=1 \
		modules_install
	rm $BDIR/lib/modules/*/build $BDIR/lib/modules/*/source
}

PREPARE_NEXT() {
	echo "$DEVICE" > $BDIR/DEVICE \
		|| echo -e $COLOR_R"Failed to reflect device!"
	if grep -q 'KERNEL_COMPRESSION_LZ4=y' $BDIR/.config; then
	  echo lz4 > $BDIR/COMPRESSION \
		|| echo -e $COLOR_R"Failed to reflect compression method!"
	else
	  echo gz > $BDIR/COMPRESSION \
		|| echo -e $COLOR_R"Failed to reflect compression method!"
	fi
	git log --oneline -50 > $BDIR/GITCOMMITS \
		|| echo -e $COLOR_R"Failed to reflect commit log!"
}

cd "$RDIR" || ABORT "Failed to enter $RDIR!"
echo -e $COLOR_G"Building ${DEVICE} ${VER}..."
echo -e $COLOR_P"Using $GCC_VER..."
if [ "$USE_CCACHE" = "yes" ]; then
  echo -e $COLOR_P"Using CCACHE..."
fi

CLEAN_BUILD &&
SETUP_BUILD &&
BUILD_KERNEL &&
INSTALL_MODULES &&
PREPARE_NEXT &&
echo -e $COLOR_G"Finished building ${DEVICE} ${VER} -- Kernel compilation took"$COLOR_R $BTIME
echo -e $COLOR_P"Run ./copy_finished.sh to create AnyKernel zip."
