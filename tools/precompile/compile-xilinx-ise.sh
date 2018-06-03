#! /usr/bin/env bash
# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
#
# ==============================================================================
#	Authors:         	Martin Zabel
#                   Patrick Lehmann
#
#	Bash Script:			Compile Xilinx's ISE simulation libraries
#
# Description:
# ------------------------------------
#	This is a Bash script (executable) which:
#		- creates a subdirectory in the current working directory
#		- compiles all Xilinx ISE libraries
#
# License:
# ==============================================================================
# Copyright 2017-2018 Patrick Lehmann - Bötzingen, Germany
# Copyright 2007-2016 Technische Universität Dresden - Germany
#											Chair of VLSI-Design, Diagnostics and Architecture
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

# work around for Darwin (Mac OS)
READLINK=readlink; if [[ $(uname) == "Darwin" ]]; then READLINK=greadlink; fi

# Save working directory
WorkingDir=$(pwd)
ScriptDir="$(dirname $0)"
ScriptDir="$($READLINK -f $ScriptDir)"

PoCRootDir="$($READLINK -f $ScriptDir/../..)"
PoC_sh=$PoCRootDir/poc.sh

# source shared file from precompile directory
source $ScriptDir/precompile.sh


# command line argument processing
NO_COMMAND=1
VERBOSE=0
DEBUG=0
VHDL93=0
VHDL2008=0
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-c|--clean)
		CLEAN=TRUE
		;;
		-a|--all)
		COMPILE_ALL=TRUE
		NO_COMMAND=0
		;;
		--ghdl)
		COMPILE_FOR_GHDL=TRUE
		NO_COMMAND=0
		;;
		--questa)
		COMPILE_FOR_VSIM=TRUE
		NO_COMMAND=0
		;;
		-v|--verbose)
		VERBOSE=1
		;;
		-d|--debug)
		VERBOSE=1
		DEBUG=1
		;;
		-h|--help)
		HELP=TRUE
		NO_COMMAND=0
		;;
		--vhdl93)
		VHDL93=1
		;;
		--vhdl2008)
		VHDL2008=1
		;;
		*)		# unknown option
		echo 1>&2 -e "${COLORED_ERROR} Unknown command line option '$key'.${ANSI_NOCOLOR}"
		exit -1
		;;
	esac
	shift # past argument or value
done

if [ $NO_COMMAND -eq 1 ]; then
	HELP=TRUE
fi

if [ "$HELP" == "TRUE" ]; then
	test $NO_COMMAND -eq 1 && echo 1>&2 -e "\n${COLORED_ERROR} No command selected.${ANSI_NOCOLOR}"
	echo ""
	echo "Synopsis:"
	echo "  Script to compile the Xilinx ISE simulation libraries for"
	echo "  - GHDL"
	echo "  - QuestaSim/ModelSim"
	echo "  on Linux."
	echo ""
	echo "Usage:"
	echo "  compile-xilinx-ise.sh [-c] [--help|--all|--ghdl|--questa] [<Options>]"
	echo ""
	echo "Common commands:"
	echo "  -h --help             Print this help page"
	# echo "  -c --clean            Remove all generated files"
	echo ""
	echo "Common options:"
	echo "  -v --verbose          Print verbose messages."
	echo "  -d --debug            Print debug messages."
	echo ""
	echo "Tool chain:"
	echo "  -a --all              Compile for all tool chains."
	echo "     --ghdl             Compile for GHDL."
	echo "     --questa           Compile for QuestaSim/ModelSim."
	echo ""
	echo "Options:"
	echo "     --vhdl93           Compile for VHDL-93."
	echo "     --vhdl2008         Compile for VHDL-2008."
	echo ""
	exit 0
fi


if [ "$COMPILE_ALL" == "TRUE" ]; then
	test $VERBOSE -eq 1 && echo "  Enables all tool chains: GHDL, vsim"
	COMPILE_FOR_GHDL=TRUE
	COMPILE_FOR_VSIM=TRUE
fi
if [ \( $VHDL93 -eq 0 \) -a \( $VHDL2008 -eq 0 \) ]; then
	VHDL93=1
	VHDL2008=1
