#!/bin/bash
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/target/lvp/x86/release_skeleton/config.sh
# ROCK Linux is Copyright (C) 1998 - 2006 Clifford Wolf
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at Documentation/COPYING.
# 
# Many people helped and are helping developing ROCK Linux. Please
# have a look at http://www.rocklinux.org/ and the Documentation/TEAM
# file for details.
# 
# --- ROCK-COPYRIGHT-NOTE-END ---

. scripts/functions

[ -e .config ] && . .config
read a b lvp_ver < VERSION

oldcount=${LVP_COUNTME:-0}
quit=0

while [ "${quit}" == "0" ] ; do
	menu_init
	. scripts/configuration
	clear
	display
	read -p "Enter your choice> " choice
	case "${choice}" in
		q)
			quit=1
			;;
		s)
			save
			;;
		l)
			load
			;;
		c)
			save
			scripts/create_lvp
			if [ ${LVP_COUNTME} -eq 1 ] ; then
				read id a < <( ( cpuid 2>/dev/null ; hostid 2>/dev/null ; cat /etc/passwd ) | md5sum )
				program="`which curl`"
				if [ -z "${program}" ] ; then
					program="`which wget`"
					if [ -z "${program}" ] ; then
						echo "Can't find either curl or wget. Not counting this disk."
					else
						program="${program} -O - -o /dev/null http://lvp.crash-override.net/count.php?id=${id}"
					fi
				else
					program="${program} http://lvp.crash-override.net/count.php?id=${id} 2>/dev/null"
				fi
				${program}
			fi
			read -p "Press -<enter>- to continue"
			;;
		x)
			scripts/cleanup
			read -p "Press -<enter>- to continue"
			;;
		i)
			scripts/create_iso
			read -p "Press -<enter>- to continue"
			;;
		w)
			clear
			cat <<-EOF
			    NO WARRANTY

  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
REPAIR OR CORRECTION.

  12. IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED
TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY
YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER
PROGRAMS), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.
			EOF
			read -p "Press -<enter>- to continue"
			;;
		L)
			clear
			more=$( which more )
			${more:-cat} COPYING
			read -p "Press -<enter>- to continue"
			;;
		m)
			clear
			cat <<-EOF
If you want to make the author of this software happy, drop him a line:
	blindcoder@scavenger.homeip.net

Or support him:
	http://lvp.crash-override.net/support.html

Either way, you'll make a simple programmer very happy :-)

			EOF
			read -p "Press -<enter>- to continue"
			;;
		u)
			program="`which curl`"
			if [ -z "${program}" ] ; then
				program="`which wget`"
				if [ -z "${program}" ] ; then
					echo "Can't find either curl or wget. Please check"
					echo
					echo "	http://lvp.crash-override.net/latest.txt"
					echo
					echo "manually for an update."
				else
					program="${program} -O - http://lvp.crash-override.net/latest.txt"
				fi
			else
				program="${program} http://lvp.crash-override.net/latest.txt"
			fi
			read new_ver url < <( ${program} 2>/dev/null )
			if [ "${lvp_ver}" != "${new_ver}" ] ; then
				echo "New version LVP V${new_ver} is available! Download it at"
				echo "${url}"
				echo
			else
				echo "You already have the latest version."
				echo
			fi
			read -p "Press -<enter>- to continue"
			;;
		*)
			get ${choice}
			if [ "${LVP_COUNTME}" == "1" -a "${oldcount}" == "0" ] ; then
				read id a < <( ( cpuid 2>/dev/null ; hostid 2>/dev/null ; cat /etc/passwd ) | md5sum )
				cat <<-EOF
Thank you for deciding to have your disks counted!
To prevent abuse of the counter a semi-unique ID is sent to the server
when counting. Your ID is this:

	${id}

				EOF
				olddefault=${LVP_USE_DEFAULTS}
				LVP_USE_DEFAULTS=0
				confirm "Do you really want to do this"
				[ ${?} -eq 1 ] && LVP_COUNTME=0
				LVP_USE_DEFAULTS=${olddefault}
			fi
			oldcount=${LVP_COUNTME}
			;;
	esac
done

