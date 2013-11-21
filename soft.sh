#!/bin/sh


NO_COLOR=$(tput sgr0)
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
LIME_YELLOW=$(tput setaf 190)
YELLOW=$(tput setaf 3)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

Kernel=`uname -r`
# CentOS 5.8
if [[ "$Kernel" == "2.6.18-308.el5" ]]; then
	RMX1000_RPM_FILE=${OFFICIAL_DIR}"/SoftMcuRPMs/RPMs/Plcm-Rmx1000-*.el5.x86_64.rpm"
# CentOs 6.3
elif [[ "$Kernel" == "2.6.32-279.el6.x86_64" ]]; then
	RMX1000_RPM_FILE=${OFFICIAL_DIR}"/SoftMcuRPMs/RPMs/Plcm-Rmx1000-*.el6.x86_64.rpm"
fi

LAST_BUILD="/Carmel-Versions/CustomerBuild/RMX_100.0/200_last"
DIR_LIST=(MCMS_DIR CS_DIR MPMX_DIR MRMX_DIR ENGINE_DIR)
BUILD_LIST=(MCMS CS MPMX MC AUDIO VIDEO ENGINE)
START_UP_LOG=/tmp/startup_logs/soft_mcu_start_up.log
SERVICE_OUTPUT_LOG=/tmp/startup_logs/soft_mcu_service_output
 > $SERVICE_OUTPUT_LOG
#LOG="awk '{ print strftime("%Y%m%d%H%M%S"), $0; }' | tee -a $START_UP_LOG"
LOG="tee -a $START_UP_LOG"

export LD_LIBRARY_PATH=/mcms/Bin
export NATIVE_TOOLCHAIN=YES

export BUILD_MCMS=TRUE
export BUILD_CS=TRUE
export BUILD_MPMX=TRUE
export BUILD_MC=TRUE
export BUILD_AUDIO=TRUE
export BUILD_VIDEO=TRUE
export BUILD_ENGINE=TRUE

export Kernel=`uname -r`

################################ HELP ##################################
if [ "$1" == "" ]
then
	echo "usage: soft.sh COMMAND"
	echo "commands:"
	echo "make [MCMS|CS|MPMX|MC|AUDIO|VIDEO|ENGINE]- build all soft mcu components (native toolchain mode)"
	echo "make_clean - clean all soft mcu components"
	echo "clean - clean all soft mcu components"
	echo "start - start all soft mcu processes"
	echo "start [process] - start all soft mcu processes and test specific process with Valgrind, process={mcms process, mfa, mrmx process} - example: soft.sh start mfa" 	
	echo "target - start all soft mcu processes, on an rpm installed target"
	echo "stop - stop all soft mcu processes"
	echo
	echo "mandatory environment variables:"
	echo "MCMS_DIR - MCMS main folder"
	echo "CS_DIR - CS main folder"
	echo "MPMX_DIR - MPMX main folder"
	echo "MRMX_DIR - MRMX main folder (MC, AUDIO, VIDEO sources)"
	echo "ENGINE_DIR - Engine MRM main folder"
	echo
	echo "mandatory Soft MCU testing environment variables:"
	echo "CALLGEN_IP - Call Generator IP"
	echo "EP1 - First End Point IP"
	echo "EP2 - Second End Point IP"

	echo "optional environment variables:"
	echo "FARM=YES  - for fast compilation over farm" 
	exit 
fi



#################################################################################
#										#
#				SERVICE FUNCTIONS				#
#										#
#################################################################################


