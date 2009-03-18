
# This is the shortest possible target build.sh script. Some targets will
# add code after calling pkgloop() or modify pkgloop's behavior by defining
# a new pkgloop_action() function.
#
pkgloop

echo_header "Finishing build."

echo_status "Selecting bin packages ..."
rm -rf build/${ROCKCFG_ID}/ROCK/pkgs_sel
mkdir -p build/${ROCKCFG_ID}/ROCK/pkgs_sel
(cd build/${ROCKCFG_ID}/ROCK/pkgs/;
	ls | xargs ln --target-directory="../pkgs_sel";)

if [ "$ROCKCFG_TARGET_CRYSTAL_INCLUDEDOCS" != 1 ]; then
	# :doc packages are nice but in most cases never used
	(
		cd build/${ROCKCFG_ID}/ROCK/pkgs_sel/
		rm -f *:doc{-*,}.gem
	)
fi

# remove packages which haven't been built in stages 0-8
if [ "$ROCKCFG_TARGET_CRYSTAL_BUILDADDONS" = 1 ]; then
	for gemfile in build/${ROCKCFG_ID}/ROCK/pkgs_sel/*.gem; do
		if ! mine -k packages $gemfile | grep -q '^Build \[[0-8]\] at '; then
			rm -f $gemfile
		fi
	done
fi

echo_status "Selecting info files ..."
rm -rf build/${ROCKCFG_ID}/ROCK/info_sel
mkdir -p build/${ROCKCFG_ID}/ROCK/info_sel
cp -rl build/${ROCKCFG_ID}/var/adm/`
	`{cksums,dependencies,descs,flists,md5sums,packages,provides,requires,conflicts} \
	build/${ROCKCFG_ID}/ROCK/info_sel/.

grep -hr '^Package Name and Version:' \
	build/${ROCKCFG_ID}/ROCK/info_sel/packages |
awk '{ print $5 " " $6 "-" $7; }' |
while read p v; do
	if [ ! -f build/${ROCKCFG_ID}/ROCK/pkgs_sel/$p-$v.gem ]; then
		echo build/${ROCKCFG_ID}/ROCK/info_sel/*/$p
	fi
done | xargs -r rm

echo_status "Creating package database (everything) ..."
admdir="build/${ROCKCFG_ID}/var/adm"
create_package_db $admdir build/${ROCKCFG_ID}/ROCK/pkgs

echo_status "Creating package database (install media) ..."
admdir="build/${ROCKCFG_ID}/ROCK/info_sel"
create_package_db $admdir build/${ROCKCFG_ID}/ROCK/pkgs_sel

echo_status "Creating isofs.txt file .."
cat << EOT > build/${ROCKCFG_ID}/ROCK/isofs_crystal-pkgsel.txt
DISK1	$admdir/cksums/					${ROCKCFG_SHORTID}/info/cksums/
DISK1	$admdir/dependencies/				${ROCKCFG_SHORTID}/info/dependencies/
DISK1	$admdir/descs/					${ROCKCFG_SHORTID}/info/descs/
DISK1	$admdir/flists/					${ROCKCFG_SHORTID}/info/flists/
DISK1	$admdir/md5sums/				${ROCKCFG_SHORTID}/info/md5sums/
DISK1	$admdir/packages/				${ROCKCFG_SHORTID}/info/packages/
DISK1	$admdir/provides/				${ROCKCFG_SHORTID}/info/provides/
DISK1	$admdir/requires/				${ROCKCFG_SHORTID}/info/requires/
DISK1	$admdir/conflicts/				${ROCKCFG_SHORTID}/info/conflicts/
EVERY	build/${ROCKCFG_ID}/ROCK/pkgs_sel/packages.db	${ROCKCFG_SHORTID}/pkgs/packages.db
SPLIT	build/${ROCKCFG_ID}/ROCK/pkgs_sel/		${ROCKCFG_SHORTID}/pkgs/
EOT

cat build/${ROCKCFG_ID}/ROCK/isofs_*.txt > build/${ROCKCFG_ID}/ROCK/isofs.txt
