#!/bin/bash
# Last modify: 28/07/2007
# by spina <spina80@freemail.it>

# Usata da make_module. Crea il pacchetto per la Slackware
function _make_module_pkg
{
    cd ${MODULE_PKG_DIR};

    # Estraggo la versione del kernel dal modulo creato
    local MODULE_KERNEL_VERSION=$(modinfo ./${MODULE_NAME} | grep vermagic| \tr -s ' ' ' '| cut -d' ' -f2);
    local MODULE_DEST_DIR=lib/modules/${MODULE_KERNEL_VERSION}/external;

    mkdir -p ${MODULE_DEST_DIR};
    mv ${MODULE_NAME} ${MODULE_DEST_DIR};

    # Modifico il nome del pacchetto aggiungendo alla fine, la versione del kernel
#     MODULE_PACK_NAME=${MODULE_PACK_NAME}_kernel_${MODULE_KERNEL_VERSION//-/_}.tgz;
#     makepkg -l y -c n ${MODULE_PACK_NAME};
    
#     mv ${MODULE_PACK_NAME} ${DEST_DIR};

    cd ${ROOT_DIR};

    return;
}

# Crea il modulo per il kernel
function _make_module
{
    local MODULE_DIR=lib/modules/fglrx/build_mod;

    # Copy arch-depend files
    cp -a arch/${ARCH}/${MODULE_DIR}/* common/${MODULE_DIR};
    
    cd common/${MODULE_DIR};

    # Se ci sono, applico le patch (backward compatibility)
    if [ -f ${ROOT_DIR}/${SCRIPT_DIR}/patch_functions.sh ]; then
	source ${ROOT_DIR}/${SCRIPT_DIR}/patch_functions.sh;
	_module_patch;
    fi

    # Make modules with ati's script
    if ! sh make.sh; then
	echo "Error -> I don't have make module";
	exit 3;
    fi
    
    # Make module package
    cd ..;
    if [[ $MODULE_NAME == "fglrx.ko" ]]; then
	mv fglrx*.ko fglrx.ko;
# 	gzip fglrx.ko; # crea il file con nome uguale a $MODULE_NAME
    else
	mv fglrx*.o fglrx.o;
# 	gzip fglrx.o; # crea il file con nome uguale a $MODULE_NAME
    fi
    cp -p ${MODULE_NAME} ${ROOT_DIR}/${MODULE_PKG_DIR};
    
    cd ${ROOT_DIR};

    _make_module_pkg;

    return;
}

# Crea il pacchetto per il server X
function _make_x
{
    local CHECK_SCRIPT=./check.sh;
    local XORG_7=0;

    # set X_VERSION
    PATH=$PATH:/usr/X11/bin:/usr/X11R6/bin
    source ${CHECK_SCRIPT} --noprint;
    
    case ${X_VERSION} in
	x670*) # Xorg Server 6.7
	    USE_X_VERSION=${X_VERSION/x670/x680}; # Use the xorg 6.8 files
	    ;;
	x7*) # Xorg Server 7.x
	    XORG_7=1; 
	    ;;
    esac

    [ -z $USE_X_VERSION ] && USE_X_VERSION=${X_VERSION};

    cd ${X_PKG_DIR};
    
    # 1)
    # MOVE ARCH DIPENDENT files
    mkdir -p usr;
  
    cp -a ${ROOT_DIR}/arch/${ARCH}/usr/* usr;
    
    case ${ARCH} in
	x86_64) 
	    LIB_DIR="usr/X11R6/lib64 usr/X11R6/lib";
	    ;;
	x86)
	    LIB_DIR=usr/X11R6/lib;
    esac
    

    # Make some symbolik link
    for dir in ${LIB_DIR}; 
      do
      ( # cd $dir;
	mkdir -p ${dir/X11R6\/}/ati
	mv $dir/libGL* ${dir/X11R6\/}/ati

	  for file in $( cd ${dir/X11R6\/}/ati ; ls *.so* ) ;
	    do
	    echo ln -sf ati/$file ${dir/X11R6\/}/$file ; ln -sf ati/$file ${dir/X11R6\/}/$file ;
		if [[ "$file" != *.so ]] ; then
			echo ln -sf $file ${dir/X11R6\/}/ati/${file%.*} ; ln -sf $file ${dir/X11R6\/}/ati/${file%.*} ;
		fi
	  done
      )
    done
        
    # 2)
    # MOVE ARCH INDIPENDENT files
    cp -rp ${ROOT_DIR}/common/usr/* usr;
	rm -rf usr/share/doc/fglrx

    cp -a ${ROOT_DIR}/common/opt usr;
    mkdir -p etc/ati
    cp -a ${ROOT_DIR}/common/etc/ati/{atiogl.xml,authatieventsd.sh,control,fglrxprofiles.csv,fglrxrc,signature} etc/ati/ 2>/dev/null;

    # 3)
    # MOVE USE_X_VERSION DEPENDENT files
    cp -rp ${ROOT_DIR}/${USE_X_VERSION}/usr/* usr;


    # 4)
    # Aggiusto i permessi
    # 4.1) Nella directory usr, tolgo i diritti di esecuzione a tutti i file che non siano:
    #      - binari
    #      - librerie (a meno che non siano .a, a questi tolgo il permesso di esecuzion)
    #      - direcoty
    ( cd usr;
        find . -not \( -wholename "*bin*" -o \( -wholename "*lib*" -a -not -wholename "*.a" \) \) -not -type d\
	    | xargs chmod -x
    )

    # 4.2) I file in usr/sbin devono avere il permesso di esecuzione solo per il root
    ( cd usr/sbin;
        chmod go-x *;
    )

    # 4.3) Assicuro i giusti permessi ai binari in usr/X11R6/bin
    ( cd usr/X11R6/bin;
	chmod a+x aticonfig fgl_glxgears fglrxinfo fglrx_xgamma 2>/dev/null;
        chmod go-x amdcccle fireglcontrolpanel 2>/dev/null;
    )

    # 4.4) Aggiusto i permessi ai file in etc/ati
    ( cd etc/ati;
	chmod a-x *;
	chmod a+x authatieventsd.sh 2>/dev/null;
    )

    # 5)
    # Alcuni dei file in etc/ati devono essere spostati come .new in modo da preservarli con la rimozione del
    # pacchetto. Inoltre lo script di installazione del pacchetto provvederà a rinominarli o a cancellarli se
    # necessario.
    ( cd etc/ati;
	for file in atiogl.xml authatieventsd.sh fglrxprofiles.csv fglrxrc; do
	    [ -f $file ] && mv $file ${file}.new;
	done
    )
    
    # 6)
    # If use xorg >= 7, remove obsolete directory X11R6
    if (( $XORG_7 )); then
	for dir in ${LIB_DIR}; # Move X modules in /usr/$LIB_DIR/xorg/modules
	  do
	  mkdir ${dir}/xorg;
	  mv ${dir}/modules ${dir}/xorg;
	done
	mv usr/X11R6/* usr/;
	rm -rf usr/X11R6;
    fi

    # 7) 
    # MAKE PACKAGE
#     local X_PACK_NAME=${X_PACK_PARTIAL_NAME/fglrx-/fglrx-${X_VERSION}-}.tgz;

    # Modify the slack-desc
#     ( cd install;
# 	sed s/fglrx:/fglrx-${X_VERSION}:/ slack-desc > slack-desc.tmp;
# 	mv -f slack-desc.tmp slack-desc
#     )
    
    # Strip binaries and libraries
    find . | xargs file | sed -n "/ELF.*executable/b PRINT;/ELF.*shared object/b PRINT;d;:PRINT s/\(.*\):.*/\1/;p;"\
	| xargs strip --strip-unneeded 2> /dev/null
    
#     makepkg -l y -c n ${X_PACK_NAME};
#     mv ${X_PACK_NAME} ${DEST_DIR};

    cd ${ROOT_DIR};

    return;
}

