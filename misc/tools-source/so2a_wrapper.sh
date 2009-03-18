#!/bin/bash

# run the original command
"$@"; rc=$?

if [ -n "$AUTOSO2A_DIR" ] && \
   [[ "$*" == *" -shared "* ]]
then
  mkdir -p "$AUTOSO2A_DIR"
  {
	echo "--"; echo "$0 $*"; shift
	arname="a.out"; objs=""; del=""

	while [ "$#" -gt 0 ]
	do
		case "$1" in
			-o)
				arname="${2##*/}"; shift
				;;
			[^-]*.o|[^-]*.lo)
				if [ -f $1 ]; then
					echo "Add object: $1"
					objs="$objs $1"
				else
					echo "$0: Don't know how to handle $1 .." >&2
					echo "Don't know how to handle $1 .."
				fi
				;;
			[^-]*.a|[^-]*.al)
				if [ -f $1 ]; then
					echo "Add archive: $1"
					tmpdir=$( mktemp -d ); del="$del $tmpdir"
					( cd $tmpdir; ar x /dev/fd/0; ) < $1
					for x in $tmpdir/*; do
						[ -f $x ] || continue
						echo "  - $x"; objs="$objs $x"
					done
				else
					echo "$0: Don't know how to handle $1 .." >&2
					echo "Don't know how to handle $1 .."
				fi
				;;
			[^-]*)
				echo "$0: Don't know how to handle $1 .." >&2
				echo "Don't know how to handle $1 .."
				;;
		esac
		shift
	done

	[[ "$arname" == *.so* ]] && arname="${arname%.so*}.a"
	echo "Output file: $arname"

	rm -f "$AUTOSO2A_DIR/$arname"
	if ! $AUTOSO2A_AR q "$AUTOSO2A_DIR/$arname" $objs 2>&1; then
		echo "$0: Got an error while running $AUTOSO2A_AR .." >&2
	fi
	$AUTOSO2A_RANLIB "$AUTOSO2A_DIR/$arname"
  } >> "$AUTOSO2A_DIR/so2a_wrapper.log"
fi

exit $rc

