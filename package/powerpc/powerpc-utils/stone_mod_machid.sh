# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/powerpc/powerpc-utils/stone_mod_machid.sh
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
#
# [MAIN] 35 machid Macintosh mouse emulation

write_config() {
	cat << EOT > /etc/conf/mac_hid
mouse_button_emulation="$mouse_button_emulation"
mouse_button2_keycode="$mouse_button2_keycode"
mouse_button3_keycode="$mouse_button3_keycode"
EOT
}

set_enable() {
	gui_menu machid_enable \
	"Should the mouse emulation be activated. (Current: $mouse_button_emulation)" \
	'enable emulation' 'mouse_button_emulation=1' \
	'disable emulation' 'mouse_button_emulation=0'
	write_config
}

set_button() {
	gui_input "Set new keycode for button $1" \
                  `eval echo "$"$2` "$2"
	write_config
}

main() {
    while
	mouse_button_emulation=1
	mouse_button2_keycode=68 #96
	mouse_button3_keycode=87 #125
	[ -f /etc/conf/mac_hid ] && . /etc/conf/mac_hid

	gui_menu machid 'Macintosh mouse button emulation.
Select an item to change the value:\n(Example keys: F10:68, F11: 87, Apple: 125, KP_Return: 96 - others use showkey)' \
		"Emulation enabled ........ $mouse_button_emulation"   'set_enable' \
		"Mouse Button 2 keycode ... $mouse_button2_keycode" 'set_button 2 mouse_button2_keycode' \
		"Mouse Button 3 keycode ... $mouse_button3_keycode" 'set_button 3 mouse_button3_keycode' \
		'' '' \
		'Edit the /etc/conf/mac_hid file'				\
			"gui_edit 'MAC HID Config File' /etc/conf/mac_hid"	\
		'Configure runlevels for mac_hid service'			\
			'$STONE runlevel edit_srv mac_hid'			\
		'(Re-)Start mac_hid init script'				\
			'$STONE runlevel restart mac_hid'
    do : ; done
}