function buildpkg
{
    case $1 in
	Only_Module)
	    _make_module;
	    ;;
	Only_X)
	    _make_x;
	    ;;
	All)
	    _make_module;
	    _make_x;
	    ;;
        Test)
            local CHECK_SCRIPT=./check.sh;
            PATH=$PATH:/usr/X11/bin:/usr/X11R6/bin
            source ${CHECK_SCRIPT} --noprint;
            set;
            ;;
	*) echo "$1 unsupported";
	    exit 2;
	    ;;
    esac
}

function _detect_kernel_ver_from_PATH_KERNEL
{
    local INCLUDES=${KERNEL_PATH}/include/linux;
    KNL_VER=$(grep UTS_RELEASE ${INCLUDES}/version.h | cut -d'"' -f2);
    if [ -z ${KNL_VER} ]; then
	KNL_VER=$(grep UTS_RELEASE ${INCLUDES}/utsrelease.h | cut -d'"' -f2);
	if [ -z ${KNL_VER} ]; then
	    KNL_VER=$(grep UTS_RELEASE ${INCLUDES}/version-*.h 2>/dev/null | cut -d'"' -f2);
	fi
    fi
    
    if [ -z ${KNL_VER} ]; then
	echo "Error -> Kernel version not detected";
	exit 1;
    fi
}

function _init_env
{
    [ $(id -u) -gt 0 ] && echo "Only root can do it!" && exit 1;
    
    BUILD_VER=0.1;
    
    ROOT_DIR=$PWD; # Usata dal file patch_function (se esiste)
    echo "$ROOT_DIR" | grep -q " " && echo "The name of the current directory should not contain any spaces" && exit 1;
    
    ARCH=$(arch); # Usata dal file patch_function (se esiste)
    [[ $ARCH != x86_64 ]] && ARCH="x86";

    # Setto il nome de modulo
    if [ ! -z ${KERNEL_PATH} ]; then
	_detect_kernel_ver_from_PATH_KERNEL; # Setta KNL_VER, variabile usata dal file patch_function (se esiste)
    else
	KNL_VER=$(uname -r) # Usata dal file patch_function (se esiste)
    fi
    
    if [[ $KNL_VER == "2.6."* ]]; then
	MODULE_NAME=fglrx.ko;
    else
	MODULE_NAME=fglrx.o;
    fi

    SCRIPT_DIR=packages/ROCK; # Usata dal file patch_function (se esiste)
    ATI_DRIVER_VER=$(./ati-packager-helper.sh --version); # Usata dal file patch_function (se esiste)
    ATI_DRIVER_REL=$(./ati-packager-helper.sh --release);
    
    MODULE_PKG_DIR=${SCRIPT_DIR}/module_pkg;
#     MODULE_PACK_NAME=fglrx-module-${ATI_DRIVER_VER}-${ARCH}-${ATI_DRIVER_REL}
    
    X_PKG_DIR=${SCRIPT_DIR}/x_pkg;
#     X_PACK_PARTIAL_NAME=fglrx-${ATI_DRIVER_VER}-${ARCH}-${ATI_DRIVER_REL};
    
    DEST_DIR=${PWD%/*};
}

case $1 in
    --get-supported)
	echo -e "All\tOnly_Module\tOnly_X";
	;;
    --buildpkg)
	_init_env;
	echo -e "\nATI ROCK Linux Package Ver. $BUILD_VER"
	echo -e "Based on ATI SlackBuild by Emanuele Tomasi";
	buildpkg $2;
	;;
    *)
	echo "${1}: unsupported option passed by ati-installer.sh";
	;;
esac
