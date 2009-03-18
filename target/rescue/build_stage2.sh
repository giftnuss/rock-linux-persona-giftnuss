
set -e
taropt="--use-compress-program=bzip2 -xf"

echo_header "Creating 2nd stage filesystem:"
mkdir -p $disksdir/rescue_root ; cd $disksdir/rescue_root
#
package_map='       +00-dirtree         +glibc22            +glibc23
-gcc2               -gcc3               -gcc33              -gcc34
-gcc40              -gcc41              -gmp
-linux24-src        -linux26-src        -linux24benh-src
-linux24-source
-linux24-header     -linux26-header     -linux24benh-header
-linux24            -linux26            -linux24benh        +attr
-binutils           -bin86              -nasm               +dmapi
+grub               +lilo               +yaboot             +aboot
+silo               +parted             +mac-fdisk          +pdisk
+xfsprogs           +mkdosfs            +jfsutils           +xfsdump
+e2fsprogs          +reiserfsprogs      +genromfs           +lvm
+raidtools          +dump               +eject              +disktype
+hdparm             -memtest86          +openssl            +openssh
+mine               -termcap            +ncurses
+readline           -strace             -ltrace             -perl5
-m4                 -time               -gettext            +zlib
                    +attr               +acl                +findutils
+mktemp             +coreutils          -diffutils          -patch
-make               +grep               +sed                +gzip
+tar                +gawk               -flex               +bzip2
-texinfo            +less               -groff              -man
+nvi                -bison              +bc                 +cpio
+ed                 -autoconf                               -libtool
+curl               +wget               +dialog             +minicom
+lrzsz              +rsync              +tcpdump            +module-init-tools
-sysvinit           +shadow             +util-linux         +wireless-tools
+net-tools          +procps             +psmisc             -rockplug
+modutils           +pciutils           +portmap            +busybox
-sysklogd           -devfsd             +setserial          +iproute2
+netkit-base        +netkit-ftp         +netkit-telnet      +netkit-tftp
+sysfiles           +libpcap            +iptables           +tcp_wrappers
-kiss               +kbd                -syslinux           -rescue-stage1-init
+device-mapper      +lvm2               +mdadm              +dhcpcd
+smartmontools      +ntfsprogs          +lvm-wrapper        -man-pages
'

if [[ $rockver = 2.0* ]] ; then
	package_map="$package_map +bash -automake "
else
	package_map="$package_map +bash2 -bash3 -automake17 -automake18 +bize +ethtool "
fi

package_map="+$ROCKCFG_DEFAULT_KERNEL $package_map"

echo_status "Extracting the packages archives."
for x in $( ls $pkgsdir/*.tar.bz2 | \
	grep -v  -e ':dev.tar.bz2' -e ':doc.tar.bz2' )
do
	x="`basename $x .tar.bz2`"
	if echo "" $package_map "" | grep -q " +$x "
	then
		echo_status "\`- Extracting $x.tar.bz2 ..."
		tar --use-compress-program=bzip2 -xpf $pkgsdir/$x.tar.bz2
	elif ! echo "" $package_map "" | grep -q " -$x "
	then
		echo_error "\`- Not found in \$package_map: $x"
		echo_error "    ... fix target/$target/build.sh"
	fi
done
#
echo_status "Remove the stuff we don't need ..."
rm -rf home usr/{local,doc,man,info,games,share}
rm -rf var/adm/* var/games var/adm var/mail var/opt
rm -rf usr/{include,src} usr/*-linux-gnu {,usr/}lib/*.{a,la,o}
rm -rf etc/rc.d/rcX.d/
for x in usr/lib/*/; do rm -rf ${x%/}; done
#
echo_status "Installing some terminfo databases ..."
tar $taropt $pkgsdir/ncurses.tar.bz2	\
	usr/share/terminfo/x/xterm	usr/share/terminfo/a/ansi	\
	usr/share/terminfo/n/nxterm	usr/share/terminfo/l/linux	\
	usr/share/terminfo/v/vt200	usr/share/terminfo/v/vt220	\
	usr/share/terminfo/v/vt100	usr/share/terminfo/s/screen
#
echo_status "Installing some keymaps ..."
tar $taropt $pkgsdir/kbd.tar.bz2 \
	usr/share/kbd/keymaps/amiga \
	usr/share/kbd/keymaps/atari \
	usr/share/kbd/keymaps/i386/qwerty \
	usr/share/kbd/keymaps/i386/qwertz \
	usr/share/kbd/keymaps/i386/include \
	usr/share/kbd/keymaps/sun
find usr/share/kbd -name '*dvo*' -o -name '*az*' -o -name '*fgG*' | \
	xargs rm -f
#
#echo_status "Installing pci.ids ..."
#tar $taropt $pkgsdir/pciutils.tar.bz2 \
#	usr/share/pci.ids
#

echo_status "Installing lvm-cycle-script ..."
cp -v $base/target/$target/contrib/init-boot-cycle sbin/init-lvm-cycle
chmod 755 sbin/init-lvm-cycle

echo_status "Creating init."
cp -v $rootdir/usr/bin/busybox sbin/init
cp -al sbin/init sbin/halt
cp -al sbin/init sbin/reboot
rm -f etc/inittab etc/HOSTNAME
<<EOF cat > etc/inittab
::sysinit:/etc/init.d/rcS
vc/1::respawn:/sbin/agetty -f /etc/issue 38400 vc/1 linux
vc/2::respawn:/sbin/agetty -f /etc/issue 38400 vc/2 linux
vc/3::respawn:/sbin/agetty -f /etc/issue 38400 vc/3 linux
vc/4::respawn:/sbin/agetty -f /etc/issue 38400 vc/4 linux
vc/5::respawn:/sbin/agetty -f /etc/issue 38400 vc/5 linux
vc/6::respawn:/sbin/agetty -f /etc/issue 38400 vc/6 linux
EOF
<<EOF cat > etc/issue

\t \d  --  \U online  --  line [\l].

Welcome to \n (ROCK Linux advanced rescue system, Kernel \r).

EOF
chmod 644 etc/issue

<<EOF cat > etc/shadow
root::::::::
toor:*:::::::
bin:*:::::::
daemon:*:::::::
nobody:*:::::::
sshd:*:::::::
EOF
chmod 600 etc/shadow

mkdir -p etc/init.d/ etc/boot.d/
<<"EOF" cat > etc/init.d/rcS
#!/bin/sh
for x in /etc/boot.d/[0-9]*
do
	[ -f $x ] && . $x
done
EOF
<<EOF cat  > etc/boot.d/05-system
[ -f /proc/mounts ] || mount -t proc proc /proc
[ -d /mnt/boot ] || mkdir -p /mnt/boot
[ -d /dev/pts ] && mount /dev/pts
rm -f /dev/fd ; ln -s /proc/self/fd /dev/fd
grep -q '/mnt_boot' /proc/mounts && mount --move /old_root/mnt_boot /mnt/boot
grep -q '/old_root' /proc/mounts && umount -n /old_root
grep -v ^rootfs /proc/mounts > /etc/mtab
EOF
<<EOF cat  > etc/boot.d/10-hostname
if [ -f /etc/HOSTNAME ]
then
	/bin/hostname \`cat /etc/HOSTNAME\`
else
	/bin/hostname "$ROCKFG_RESCUE_DEFAULT_HOSTNAME"
fi
EOF
chmod 755 etc/init.d/rcS etc/boot.d/[0-9][0-9]-*
echo_status "Creating system.tar.bz2 archive."
tar --use-compress-program=bzip2 -cf ../system.tar.bz2 * ; cd ..