fi

test $VERBOSE -eq 1 && echo "  Query pyIPCMI for 'CONFIG.DirectoryNames:PrecompiledFiles'"
test $DEBUG   -eq 1 && echo "    $PoC_sh query CONFIG.DirectoryNames:PrecompiledFiles 2>/dev/null"
PrecompiledDir=$($PoC_sh query CONFIG.DirectoryNames:PrecompiledFiles 2>/dev/null)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} Cannot get precompiled directory name.${ANSI_NOCOLOR}"
	echo 1>&2 -e "${ANSI_RED}$PrecompiledDir${ANSI_NOCOLOR}"
	exit -1;
elif [ $DEBUG -eq 1 ]; then
	echo "    Return value: $PrecompiledDir"
fi

test $VERBOSE -eq 1 && echo "  Query pyIPCMI for 'CONFIG.DirectoryNames:XilinxSpecificFiles'"
test $DEBUG   -eq 1 && echo "    $PoC_sh query CONFIG.DirectoryNames:XilinxSpecificFiles 2>/dev/null"
XilinxDirName=$($PoC_sh query CONFIG.DirectoryNames:XilinxSpecificFiles 2>/dev/null)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} Cannot get Xilinx directory name.${ANSI_NOCOLOR}"
	echo 1>&2 -e "${ANSI_RED}$XilinxDirName${ANSI_NOCOLOR}"
	exit -1;
elif [ $DEBUG -eq 1 ]; then
	echo "    Return value: $XilinxDirName"
fi
XilinxDirName2=$XilinxDirName-ise

