#!/bin/bash

if [ -z "$INSTALL_WRAPPER_MYPATH" ]; then
	# someone brain-washed the environment.. tztz.
	INSTALL_WRAPPER_MYPATH="$( dirname "`type -p $0`"; )"
fi

PATH="${PATH/:$INSTALL_WRAPPER_MYPATH:/:}"
PATH="${PATH#$INSTALL_WRAPPER_MYPATH:}"
PATH="${PATH%:$INSTALL_WRAPPER_MYPATH}"

filter="${INSTALL_WRAPPER_FILTER:+|} $INSTALL_WRAPPER_FILTER"

if [ "$INSTALL_WRAPPER_NOLOOP" = 1 ]; then
	echo "--"
	echo "Found loop in install_wrapper: $0 $*" >&2
	echo "INSTALL_WRAPPER_MYPATH=$INSTALL_WRAPPER_MYPATH"
	echo "PATH=$PATH"
	echo "--"
	exit 1
fi
export INSTALL_WRAPPER_NOLOOP=1

logfile="${INSTALL_WRAPPER_LOGFILE:-/dev/null}"
[ -z "${logfile##*/*}" -a ! -d "${logfile%/*}" ] && logfile=/dev/null

command="${0##*/}"
error=0

echo ""						>> $logfile
echo "$PWD:"					>> $logfile
echo "* ${INSTALL_WRAPPER_FILTER:-No Filter.}"	>> $logfile
echo "- $command $*"				>> $logfile

case "$command" in
	chmod|chown)
		declare -a newparams
		newparams[0]="$command"
		actually_got_file_params=0
		newparams_c=0
		for p; do
			case "$p" in
				-*) newparams[newparams_c++]="$p" ;;
				*)  f="$( eval "echo \"$p\" | tr -s '/' $filter" )"
				    if [ -n "$f" ]; then
					newparams[newparams_c++]="$f"
					if [ -f "$f" -o -z "${f##*/*}" ]; then
						actually_got_file_params=1
					fi
				    fi ;;
			esac
		done
		if [ $actually_got_file_params = 1 ]; then
			echo "+ $command ${newparams[*]}" >> $logfile
			$command "${newparams[@]}" || error=$?
		fi
		echo "===> Returncode: $error" >> $logfile
		exit $error
		;;
esac

destination=""
declare -a sources
newcommand="$command"
sources_counter=0

if [ "${*/--target-directory//}" != "$*" ]; then
	echo "= $command $*" >> $logfile
	$command "$@"; exit $?
fi

while [ $# -gt 0 ]; do
	# Ignore any verbose option
	if [ "${1:0:1}" == "-" -a "${1:0:2}" != "--" ]; then
		if [ "$1" == "-v" ]; then shift; continue; fi
		param="${1//v/}"
	else
		param="$1"
	fi	

	case "$param" in  
		--verbose)
			;;	
		-g|-m|-o|-S|--group|--mode|--owner|--suffix)
			newcommand="$newcommand $param $2"
			shift 1
			;;
		-s|--strip)
			if [ "$ROCKCFG_DEBUG" = 0 -a "$STRIP" = "strip" ] || [[ $command != *install ]]
			then
				newcommand="$newcommand $param"
			fi
			;;
		-*)
			newcommand="$newcommand $param"
			;;
		*)
			if [ -n "$destination" ]; then
				sources[sources_counter++]="$destination"
			fi
			destination="$param"
			;;
	esac
	shift 1
done
unset param

[ -z "${destination##/*}" ] || destination="$PWD/$destination"

if [ "$filter" != " " ]; then
	destination="$( eval "echo \"$destination\" | tr -s '/' $filter" )"
fi

if [ -z "$destination" ]; then
	: do nothing
elif [ $sources_counter -eq 0 ]; then
	echo "+ $newcommand $destination" >> $logfile
	$newcommand "$destination" || error=$?
elif [ -d "$destination" ]; then
	for source in "${sources[@]}"; do
		thisdest="${destination}"
		[ ! -d "${source//\/\///}" ] && thisdest="$thisdest/${source##*/}"
		thisdest="${thisdest//\/\///}"
		[ "$filter" != " " ] && thisdest="$( eval "echo \"$thisdest\" $filter" )"
		if [ ! -z "$thisdest" ]; then
			echo "+ $newcommand $source $thisdest" >> $logfile
			$newcommand "$source" "$thisdest" || error=$?
		fi
	done
else
	echo "+ $newcommand ${sources[*]} $destination" >> $logfile
	$newcommand "${sources[@]}" "$destination" || error=$?
fi

echo "===> Returncode: $error" >> $logfile
exit $error