###########################################################################
setup_env (){
	mkdir -p /tmp/mfa_x86_env/bin /tmp/mfa_x86_env/cfg /tmp/mfa_x86_env/logs 
	mkdir -p /tmp/mfa_x86_env/mcms_share/cfg /tmp/mfa_x86_env/mcms_share/bin
	
	
		 
	# CentOs 6.3
	if [[ "$Kernel" == "2.6.32-279.el6.x86_64" ]]; then
		if [ -e Bin.i32cent63 ]; then
			echo "Copy SOFT MCU binaries CentOS 6.3 into Bin folder..."
			rm -Rf Bin/*
			(
				cd Bin
				find ../Bin.i32cent63 -type f -exec ln -sf {} . \;
				find ../Bin.i32cent63 -type l -exec ln -sf {} . \;
				#ln -sf ../Bin.i32ptx/lib* ../Bin.i32ptx/httpd ../Bin.i32ptx/mod_polycom.so  ../Bin.i32ptx/libMcmsCs.so \
				#../Bin.i32ptx/snmpd ../Bin.i32ptx/openssl ../Bin.i32ptx/ApacheModule ../Bin.i32ptx/McuCmd .
				#ln -sf ../Bin.i32cent63/* . 
				#ln -sf /usr/local/apache2/bin/httpd .
			) 2> /dev/null
		fi 
	else
		if [ -e Bin.i32cent56 ]; then
			echo "Copy SOFT MCU binaries CentOS 5.6 into Bin folder..."
			rm -Rf Bin/*
			(
				cd Bin
				find ../Bin.i32cent56 -type f -exec ln -sf {} . \;
				find ../Bin.i32cent56 -type l -exec ln -sf {} . \;
				#ln -sf ../Bin.i32ptx/lib* ../Bin.i32ptx/httpd ../Bin.i32ptx/mod_polycom.so  ../Bin.i32ptx/libMcmsCs.so \
				#../Bin.i32ptx/snmpd ../Bin.i32ptx/openssl ../Bin.i32ptx/ApacheModule ../Bin.i32ptx/McuCmd .
				#ln -sf ../Bin.i32cent56/* . 
			) 2> /dev/null
		fi
	fi
	
	#Fix INFRA-38
	#rm -f Bin/ApacheModule

	if [[ $MCMS_DIR == "$OFFICIAL_DIR/mcms/" ]];then
		if [[ $CLEAN_CFG != "NO" ]];then
			rm -rf $HOME/dev_env/*
		fi
                setup_env_official_mcms
        fi
	
	rm /tmp/mcms
	ln -sf $MCMS_DIR /tmp/mcms

	if [[ $CS_DIR == "$OFFICIAL_DIR/cs_smcu/CS/" ]];then
                setup_env_official_cs
        fi
	
	if [[ $MPMX_DIR != "$OFFICIAL_DIR/MediaCard/MFA/MFA/MPMX/" ]]; then
                cd $MPMX_DIR
                ./Script/build-x86_env.sh
                cd -
        fi
}

###########################################################################
setup_env_official_mcms (){
	
	echo -n "Settup your mcms cfg env..."
	USER_MCMS_DIR="$HOME/dev_env/mcms/"
	mkdir -p $USER_MCMS_DIR
	cd $USER_MCMS_DIR &> /dev/null
	mkdir -p Audit Backup CdrFiles Cores Faults IVRX Keys KeysForCS LogFiles MediaRecording Restore States TestResults Bin EMACfg
	cd - &> /dev/null
	
	ln -sf $MCMS_DIR/EMA $USER_MCMS_DIR/EMA
	ln -sf $MCMS_DIR/Libs $USER_MCMS_DIR/Libs
	ln -sf $MCMS_DIR/MIBS $USER_MCMS_DIR/MIBS
	ln -sf $MCMS_DIR/Scripts $USER_MCMS_DIR/Scripts
	ln -sf $MCMS_DIR/StaticCfg $USER_MCMS_DIR/StaticCfg
	ln -sf $MCMS_DIR/VersionCfg $USER_MCMS_DIR/VersionCfg
	ln -sf $MCMS_DIR/Makefile $USER_MCMS_DIR/Makefile
	ln -sf $MCMS_DIR/Main.mk $USER_MCMS_DIR/Main.mk
	ln -sf $MCMS_DIR/Processes $USER_MCMS_DIR/Processes

	if [ ! -d $USER_MCMS_DIR/Cfg ]; then
		cp -rf $MCMS_DIR/Cfg $USER_MCMS_DIR
	fi
	if [ ! -d $USER_MCMS_DIR/IVRX ]; then
		cp -rf $MCMS_DIR/IVRX $USER_MCMS_DIR
	fi
	if [ ! -d $USER_MCMS_DIR/Utils ]; then
		cp -rf $MCMS_DIR/Utils $USER_MCMS_DIR
	fi

	# Fix SA on OFFICIAL BUILD
	cp -rf ${MCMS_DIR}/StaticCfg $USER_MCMS_DIR
	chmod u+w $USER_MCMS_DIR/StaticCfg/httpd.conf.sim
	if [[ ! `tail -1 $USER_MCMS_DIR/StaticCfg/httpd.conf.sim | grep '^User'` ]]; then
	        echo "User `whoami`" >> $USER_MCMS_DIR/StaticCfg/httpd.conf.sim
	fi
	rm -f $USER_MCMS_DIR/StaticCfg/httpd.conf
	cd $USER_MCMS_DIR/StaticCfg
	ln -s httpd.conf.sim httpd.conf
	cd -

	echo "Copy SOFT MCU binaries into Bin folder..."
	# CentOs 6.3
	if [[ "$Kernel" == "2.6.32-279.el6.x86_64" ]]; then
		rm -Rf $USER_MCMS_DIR/Bin/*
		(
			cd $USER_MCMS_DIR/Bin
			#ln -sf $MCMS_DIR/Bin.i32ptx/lib* $MCMS_DIR/Bin.i32ptx/httpd $MCMS_DIR/Bin.i32ptx/mod_polycom.so  $MCMS_DIR/Bin.i32ptx/libMcmsCs.so \
			ln -sf $MCMS_DIR/Bin.i32ptx/lib* $MCMS_DIR/Bin.i32ptx/mod_polycom.so  $MCMS_DIR/Bin.i32ptx/libMcmsCs.so \
			$MCMS_DIR/Bin.i32ptx/snmpd $MCMS_DIR/Bin.i32ptx/openssl $MCMS_DIR/Bin.i32ptx/ApacheModule $MCMS_DIR/Bin.i32ptx/McuCmd .
			ln -sf $MCMS_DIR/Bin.i32cent63/* . 
			ln -sf /usr/local/apache/bin/httpd .
		) 2> /dev/null
	else
		rm -Rf $USER_MCMS_DIR/Bin/*
		(
			cd $USER_MCMS_DIR/Bin
			ln -sf $MCMS_DIR/Bin.i32ptx/lib* $MCMS_DIR/Bin.i32ptx/httpd $MCMS_DIR/Bin.i32ptx/mod_polycom.so  $MCMS_DIR/Bin.i32ptx/libMcmsCs.so \
			$MCMS_DIR/Bin.i32ptx/openssl $MCMS_DIR/Bin.i32ptx/ApacheModule $MCMS_DIR/Bin.i32ptx/McuCmd .
			ln -sf $MCMS_DIR/Bin.i32cent56/* . 
		) 2> /dev/null
	fi

	

	export MCMS_DIR=$USER_MCMS_DIR
	rm /tmp/mcms
	
	echo "Done."
}

###########################################################################
setup_env_official_cs (){
	
	echo -n "Settup your cs env..."

	USER_CS_DIR="$HOME/dev_env/cs/"
	mkdir -p $USER_CS_DIR
	cd $USER_CS_DIR &> /dev/null
	mkdir -p logs/cs1 ocs/cs1
	cd - &> /dev/null

	rm -f $USER_CS_DIR/bin  $USER_CS_DIR/scripts  $USER_CS_DIR/lib	
	ln -sf $CS_DIR/bin $USER_CS_DIR/bin
	ln -sf $CS_DIR/scripts $USER_CS_DIR/scripts
	ln -sf $CS_DIR/lib $USER_CS_DIR/lib

	if [ ! -d $USER_CS_DIR/cfg ]; then
		cp -rf $CS_DIR/cfg $USER_CS_DIR
	fi

	export CS_DIR=$USER_CS_DIR
	rm /tmp/cs
	ln -sf $CS_DIR /tmp/cs
	
	echo "Done."
}



###########################################################################
export_official () {
	
	case $1 in
	MCMS_DIR)
		export $1=$OFFICIAL_DIR/mcms/
		;;
	CS_DIR)
		export $1=$OFFICIAL_DIR/cs_smcu/CS/
		;;
	MPMX_DIR)
		export $1=$OFFICIAL_DIR/MediaCard/MFA/MFA/MPMX/
		;;
	MRMX_DIR)
		export $1=$OFFICIAL_DIR/MRMX/
		;;
	ENGINE_DIR)
		export $1=$OFFICIAL_DIR/EngineMRM/
		;;
	esac
}

##############################################################################
test_using_official (){

	OFFICIAL=`echo $1 | grep $OFFICIAL_DIR`
	if [[ $OFFICIAL != "" || $1 == "$USER_MCMS_DIR" ]]; then
		echo " - Using Official Build $OFFICIAL_DIR"
	else
		echo " - On a private path: $1"
	fi
}


##############################################################################
mark_not_to_build () {

	case $1 in
	MCMS_DIR)
		export BUILD_MCMS=FALSE
		;;
	CS_DIR)
		export BUILD_CS=FALSE
		;;
	MPMX_DIR)
		export BUILD_MPMX=FALSE
		;;
	MRMX_DIR)
		export BUILD_MC=FALSE
		export BUILD_AUDIO=FALSE
		export BUILD_VIDEO=FALSE
		;;
	ENGINE_DIR)
		export BUILD_ENGINE=FALSE
		;;
	esac
}

#############################################################################
echo_build_projects (){
	echo
	echo "building projects:"
	echo "=================="
	for build in ${BUILD_LIST[*]}
	do
		echo `env | grep BUILD_$build=`
	done

	echo
}

#############################################################################
test_var (){
	VAR=`env | grep $1 | cut -d'=' -f2`
	if [  "$VAR" == "" ]; then
		LOOP="true"
		while [[ "$LOOP" == "true" ]]; do
			clear
			echo -e  "Please specify $1 directory:\n1. Use $1 from last build\n2. export $1=PATH (.../vob/MCMS/Main)"
			read -p "Your choice [1/2]:" 	
			case $REPLY in
			1)
				export_last $1
				LOOP="false";
				;;
			2)
				read -p "export $1="
				export "$1"="$REPLY"
				LOOP="false"
				;;
			*)
				echo "Invalid choice..."
				sleep 1
				;;				
			esac
		done
	fi
}	

#############################################################################
#Point Projects directories that were not export to 'last', and mark them not to be built
test_dir (){
	
	OFFICIAL=`env | grep "OFFICIAL_DIR" | cut -d'=' -f2`
	VAR=`env | grep $1 | cut -d'=' -f2`
	#Test official build dir
	if [ "$OFFICIAL" != "" ]; then
		if [ -d "$OFFICIAL_DIR" ]; then
			
			if [  "$VAR" == "" ]; then
				export_official $1 
				mark_not_to_build $1
			else		
				TMP=`env | grep $1 | cut -d'=' -f2 | grep NonStableBuild`
				if [ "$TMP" != "" ]; then
					mark_not_to_build $1
				fi
			fi

		else
			echo "OFFICIAL_DIR is invalid: $OFFICIAL_DIR"
			exit 1
		fi
	else
		#subproject 
		if [  "$VAR" == "" ]; then
			echo "Please specify $1 directory by export $1=PATH (.../vob/MCMS/Main)"
			exit 1
		else		
			TMP=`env | grep $1 | cut -d'=' -f2 | grep NonStableBuild`
			if [ "$TMP" != "" ]; then
				mark_not_to_build $1
			fi
		fi
	fi
}


################################ VARIABLES VERIFICATION ##################################
verify_variables () {
	for var in ${DIR_LIST[*]}
	do
		test_dir $var
	done

	echo ""
	echo "Verifying variables:"
	echo "===================="

	if [ -e $MCMS_DIR/Scripts/soft.sh ]
	then
	 	echo -n "MCMS_DIR is verified"
		test_using_official $MCMS_DIR
	else
		echo "MCMS_DIR is invalid:" $MCMS_DIR
		return 1
	fi

	if [ -e $CS_DIR/bin/loader ]
	then
	 	echo -n "CS_DIR is verified"
		test_using_official $CS_DIR
	else
		echo "CS_DIR is invalid:" $CS_DIR
		return 1
	fi

	if [ -e $MPMX_DIR/Script/runmfa.sh ]
	then
	 	echo -n "MPMX_DIR is verified"
		test_using_official $MPMX_DIR
	else
		echo "MPMX_DIR is invalid:" $MPMX_DIR
		return 1
	fi

	if [ -e $MRMX_DIR/mp*proxy ]
	then
		echo -n "MRMX_DIR is verified"
		test_using_official $MRMX_DIR
	else
		echo "MRMX_DIR is invalid:" $MRMX_DIR
		return 1
	fi

	if [ -e $ENGINE_DIR/Scripts/ ]
	then
	 	echo -n "ENGINE_DIR is verified"
		test_using_official $ENGINE_DIR
	else
		echo "ENGINE_DIR is invalid:" $ENGINE_DIR
		return 1
	fi
}

################################## Make MCMS #############################
make_MCMS() {
	cd $MCMS_DIR
	if [[ "$KLOCWORK" == "YES" ]]; then
		echo "This compilation will run KLOCWORK analyze!!!"
		make active
		/opt/polycom/soft_mcu/KW_local_analyze.sh MCMS_7_6_1S " " ./make.sh  || echo "Klocwork - Nothing to analyze. "
		return 0
	fi
	
	if [[ $? == 0 ]]; then
		make active
		./make.sh || return 1
	else	
			return 1
	fi
}

################################## Make CS #############################
make_CS() {

	cd $CS_DIR
	if [[ $? == 0 ]]; then

		if [ -e $MCMS_DIR/CSFirstRun ]
		then
			echo "Compile the CS without -C"
			./csmake || return 1
		else
		 	echo "Compile the CS with -C"
	                touch $MCMS_DIR/CSFirstRun
			./csmake -C || return 1
		fi

	else
		return 1
	fi
}

################################## Make MediaCard #############################
make_MPMX() {
	cd $MPMX_DIR
	if [[ $? == 0 ]]; then
		./_MPMXmake_ -x86 || return 1
		./Script/build-x86_env.sh || return 1
	else	
		return 1
	fi
}

################################## Make MC #############################
make_MC() {
	ln -sf $RMX1000_RPM_FILE /tmp/rmx1000.rpm
	. $MCMS_DIR/Scripts/InstallRmx1000rpm.sh	
	#cd $MRMX_DIR/mermaid/
	cd $MRMX_DIR/mp_proxy
	if [[ $? == 0 ]]; then
		make -j4 || return 1
	else	
		return 1
	fi
}

################################## Make AUDIO #############################
make_AUDIO() {
	cd $MRMX_DIR/ampSoft/
	if [[ $? == 0 ]]; then
		echo "Compile audio"
		make -j4 || return 1
	else	
		return 1
	fi
}

################################## Make VIDEO #############################
make_VIDEO() {
	cd $MRMX_DIR/vmp/
	if [[ $? == 0 ]]; then
		echo "Compile video"
		source $MRMX_DIR/vmp/ia64_pt
		make -j8 || return 1
		make install
	else	
		return 1
	fi
}
################################## Make ENGINE #############################
make_ENGINE() {

	cd $ENGINE_DIR

	if [[ "$KLOCWORK" == "YES" ]]; then
		echo "This compilation will run KLOCWORK analyze!!!"
		/opt/polycom/soft_mcu/KW_local_analyze.sh EngineMRM_7_6_1S " " make  ||  echo "Klocwork - Nothing to analyze."
		return 0
	fi
	
	if [[ "$FARM" == "YES" ]]; then
		export DISTCC_DIR=/nethome/sagia/distcc
		export MAKEPARM=-j36
		export DISTCC_BIN=$DISTCC_DIR/bin/distcc
		export PREMAKE=$DISTCC_DIR/bin/pump
		unset DISTCC_HOSTS
	fi

	if [[ $? == 0 ]]; then
		$PREMAKE make $MAKEPARM || return 1
	else	
		return 1
	fi
}

################################## MAKE All##################################
make_all_projects (){
	
	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit
	fi	
	
	#If 'soft.sh make TARGET' is used, export only this TARGET as TRUE and the rest with FALSE
	if [[ "$1" != "" ]]
	then
		for build in ${BUILD_LIST[*]}
		do
			if [ "$build" == $1 ]; then
				export BUILD_$build=TRUE
			else
				export BUILD_$build=FALSE
			fi
		done
	fi	

	echo_build_projects
	
	#Loop to build each project
	for build in ${BUILD_LIST[*]}
	do
		if [ `env | grep BUILD_$build= | cut -d'=' -f2` == TRUE ]; then
			trace_start_build $build
			make_$build
			compile_result $? "BUILD_$build"
		fi
	done
	
	compile_result 0 "ALL"
}

################################## MAKE CLEAN ##################################
make_clean (){


	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit
	fi

#Cleaning
	clean

# Building
	echo "building all soft mcu process after clean"

	make_all_projects

	exit 0 
}


################################## CLEAN ##################################
clean () {
	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit
	fi

	echo "cleaning soft mcu modules"
	echo_build_projects
	
	if [ "$BUILD_MCMS" == "TRUE" ]; then
		cd $MCMS_DIR
		./fast_clean.sh
	fi
	#cd $CS_DIR
	#Force CS make clean by removing the following file:
	if [ "$BUILD_CS" == "TRUE" ]; then
		rm -f $MCMS_DIR/CSFirstRun
	fi

	if [ "$BUILD_MPMX" == "TRUE" ]; then
		cd $MPMX_DIR
		make clean
	fi

	if [ "$BUILD_MC" == "TRUE" ]; then
		#cd $MRMX_DIR/mermaid/
		cd $MRMX_DIR/mp_proxy
		make clean
	fi

	if [ "$BUILD_AUDIO" == "TRUE" ]; then
		cd $MRMX_DIR/ampSoft/
		make clean
	fi
	if [ "$BUILD_VIDEO" == "TRUE" ]; then
		cd $MRMX_DIR/vmp/
		source ./ia64_pt
		make clean
	fi

	if [ "$BUILD_ENGINE" == "TRUE" ]; then
		cd $ENGINE_DIR
		make clean
	fi
}


################################## MAKE RPM ################################
make_rpm () {

	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit
	fi

	echo "make rpm for soft mcu modules"
	echo_build_projects
	
	if [ "$BUILD_MCMS" == "TRUE" ]; then
		echo "Make MCMS RPM"
		cd $MCMS_DIR
		make active
		./MakeRpm.sh no
	fi

	
	if [ "$BUILD_CS" == "TRUE" ]; then
		echo "Make CS RPM"
		cd $CS_DIR
		./MakeRpm.sh no
	fi

	if [ "$BUILD_MPMX" == "TRUE" ]; then
		echo "Make MPMX RPM"
		cd $MPMX_DIR
		./MakeRPM.sh no
	fi

	if [ "$BUILD_MC" == "TRUE" ]; then
		echo "Make mp_proxy and amp RPM"
		cd $MRMX_DIR/
		./MakeRmx1000Rpm.sh yes
	fi


	if [ "$BUILD_AUDIO" == "TRUE" ]; then
		echo "Make Audio(Amp) RPM"
		cd $MRMX_DIR/ampSoft/
		./MakeRPM.sh no
	fi
	if [ "$BUILD_VIDEO" == "TRUE" ]; then
		echo "Make Video(Vmp) RPM"
		cd $MRMX_DIR/vmp/
		./MakeRPM.sh no
	fi
	if [ "$BUILD_ENGINE" == "TRUE" ]; then
		echo "Make engine RPM"
		cd $ENGINE_DIR
		./MakeRPM.sh no
	fi
}

################################## PRIVATE_BUILD ##################################
private_build(){
	if [ -d "$OFFICIAL_DIR" ]; then
		echo "Creating Private build:"
		# Create private rpms
		make_rpm
		# Prepare dir
		rm -rf	~/SoftMcu_PrivateBuild
		mkdir -p ~/SoftMcu_PrivateBuild
		
		# Copy original rpms
		cp $OFFICIAL_DIR/SoftMcuRPMs/RPMs/*.rpm ~/SoftMcu_PrivateBuild/
		
		# Copy specific rpms - per project
		if [ "$BUILD_MCMS" == "TRUE" ]; then
			rm ~/SoftMcu_PrivateBuild/Plcm-Mcms-*.i386.rpm
			echo "Copy MCMS RPM"
			cp ~/McmsRpmbuild/rpmbuild/RPMS/i386/Plcm-Mcms-*.i386.rpm ~/SoftMcu_PrivateBuild/
		fi
	
		if [ "$BUILD_CS" == "TRUE" ]; then
			rm ~/SoftMcu_PrivateBuild/Plcm-Cs-*.i386.rpm
			echo "Copy CS RPM"
			cp ~/CsRpmBuild/rpmbuild/RPMS/i386/Plcm-Cs-*.i386.rpm ~/SoftMcu_PrivateBuild/
		fi

		if [ "$BUILD_MPMX" == "TRUE" ]; then
			rm ~/SoftMcu_PrivateBuild/Plcm-Mpmx-*.i386.rpm
			echo "Copy MPMX RPM"
			cp ~/MediaCardRpm/rpmbuild/RPMS/i386/Plcm-Mpmx-*.i386.rpm ~/SoftMcu_PrivateBuild/
		fi

		if [ "$BUILD_MC" == "TRUE" ]; then
			rm ~/SoftMcu_PrivateBuild/Plcm-Rmx1000-*.i386.rpm
			rm ~/SoftMcu_PrivateBuild/Plcm-AmpSoft-*.i386.rpm
			rm ~/SoftMcu_PrivateBuild/Plcm-VmpSoft-*.x86_64.rpm
			rm ~/SoftMcu_PrivateBuild/Plcm-MpProxy-*.i386.rpm
			echo "Copy MpProxy, amp and vmp RPM"
			cp ~/Rmx1000Rpmbuild/rpmbuild/RPMS/i386/Plcm-Rmx1000-*.i386.rpm ~/SoftMcu_PrivateBuild/
			cp ~/Rmx1000Rpmbuild/rpmbuild/RPMS/i386/Plcm-AmpSoft-*.i386.rpm ~/SoftMcu_PrivateBuild/
			cp ~/Rmx1000Rpmbuild/rpmbuild/RPMS/x86_64/Plcm-VmpSoft-*.x86_64.rpm ~/SoftMcu_PrivateBuild/
			cp ~/Rmx1000Rpmbuild/rpmbuild/RPMS/i386/Plcm-MpProxy-*.i386.rpm ~/SoftMcu_PrivateBuild/
		fi

		if [ "$BUILD_ENGINE" == "TRUE" ]; then
			rm ~/SoftMcu_PrivateBuild/Plcm-EngineMRM-*.x86_64.rpm
			echo "Copy engine RPM"
			cp ~/EngineRpm/rpmbuild/RPMS/x86_64/Plcm-EngineMRM-*.x86_64.rpm ~/SoftMcu_PrivateBuild/
		fi
		echo -e ${GREEN}"Private build is ready at: $HOME/SoftMcu_PrivateBuild/"${NO_COLOR}
	else
		echo "OFFICIAL_DIR is invalid: $OFFICIAL_DIR"
		exit 1
	fi	
}

################################## START ##################################
install_build(){
	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit 1
	fi
	if [[ $1 == "" ]]; then
		echo "Usage: soft.sh install IP_ADDRESS"
		exit 1
	fi
	# Validate dest address
	ping -c 1 $1 &> /dev/null
	if [[ $? != 0 ]]; then
		echo -e ${RED}"$1 - Address is not reachable"${NO_COLOR}
		exit 1
	else
		ssh root@$1 'rm -rf /tmp/RPMs; mkdir -p /tmp/RPMs; service soft_mcu stop'
		echo "Copying rpm files to remote machine"
		scp ~/SoftMcu_PrivateBuild/*.rpm root@$1:/tmp/RPMs/
		echo "Installing remote machine"
		#ssh root@$1 'if [[ `rpm -qa | grep "Plcm" ` != "" ]]; then rpm -e Plcm-SoftMcuMain-* Plcm-EngineMRM-* Plcm-UI_AIM-* Plcm-jsoncpp-* Plcm-libphp-* Plcm-httpd-* Plcm-VmpSoft-* Plcm-MpProxy-* Plcm-AmpSoft-* Plcm-Rmx1000-* Plcm-Mpmx-* Plcm-Cs-* Plcm-Ema-* Plcm-Mcms-*; fi; cd /tmp/RPMs; rpm -ivh Plcm-SoftMcuMain-* Plcm-EngineMRM-* Plcm-UI_AIM-* Plcm-jsoncpp-* Plcm-libphp-* Plcm-httpd-* Plcm-VmpSoft-* Plcm-MpProxy-* Plcm-AmpSoft-* Plcm-Rmx1000-* Plcm-Mpmx-* Plcm-Cs-* Plcm-Ema-* Plcm-Mcms-*; if [[ $? == 0 ]]; then echo "===== INSTALLATION FINISHED ===="; else echo "===== INSTALLATION FAILED ====";fi'
		ssh root@$1 'if [[ `rpm -qa | grep "Plcm" ` != "" ]]; then rpm -e Plcm-SoftMcuMain-* Plcm-EngineMRM-* Plcm-UI_AIM-* Plcm-jsoncpp-* Plcm-VmpSoft-* Plcm-MpProxy-* Plcm-AmpSoft-* Plcm-Rmx1000-* Plcm-Mpmx-* Plcm-Cs-* Plcm-Ema-* Plcm-Mcms-* Plcm-SingleApache-*; fi; cd /tmp/RPMs; rpm -ivh Plcm-SoftMcuMain-* Plcm-EngineMRM-* Plcm-UI_AIM-* Plcm-jsoncpp-* Plcm-VmpSoft-* Plcm-MpProxy-* Plcm-AmpSoft-* Plcm-Rmx1000-* Plcm-Mpmx-* Plcm-Cs-* Plcm-Ema-* Plcm-Mcms-* Plcm-SingleApache-*; if [[ $? == 0 ]]; then echo "===== INSTALLATION FINISHED ===="; else echo "===== INSTALLATION FAILED ====";fi'
		 
	fi
}

################################## SETUP_VM ##################################
setup_sim_license_file(){

	# select license file by product type
	if [ "$LICENSE_FILE" == "" ]; then

		PRODUCT_TYPE=`cat /mcms/ProductType`

		if [ $PRODUCT_TYPE == "SOFT_MCU_EDGE" ]; then
			LICENSE_FILE="VersionCfg/Keycodes_SoftMcuEdgeAxis_20_HD.cfs"
		elif [ $PRODUCT_TYPE == "SOFT_MCU_CG" ]; then
			LICENSE_FILE="VersionCfg/Keycodes_SoftMcuCG.cfs"
		else
			LICENSE_FILE="VersionCfg/Keycodes_SoftMcu_20_HD.cfs"
		fi
	fi

	echo ""
	echo Using License file for simulation: $LICENSE_FILE
	
	mkdir -p /config/sysinfo
	chmod a+w /config/sysinfo
	
	cp $MCMS_DIR/$LICENSE_FILE /config/sysinfo/keycode.txt
	chmod a+w /config/sysinfo/keycode.txt
	
}

################################## SETUP_VM ##################################
setup_vm_all_products (){

	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit
	fi

	cd $MCMS_DIR
	stop
	
	make active

	setup_env

	rm /tmp/mcms
	ln -sf $MCMS_DIR /tmp/mcms
	
	ln -sf $RMX1000_RPM_FILE /tmp/rmx1000.rpm
	. $MCMS_DIR/Scripts/InstallRmx1000rpm.sh
	
	export VM=YES

	# Start of Block for Single Apache   - kobig , remove this link in VM=YES
#	rm -f /mcms/Bin/httpd 2> /dev/null
#	ln -sf /usr/local/apache2/bin/httpd /mcms/Bin/
	sudo /bin/rm /tmp/httpd.rest.conf
#	cp -f /usr/local/apache2/conf/httpd.rest.conf /tmp
	cp -f /mcms/StaticCfg/httpd.rest.conf /tmp

	sed -i 's#^Include /tmp/httpd\.rest\.conf.*$##' /tmp/mcms/StaticCfg/httpd.conf.sim
	sed -i 's/^User .*$//' /tmp/mcms/StaticCfg/httpd.conf.sim
	chmod u+w /tmp/mcms/StaticCfg/httpd.conf.sim
	echo "User `whoami`" >> /tmp/mcms/StaticCfg/httpd.conf.sim
	mkdir /mcms/logs 2> /dev/null
	chmod a+rwx /mcms/logs
	echo "Include /tmp/httpd.rest.conf" >> /tmp/mcms/StaticCfg/httpd.conf.sim
	echo "#!/bin/sh" > /mcms/Bin/ApacheModule
	echo "CMD='sudo env LD_LIBRARY_PATH=/usr/local/apache2/lib:/mcms/Bin /mcms/Bin/httpd'" >> /mcms/Bin/ApacheModule
	echo "CFG=/mcms/StaticCfg/httpd.conf.sim" >> /mcms/Bin/ApacheModule
	echo "LOG=/tmp/startup_logs/DaemonProcessesLoad.log" >> /mcms/Bin/ApacheModule
	echo "sleep 1" >> /mcms/Bin/ApacheModule
	echo "\$CMD -f \$CFG 2>&1 | tee -a \$LOG" >> /mcms/Bin/ApacheModule
	echo "while true; do" >> /mcms/Bin/ApacheModule
	echo "  sleep 10" >> /mcms/Bin/ApacheModule
	echo "  ps -e | grep -v grep | grep httpd >/dev/null || \$CMD -f \$CFG 2>&1 | tee -a \$LOG" >> /mcms/Bin/ApacheModule
	echo "done" >> /mcms/Bin/ApacheModule

	if [[ ! -e /mcms/EMA/htdocs ]]; then
               ln -sf ${LAST_BUILD}/ema/ /mcms/EMA/htdocs
	fi
	
	#if [[ `ps -e | grep ApacheModule | grep -v grep` ]]; then
	#	:
	#else
	#	nohup /mcms/Bin/ApacheModule 2> /dev/null &
	#fi
	# End Block for Single Apache

	if [ "$CLEAN_CFG" != "NO" ]
	then
		export CLEAN_CFG=YES
		echo "CONFIGURATION FILES WILL BE CLEANED"
	fi	
}

################################## START ##################################
start (){
	
	if [ `whoami` == "root" ]
  	then
		echo "You can't run this script as root!" | $LOG
    	exit 1
  	fi

  	# Gives 2 minutes to cool down in case of high load average.
	# Exits if the load still exist.
	export NUMBER_OF_CORES=`grep -c ^processor /proc/cpuinfo`
  	export LOAD_AVERAGE=`uptime | awk '{printf "%.0f\n",$(NF-2)}'`
  	export LOAD_THRESHOLD=1
  	if [[ $((LOAD_AVERAGE/NUMBER_OF_CORES)) -ge $LOAD_THRESHOLD ]]
  	then
    		echo "Load average $LOAD_AVERAGE / $NUMBER_OF_CORES >= $LOAD_THRESHOLD, wait for 2 minutes..." | $LOG
    		sleep 2m

    		LOAD_AVERAGE=`uptime | awk '{printf "%.0f\n",$(NF-2)}'`
    		if [[ $((LOAD_AVERAGE/NUMBER_OF_CORES)) -ge $LOAD_THRESHOLD ]]
		then
      			echo "Load average $LOAD_AVERAGE / $NUMBER_OF_CORES >= $LOAD_THRESHOLD, exit." | $LOG
      			exit 1
    		fi
  	fi
#Launch the periodic MCU status logger
        #echo "Launching Soft MCU Status Logger" | $LOG
	if [[ "YES" == "${VM}" ]]; then
        	/mcms/Scripts/status_logger.sh soft.sh /tmp/startup_logs/MCU_Process_Status.log 15  60 &
	fi
	MFA_WITH_VALGRIND="NO"
	if [[ "$1" != "" && "$1" == "mfa" ]]
	then
		MFA_WITH_VALGRIND="YES"	
	fi
				
	export LD_LIBRARY_PATH=$MCMS_DIR/Bin:$CS_DIR/lib
	export ENDPOINTSSIM=NO
	export GIDEONSIM=NO

	if [ "$CLEAN_CFG" != "YES" ]
	then
		echo "CONFIGURATION FILES WILL NOT BE CLEANED" | $LOG
		export CLEAN_CFG=NO
	fi

	export CLEAN_LOG_FILES=NO
	rm -f /tmp/httpd.pid

	cd $MCMS_DIR
	echo "Clean before start." | $LOG
	Scripts/Cleanup.sh 2>&1 | $LOG

	PRODUCT_TYPE=`cat /mcms/ProductType`
  	if [ -z $PRODUCT_TYPE ]; then
    		PRODUCT_TYPE="SOFT_MCU"
  	fi

  	echo "Start $PRODUCT_TYPE." | $LOG
  	export SOFT_MCU_FAMILY=YES

  	if [[ $PRODUCT_TYPE == "SOFT_MCU_MFW" ]]; then
    		export SOFT_MCU_MFW=YES
    		mkdir -p /mcms/EMA
  	elif [[ $PRODUCT_TYPE == "SOFT_MCU_EDGE" ]]; then
    		export SOFT_MCU_EDGE=YES
  	elif [[ "$PRODUCT_TYPE" == "GESHER" ]]; then
    		export GESHER=YES

    		echo "Gesher Bringing up eth0 first..."
    		Scripts/GesherUpEths.sh
    		echo "Run Gesher McmsStart.sh ..."
    		Scripts/GesherMcmsStart.sh &
 	elif [[ "$PRODUCT_TYPE" == "NINJA" ]]; then
    		export NINJA=YES

    		echo "Ninja Bringing up eth0 first..."
    		Scripts/GesherUpEths.sh
    		echo "Run Ninha McmsStart.sh ..."
    		Scripts/GesherMcmsStart.sh &
	elif [[ "$PRODUCT_TYPE" == "SOFT_MCU_CG" ]]; then
			export SOFT_MCU_CG=YES
  	else 
    		export SOFT_MCU=YES
  	fi
	
	echo -n $PRODUCT_TYPE > /tmp/EMAProductType.txt
	echo -n NO > /tmp/JITC_MODE.txt

	export MPL_SIM_FILE=VersionCfg/MPL_SIM_SWITCH_ONLY.XML

	make active
	
	echo "Start MCMS." | $LOG
	if [[ "$1" != "" ]]
	then	
		echo "#######################################" | $LOG
		echo "   Running $1 under Valgrind           " | $LOG
		echo "#######################################" | $LOG
		if [ ! -d TestResults ]; then
		   mkdir TestResults
		fi
		chmod 777 TestResults		
		Scripts/Startup.sh $1 $2 &				
	else
		Scripts/Startup.sh &
	fi	
		
	sleep 25

	if [[ $PRODUCT_TYPE == "SOFT_MCU_MFW" || $PRODUCT_TYPE == "SOFT_MCU_EDGE" || $PRODUCT_TYPE == "SOFT_MCU_CG" ]]; then
		if [ -e /tmp/stop_monitor ]
		then
			echo "Stop monitor for debug"
		else 
		# Makes sure processes are running
		echo "Watcher is alive." | $LOG
		Process_Watcher=$(ps -ef | grep SoftMcuWatcher.sh | grep -v grep)
		if [ "" == "${Process_Watcher}" ]
		then
			echo "Starting SoftMcuWatcher..." | $LOG
       			nohup /mcms/Scripts/SoftMcuWatcher.sh > /dev/null 2>&1 &
		fi
	fi
	fi
	
	if [ "YES" == "${VM}" ]
	then
		 sudo /bin/chmod -R a+w /etc/rmx1000/sysconfig
		 sed -i '/SkipImage.*/d' /etc/rmx1000/sysconfig/imgs_to_launch.conf
		cd $MPMX_DIR
		(echo "# Generated by soft.sh"
		echo export SIMULATION=YES
		echo export RUN_MCMS=NO
		echo export GDB=NO
		echo export VALGRIND=$MFA_WITH_VALGRIND
		echo export DMALLOC_SIM=NO
		echo export EFENCE_SIM=NO
		echo export TRACE_IPMC_PROTOCOL=NO
		echo export PLATFORM=RMX2000) > ./mfa_x86_env/cfg/runmfa.export
		echo "STARTING MPMX"
		(	
			export LD_LIBRARY_PATH=$MPMX_DIR/mfa_x86_env/bin
			ulimit -n 4096
			./Script/runmfa.sh 2>&1 1>/dev/null &
		)&
	else
	# to make sure processes are running
	Process_MpWatcher=$(ps -ef | grep MpWatcher.sh | grep -v grep)
	if [ "" == "${Process_MpWatcher}" ]
	then 
		/mcms/Scripts/MpWatcher.sh &
	fi
	fi
	# run rmx1000 parts
	( 
		export LD_LIBRARY_PATH=/usr/rmx1000/bin:$MRMX_DIR/libs/lib:$MRMX_DIR/libs/usr/lib
		ulimit -n 4096 
		nohup /usr/rmx1000/bin/launcher  
	) &


	cd $ENGINE_DIR
	echo "STARTING ENGINEMRM"
	./mrm.sh all &

	cp /mcms/Scripts/TLS/passphrase.sh     /tmp
	cp /mcms/Scripts/TLS/passphraseplcm.sh /tmp
	chown mcms:mcms /tmp/passphrase.sh
	chown mcms:mcms /tmp/passphraseplcm.sh

	# Making sure Single Apache is monitored
	sleep 5
	echo "**************************"
	echo "* STARTING SINGLE APACHE *"
	echo "**************************"
	# Force Single Apache binary to be used"
	if [[ `whoami` == 'root' || `whoami` == 'mcms' ]]; then
		rm -f /mcms/Bin/httpd	
		ln -sf /usr/local/apache2/bin/httpd /mcms/Bin/
	fi
	if [[ `ps -e | grep ApacheModule | grep -v grep` ]]; then
                :
        else
		if [[ "YES" == "${VM}" ]]; then
			echo "Running ApacheModule fix on VM"
                        #rm -rf /mcms/LogFiles
                        #rm -rf /tmp/LogFiles
                        #mkdir /tmp/LogFiles
                        #chmod a+wxr /tmp/LogFiles
                        #ln -sf /tmp/LogFiles /mcms/LogFiles
                        chmod u+x /mcms/Bin/ApacheModule
			/usr/bin/nohup /mcms/Bin/ApacheModule 2> /dev/null &
		fi
        fi

	sleep 5
	
	if [[ "YES" == "${VM}" ]]; then
		if [[ ! -d /mcms/LogFiles ]]; then
			rm -f /mcms/LogFiles
			mkdir /mcms/LogFiles
		fi
	fi

	cd $CS_DIR
	echo "Start CS." | $LOG
	mkdir -p /config/ocs
	chmod a+w /config/ocs
		
	#incase of upgrade change file to new name
	for i in 1 2 3 4 5 6 7 8
	
	do
	  ## create the directory if does not exist
	  mkdir -p /config/ocs/cs$i/keys

	  filename=/cs/ocs/cs$i/keys/certPassword.txt
	  if [ -f $filename ]
	  then  
	    newFileName=/cs/ocs/cs$i/keys/certPassword.txt.orig	
	    mv $filename $newFileName
	  fi
	  cs_destination=/cs/ocs/cs$i/keys
  	  cs_source=/config/keys/cs/cs$i/*
  
  	  cp -Rf $cs_source $cs_destination
  	  
	done
	cp -f /mcms/Versions.xml /tmp

	## path chanege from 7.8 cp -R /mcms/KeysForCS/* /cs/ocs/
	
	CS_NUM_OF_CALLS=-N400
	CS_PLATFORM_TYPE=-P6

	if [ "$PRODUCT_TYPE" == "SOFT_MCU_MFW" ]; then
		CS_NUM_OF_CALLS=-N2000	
		CS_PLATFORM_TYPE=-P7
	fi
	
	if [ "$VM" == "YES" ]
	then		
		./bin/acloader -c -C$CS_DIR/cfg/cfg_soft/cs_private_cfg_dev.xml $CS_PLATFORM_TYPE -S1 $CS_NUM_OF_CALLS
	else		
		./bin/acloader -c -C$CS_DIR/cfg/cfg_soft/cs_private_cfg_rel.xml $CS_PLATFORM_TYPE -S1 $CS_NUM_OF_CALLS
	fi

	# wait until CS is ended...
	exit
}

create_custom_cfg_file ()
{
	CUSTOM_CFG_FILE=/mcu_custom_config/custom.cfg

	echo "<SYSTEM_CFG>" >> $CUSTOM_CFG_FILE
	echo "	<CFG_SECTION>" >> $CUSTOM_CFG_FILE
	echo "	    <NAME>CUSTOM_CONFIG_PARAMETERS</NAME>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>REST_API_PORT</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>443</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>XML_API_PORT</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>8080</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>XML_API_HTTPS_PORT</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>4443</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>STUN_SERVER_PORT</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>3478</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>TURN_SERVER_PORT</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>3478</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>CUSTOM_USER_LOGIN</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>POLYCOM</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>CUSTOM_USER_PASSWD</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>POLYCOM</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     <CFG_PAIR>" >> $CUSTOM_CFG_FILE
	echo "	     	<KEY>FORCE_LOW_MEMORY_USAGE</KEY>" >> $CUSTOM_CFG_FILE
	echo "	        <DATA>NO</DATA>" >> $CUSTOM_CFG_FILE
	echo "	     </CFG_PAIR>" >> $CUSTOM_CFG_FILE				
	echo "	</CFG_SECTION>" >> $CUSTOM_CFG_FILE
	echo "</SYSTEM_CFG>" >> $CUSTOM_CFG_FILE

	chmod 777 $CUSTOM_CFG_FILE

}

create_custom_cfg_path ()
{
	if [ ! -d /mcu_custom_config ];then
		mkdir /mcu_custom_config
		chmod 777 /mcu_custom_config
		create_custom_cfg_file
	else
		CUSTOM_CFG_FILE=/mcu_custom_config/custom.cfg
		if [ -f $CUSTOM_CFG_FILE ];then
			chmod 777 $CUSTOM_CFG_FILE
		else			
			create_custom_cfg_file
		fi
	
	fi



}


################################## TARGET ##################################
target () {
	
	echo "TARGET LOG" > $START_UP_LOG
	
	rm -fR /tmp/queue
	rm -fR /tmp/shared_memory
	rm -fR /tmp/semaphore
	rm -fR /tmp/802_1xCtrl
	rm -f /tmp/loglog.txt
	rm -f /tmp/httpd.pid
	rm -f /tmp/httpd.listen.conf
	#rm -f /tmp/httpd.rest.conf	
	
	create_custom_cfg_path
	auto_detect_compilation_type
	touch /tmp/httpd.listen.conf
	#touch /tmp/httpd.rest.conf
	chmod 777 /tmp/httpd.listen.conf
	chmod 777 /tmp/httpd.rest.conf

	su - mcms -c "cd $MCMS_DIR ; . Scripts/SoftMcuExports.sh ; ./Scripts/soft.sh start $1 &"
	PRODUCT_TYPE=`cat /mcms/ProductType`
        if [[ $PRODUCT_TYPE != "SOFT_MCU_EDGE" ]];then      
		if [[ `ps -ef | grep /usr/local/apache2/bin/httpd | grep -v root` == "" ]];then		
			service httpd start
		fi    
	fi
	
	verify_system_is_up

	/usr/rmx1000/bin/SetAudioSoftPriority.sh
}

##################################Auto detect compilation type#############################

auto_detect_compilation_type () {

rm /usr/share/EngineMRM/Bin
FORCE_LOW_MEMORY_USAGE=`echo "cat /SYSTEM_CFG/CFG_SECTION/CFG_PAIR[KEY='FORCE_LOW_MEMORY_USAGE']/DATA/text()" | xmllint --shell /mcu_custom_config/custom.cfg  | egrep '^\w'`
if [[ "$FORCE_LOW_MEMORY_USAGE" == "YES" ]];then
	ln -sf /usr/share/EngineMRM/Bin-regular/ /usr/share/EngineMRM/Bin
	echo "FORCE_LOW_MEMORY_USAGE - low memory compilation" >> $START_UP_LOG
else
	MEMORY_AMOUNT=`cat /proc/meminfo | grep MemTotal | awk '{ print $2 }'`
	if [[ $MEMORY_AMOUNT -le 700000 ]];then		
	        echo "Auto detect memory low than 8g - stop startup!!" >> $START_UP_LOG
		echo "The system does not meet the minimum hardware requirements." > $SERVICE_OUTPUT_LOG
		stop
		exit 1
	fi

	PRODUCT_TYPE=`cat /mcms/ProductType`
	if [[ $MEMORY_AMOUNT -ge 12000000 && $PRODUCT_TYPE == "SOFT_MCU_MFW" ]];then
		ln -sf /usr/share/EngineMRM/Bin-high/ /usr/share/EngineMRM/Bin
	        echo "Auto detect high memory compilation" >> $START_UP_LOG
	else
		ln -sf /usr/share/EngineMRM/Bin-regular/ /usr/share/EngineMRM/Bin
	        echo "Auto detect low memory compilation" >> $START_UP_LOG
	fi	
	

fi
chown -R mcms:mcms /usr/share/EngineMRM/Bin

}

################################## VERIFY SYSTEM IS UP ##################################
verify_system_is_up () {
	
	# Allow 'start' to begin
	sleep 30
	# wait for 'audio_soft' to run and renice to -10
	AUDIO_SOFT_TIMOUT=60
	HTTPD_SOFT_TIMOUT=180
	time_out_counter=0
	while [[ $(ps -A | grep "audio_soft") == "" && $time_out_counter -le $AUDIO_SOFT_TIMOUT ]]
	do
		sleep 1
		((time_out_counter++))
	done

	if [[ $time_out_counter -ge $AUDIO_SOFT_TIMOUT ]]
	then
		echo "AUDIO_SOFT_TIMOUT ERPIRED" >> $START_UP_LOG
		stop
		exit 1			
	fi
	
	time_out_counter=0
	
	while [[ `ps -ef | grep /mcms/Bin/httpd | grep -v root` == "" && $time_out_counter -le $HTTPD_SOFT_TIMOUT ]]
   	do
       		sleep 1
       		((time_out_counter++))
   	done  

	if [[ $time_out_counter -ge $HTTPD_SOFT_TIMOUT ]]
	then
		echo "HTTPD_SOFT_TIMOUT EXPIRED" >> $START_UP_LOG
		stop
		exit 1			
	fi     
}

################################## STOP ##################################
stop ()
{
  PRODUCT_TYPE=`cat /mcms/ProductType`
  if [ -z $PRODUCT_TYPE ]; then
    PRODUCT_TYPE="SOFT_MCU" 
  fi

  echo "Stop $PRODUCT_TYPE." | $LOG

  if [[ $PRODUCT_TYPE == "SOFT_MCU_MFW" ]]; then
    export SOFT_MCU_MFW=YES 
  elif [[ $PRODUCT_TYPE == "SOFT_MCU_EDGE" ]]; then
    export SOFT_MCU_EDGE=YES 
  elif [[ "$PRODUCT_TYPE" == "GESHER" ]]; then
    export GESHER=YES
  elif [[ "$PRODUCT_TYPE" == "NINJA" ]]; then
    export NINJA=YES
  elif [[ "$PRODUCT_TYPE" == "SOFT_MCU_CG" ]]; then
    export SOFT_MCU_CG=YES
  else 
    export SOFT_MCU=YES 
  fi

  # Only if in vm simulation, stop Watcher process.
  if [[ $USER != "mcms" ]]; then
	killall -9 SoftMcuWatcher.sh 2> /dev/null
  fi

  export LD_LIBRARY_PATH=/mcms/Bin
  cd $MCMS_DIR
  echo -n "Flush Logger..." | $LOG
  pgrep -x Logger && Bin/McuCmd flush Logger < /dev/null && sleep 2
  echo "done." | $LOG

  # MCMS
  $MCMS_DIR/Scripts/Destroy.sh | $LOG
  killall Startup.sh WaitForStartup.sh 2>&1 | $LOG
  killall -9 MpWatcher.sh

  # Kills launcher first to prevent restart of some process.
  pgrep -x launcher && killall -9 launcher 2>&1 | $LOG && sleep 1

  # Generously asks to die and gives some time to free resources.
  killall -2 MRM-MrmMain acloader IpmcSim.x86 mfa audio_soft video 2>&1 | $LOG
  pkill -f status_logger.sh 2>&1 | $LOG

  # Brutal termination.
  PROCESSES="\
            MRM-MrmMain \
            acloader \
            tarAndZip \
            calltask \
            csman \
            gkiftask \
            h323LoadBalancer \
            mcmsif \
            siptask \
            mcms \
            IpmcSim.x86 \
            mfa \
            launcher\
            sys \
            mp \
            audio_soft \
            traced \
            Proxy \
            sys_status_monitor \
            ManageMcuMenu \
            menu \
            mpproxy \
            video \
            Startup.sh \
            WaitForStartup.sh \
            "

  # Limits process names to the 15 characters.
  for p in $PROCESSES
  do
    pgrep -x ${p:0:15} && echo "$p is still alive, finish him." | $LOG && killall -9 -v $p 2>&1 | $LOG
    killall -9 $p | $LOG &
  done

  wait

  for p in $PROCESSES
  do
    killall -9 $p
    pgrep -x ${p:0:15} && echo "Failed to kill $p." | $LOG
  done

    killall -9 launcher sys mp traced Proxy sys_status_moni ManageMcuMenu menu httpd mpproxy video sys_status_monitor \
               ASS-AMPMgr ASS-AMPUdpRx ASS-AH ASS-AMPTx ASS-AMPLog AMP-AmpAHMgr AMP-AmpAHDec0 AMP-AmpAHEnc0 AMP-AmpAHIvr0 mcmsif 2>/dev/null

    # Single Apache kill
    echo "Stopping Single Apache..." 
    pkill ApacheModule
    if [[ `whoami` == "root" ]]; then
	    ( pkill httpd && sleep 1; pkill -9 httpd && sleep 1 ) 2> /dev/null
    else
	    ( sudo pkill httpd && sleep 1; sudo pkill httpd && sleep 1 ) 2> /dev/null
    fi
  # Cleans files and shared memory (once) for MCMS.
  export -n SOFT_MCU_MFW
  export -n SOFT_MCU_EDGE
  export -n GESHER
  export -n NINJA
  export -n SOFT_MCU
  export -n SOFT_MCU_CG

  cd $MCMS_DIR

    kill -9 `pgrep Cards` 2> /dev/null
    kill -9 `pgrep MCCFMngr` 2> /dev/null
    #pkill -u mcms 2> /dev/null

    #echo "Cleaning system resources..."
  Scripts/Cleanup.sh | $LOG 
}

################################## TEST ##################################
# DTD_list  =====================================
DTD_list (){
  echo $COLORBROWN
  grep "#--DTD_" ./Scripts/DeliveryTestsDefs.sh | cut -f2 -d"_" | sort
  echo $TXTRESET
  #grep "#--DTD_" ./Scripts/NightTestsDefs.sh | grep -oE "[^_]+$"
}

# make_test  ====================================
make_test () {
	cd $MCMS_DIR  

	# Set global variables for colors
	. ./Scripts/ClrSetting.sh
	# Load set of functions of DeliveryTests
	. ./Scripts/DeliveryTestsDefs.sh 
	
	export LD_LIBRARY_PATH=/usr/local/apache2/lib:/mcms/Bin
        ulimit -c unlimited

	make active
	setup_env

	ln -sf $RMX1000_RPM_FILE /tmp/rmx1000.rpm
	. $MCMS_DIR/Scripts/InstallRmx1000rpm.sh

	param=${1-NONE}

        if [ $param != "NONE" ]
	then
	  if [ $param != "list" ]
          then
	  	echo "$COLORMGNTA********** Running $param tests ***************$TXTRESET"
		CleanCoreDumpsFiles
		#CheckCoreDumpsExisting
	  fi

	  DTD_$param Exit_From_MakeTest true
          
        else 
	  CleanCoreDumpsFiles

	  echo $COLORBROWN
	  echo "*****************************************"
	  echo "********** START DELIVERY TESTS *********"
	  echo "*****************************************"
	  echo $TXTRESET

          #echo "$COLORMGNTA********** Running SoftMCU System tests **********$TXTRESET"
          #DTD_SoftMCUSystemTests Exit_From_MakeTest false


	  echo "$COLORMGNTA********** Running MCMS Unit tests ***************$TXTRESET"
	  DTD_MCMSUnitTests Exit_From_MakeTest false


	  # VNGSW-168
	  #echo "$COLORMGNTA********** Running MCMS python tests **********$TXTRESET"
	  #StartMCMSPythonTests

	  #old way to run python tests
	  #make test_scripts

	  # The function runs 'AllVersionTestsBreezeMode.sh'
	  #DTD_MCMSAllVersionTestsBreezeMode Exit_From_MakeTest false

	  # The function runs 'AllVersionTestsBreezeModeCP.sh'
	  #DTD_MCMSAllVersionTestsBreezeModeCP Exit_From_MakeTest false

	  # The function runs 'AllVersionTestsBarakMode.sh'
	  #DTD_MCMSAllVersionTestsBarakMode Exit_From_MakeTest false

	  #EndMCMSPythonTests
	  # end of MCMS python tests

	
	  echo "$COLORMGNTA********** Running EngineMRM Unit tests **********$TXTRESET"
	  DTD_EngineMRMUnitTests Exit_From_MakeTest false

          
          Exit_From_MakeTest 0
	fi

}


################################## NIGHT ##################################
# NTD_list  =====================================
NTD_list (){
  echo $COLORBROWN
  grep "#--NTD_" ./Scripts/NightTestsDefs.sh | cut -f2 -d"_" | sort
  echo $TXTRESET
}

# night() ========================================
night () {
	if [ `whoami` == "root" ]
	then
		echo "You can't run this script as root!!!"
		exit
	fi

	# Set global variables for colors
  	. ./Scripts/ClrSetting.sh
  	# Load set of functions of NightTests
  	. ./Scripts/NightTestsDefs.sh 

	Init_NightTest

	param=${1-NONE}
	if [ $param != "NONE" ]
	then
	  if [ $param != "list" ]
          then
	  	echo $COLORMGNTA
		echo "NightTest($param) Start: `date` ; `hostname` ; `whoami` "
		echo $TXTRESET
		make active
		CleanAllRelevantDirs
		#CreateRelevantIssuesForNightTests
	  fi

	  NTD_$param Return_From_NightTest true  
          
        else
	  make active
          CleanAllRelevantDirs
	  CreateRelevantIssuesForNightTests

	  # To delete all directories older then 30 days
	  # This call must be located under 'CreateRelevantIssuesForNightTests()'
	  find $RootDirectory/* -type d -mtime +30 -exec rm -fR '{}' \; 2>/dev/null
	  #find $RootDirectory/* -type d -mtime +1 -exec rm -fR '{}' \; 2>/dev/null

	  echo $COLORBROWN
	  echo "************************************************************"
	  echo "NightTestStart: `date` ; `hostname` ; `whoami` "
	  echo "************************************************************"
	  echo $TXTRESET

	  echo "$COLORMGNTA********** Running SoftMCU system night tests **********$TXTRESET"
	  RunOneSetOfTests NTD_SoftMCUSystemTests "SystemTests" "SoftMCU tests"

	  echo "$COLORMGNTA********** Running EngineMRM night tests **********$TXTRESET"
	  RunOneSetOfTests NTD_EngineMRMNightTests "EngineMRM" "EngineMRM tests"

	  echo "$COLORMGNTA********** Running MCMS python night tests **********$TXTRESET"
	  StartMCMSPythonTests

	  #old way to run python tests
	  #make all_test_scripts

	  #The function runs 'Scripts/AutoRealVoip.sh'
	  RunOneSetOfTests NTD_MCMSAutoRealVoip "AutoRealVoip" "MCMS tests"

	  #The function runs 'Scripts/AutoRealVideo.sh'
	  RunOneSetOfTests NTD_MCMSAutoRealVideo "AutoRealVideo" "MCMS tests" 

	  #The function runs 'Scripts/Add20ConferenceNew.sh'
	  #RunOneSetOfTests NTD_MCMSAdd20ConferenceNew "Add20ConferenceNew" "MCMS tests"

	  #The function runs 'Scripts/AddDeleteIpServ.sh'
	  #RunOneSetOfTests NTD_MCMSAddDeleteIpServ "AddDeleteIpServ" "MCMS tests"

	  #The function runs 'Scripts/AddDeleteNewIvr.sh'
	  RunOneSetOfTests NTD_MCMSAddDeleteNewIvr "AddDeleteNewIvr" "MCMS tests"

	  #The function runs 'Scripts/AddIpServiceWithGkNew.sh'
	  #RunOneSetOfTests NTD_MCMSAddIpServiceWithGkNew "AddIpServiceWithGkNew" "MCMS tests"

	  #The function runs 'Scripts/AddIpServiceWithGk.sh'
	  #RunOneSetOfTests NTD_MCMSAddIpServiceWithGk "AddIpServiceWithGk" "MCMS tests"

	  #The function runs 'Scripts/AddRemoveMrNew.sh'
	  RunOneSetOfTests NTD_MCMSAddRemoveMrNew "AddRemoveMrNew" "MCMS tests"

	  #The function runs 'Scripts/AddRemoveOperator.sh'
	  RunOneSetOfTests NTD_MCMSAddRemoveOperator "AddRemoveOperator" "MCMS tests"

	  #The function runs 'Scripts/AddRemoveProfile.sh'
	  RunOneSetOfTests NTD_MCMSAddRemoveProfile "AddRemoveProfile" "MCMS tests"

	  EndMCMSPythonTests

	  #The function runs Scripts/run_night_test.sh
	  RunOneSetOfTests NTD_RMXPartNightTests "RMXNightTests" "RMX tests"


	  PrintHTMLEnd 
	  ./Scripts/MoveLastTblUP.sh $NightReportF "<table border=" "</table>"
          
	  SendMail $NightReportF

	  UnsetOfAllRestedExportVars
	fi

	exit 0
}

################################## LIST ######################################
McmsUnitTestList() {
	cd $MCMS_DIR
	for Name in ./Bin/*.Test ; 
	do
		echo "+-+-+- List of tests in '$Name' +-+-+-+"
		$Name list 2>&1 | grep "::"
	done
}

##############################################################################
trace_start_build (){
	echo -e ${BLUE}
	echo "#######################################"
	echo "#  Project: $1  #"
	echo "#  STARTING COMPILATION		    #"
	echo "#######################################"
	echo -e ${NO_COLOR}
}

##############################################################################
compile_result (){
	if [ $1 == 0 ];then
		echo -e ${GREEN}
		echo "#######################################"
		echo "#  Project: $2  #"
		echo "#  COMPILATION FINISHED SUCCESSFULLY  #"
		echo "#######################################"
		echo -e ${NO_COLOR}
	else
		echo -e ${RED}
		echo "##########################"
		echo "#  Project: $2  #"
		echo "#   COMPILATION FAILED   #"
		echo "##########################"
		echo -e ${NO_COLOR}
		exit 1
	fi
}


#################################################################
#								#
#			MAIN					#
#								#
#################################################################


verify_variables
if [ $? != 0 ];then
	exit 1
fi

echo -e "\nRunning soft.sh $1 $2:\n=================================="
        
case "$1" in
make)
	make_all_projects $2
	;;
make_clean)	
	make_clean
	;;
clean)
	clean
	;;
make_rpm)
	make_rpm
	;;
private_build)
	private_build
	;;
install_build)
	install_build $2
	;;
start_vm)
	setup_vm_all_products 
	echo -n SOFT_MCU > /mcms/ProductType
	setup_sim_license_file
	/opt/polycom/scalesuite_video_mount
	start $2
	;;
start_vm_cg)
	setup_vm_all_products 
	echo -n SOFT_MCU_CG > /mcms/ProductType
	setup_sim_license_file
	/opt/polycom/scalesuite_video_mount
	start $2
	;;
start_vm_mfw)
	setup_vm_all_products 
	echo -n SOFT_MCU_MFW > /mcms/ProductType
	setup_sim_license_file
	start $2
	;;
start_vm_edge)
	setup_vm_all_products 
	echo -n SOFT_MCU_EDGE > /mcms/ProductType
	setup_sim_license_file
	start $2
	;;
start_vm_gesher)
	setup_vm_all_products 
    	echo -n GESHER > /mcms/ProductType
	start $2
	;;
start)
	start $2
	;;
target)
	target $2
	;;
stop)
	stop	
	;;
test)
	make_test $2
	;;
night)
	night $2
	;;

mcmsUnitTestList)
	McmsUnitTestList
	;;
*)
	echo "$1: Action not supported."
	;;
esac