# GHDL
# ==============================================================================
if [ "$COMPILE_FOR_GHDL" == "TRUE" ]; then
	# Get GHDL directories
	# <= $GHDLBinDir
	# <= $GHDLScriptDir
	# <= $GHDLDirName
	GetGHDLDirectories $PoC_sh

	# Assemble output directory
	DestDir=$PoCRootDir/$PrecompiledDir/$GHDLDirName
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir

	# Assemble Xilinx compile script path
	GHDLXilinxScript="$($READLINK -f $GHDLScriptDir/compile-xilinx-ise.sh)"


	# Get Xilinx installation directory
	test $VERBOSE -eq 1 && echo "  Query pyIPCMI for 'INSTALL.Xilinx.ISE:InstallationDirectory'"
	test $DEBUG   -eq 1 && echo "    $PoC_sh query INSTALL.Xilinx.ISE:InstallationDirectory 2>/dev/null"
	ISEInstallDir=$($PoC_sh query INSTALL.Xilinx.ISE:InstallationDirectory 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${COLORED_ERROR} Cannot get Xilinx ISE installation directory.${ANSI_NOCOLOR}"
		echo 1>&2 -e "${COLORED_MESSAGE} $ISEInstallDir${ANSI_NOCOLOR}"
		echo 1>&2 -e "${ANSI_YELLOW}Run 'poc.sh configure' to configure your Xilinx ISE installation.${ANSI_NOCOLOR}"
		exit -1;
	elif [ $DEBUG -eq 1 ]; then
		echo "    Return value: $ISEInstallDir"
	fi
	SourceDir=$ISEInstallDir/ISE/vhdl/src

	# export GHDL binary dir if not allready set
	if [ -z $GHDL ]; then
		export GHDL=$GHDLBinDir/ghdl
	fi

	BASH=$(which bash)

	# compile all architectures, skip existing and large files, no wanrings
	if [ $VHDL93 -eq 1 ]; then
		$BASH $GHDLXilinxScript --all --vhdl93 -s -S -n --src $SourceDir --out $XilinxDirName2
		if [ $? -ne 0 ]; then
			echo 1>&2 -e "${COLORED_ERROR} While executing vendor library compile script from GHDL.${ANSI_NOCOLOR}"
			exit -1;
		fi
	fi
	if [ $VHDL2008 -eq 1 ]; then
		$BASH $GHDLXilinxScript --all --vhdl2008 -s -S -n --src $SourceDir --out $XilinxDirName2
		if [ $? -ne 0 ]; then
			echo 1>&2 -e "${COLORED_ERROR} While executing vendor library compile script from GHDL.${ANSI_NOCOLOR}"
			exit -1;
		fi
	fi

	# create "xilinx" symlink
	rm -f $XilinxDirName
	ln -s $XilinxDirName2 $XilinxDirName
fi

# QuestaSim/ModelSim
# ==============================================================================
if [ "$COMPILE_FOR_VSIM" == "TRUE" ]; then
	# Get GHDL directories
	# <= $VSimBinDir
	# <= $VSimDirName
	GetVSimDirectories $PoC_sh

	# Assemble output directory
	DestDir=$PoCRootDir/$PrecompiledDir/$VSimDirName/$XilinxDirName2
	# Create and change to destination directory
	# -> $DestinationDirectory
	CreateDestinationDirectory $DestDir

	# if XILINX environment variable is not set, load ISE environment
	if [ -z "$XILINX" ]; then
		test $VERBOSE -eq 1 && echo "  Query pyIPCMI for 'Xilinx.ISE:SettingsFile'"
		test $DEBUG   -eq 1 && echo "    $PoC_sh query Xilinx.ISE:SettingsFile 2>/dev/null"
		ISE_SettingsFile=$($PoC_sh query Xilinx.ISE:SettingsFile)
		if [ $? -ne 0 ]; then
			echo 1>&2 -e "${COLORED_ERROR} No Xilinx ISE installation found.${ANSI_NOCOLOR}"
			echo 1>&2 -e "${COLORED_MESSAGE} $ISE_SettingsFile${ANSI_NOCOLOR}"
			echo 1>&2 -e "${ANSI_YELLOW}Run 'poc.sh configure' to configure your Xilinx ISE installation.${ANSI_NOCOLOR}"
			exit -1
		elif [ $DEBUG -eq 1 ]; then
			echo "    Return value: $ISE_SettingsFile"
		fi
		echo -e "${ANSI_YELLOW}Loading Xilinx ISE environment '$ISE_SettingsFile'${ANSI_NOCOLOR}"
		RescueArgs=$@
		set --
		source "$ISE_SettingsFile"
		set -- $RescueArgs
	fi
	
	test $VERBOSE -eq 1 && echo "  Query pyIPCMI for 'INSTALL.Xilinx.ISE:BinaryDirectory'"
	test $DEBUG   -eq 1 && echo "    $PoC_sh query INSTALL.Xilinx.ISE:BinaryDirectory 2>/dev/null"
	ISEBinDir=$($PoC_sh query INSTALL.Xilinx.ISE:BinaryDirectory 2>/dev/null)
  if [ $? -ne 0 ]; then
	  echo 1>&2 -e "${COLORED_ERROR} Cannot get Xilinx ISE binary directory.${ANSI_NOCOLOR}"
	  echo 1>&2 -e "${COLORED_MESSAGE} $ISEBinDir${ANSI_NOCOLOR}"
		echo 1>&2 -e "${ANSI_YELLOW}Run 'poc.sh configure' to configure your Xilinx ISE installation.${ANSI_NOCOLOR}"
		exit -1;
	elif [ $DEBUG -eq 1 ]; then
		echo "    Return value: $ISEBinDir"
  fi
	ISE_compxlib=$ISEBinDir/compxlib

	# create an empty modelsim.ini in the 'xilinx-ise' directory and add reference to parent modelsim.ini
	CreateLocalModelsim_ini

	Simulator=questa
	Language=vhdl
	TargetArchitecture=all			# all, virtex5, virtex6, virtex7, ...

	# compile common libraries
	$ISE_compxlib -64bit -s $Simulator -l $Language -dir $DestDir -p $VSimBinDir -arch $TargetArchitecture -lib unisim -lib simprim -lib xilinxcorelib -intstyle ise
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${COLORED_ERROR} Error while compiling Xilinx ISE libraries.${ANSI_NOCOLOR}"
		exit -1;
	fi

	# create "xilinx" symlink
	cd ..
	rm -f $XilinxDirName
	ln -s $XilinxDirName2 $XilinxDirName
fi
