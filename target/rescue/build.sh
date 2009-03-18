
if [[ $rockver = 2.0* ]] ; then
	disksdir="$build_dir/rescue"
	pkgsdir="$build_dir/pkgs"
	rootdir="$build_dir/root"
else
	disksdir="$build_rock/rescue"
	pkgsdir="$build_rock/pkgs"
	rootdir="$build_rock/.."
fi

if [ "$ROCK_DEBUG_RESCUE_NOSTAGE2" != 1 -a \
     "$ROCK_DEBUG_RESCUE_NOSTAGE1" != 1 ]
then
	pkgloop
	rm -rf $disksdir
	mkdir -p $disksdir
	chmod 700 $disksdir
fi

# Re-evaluate CC and other variables (as we have built the cross cc now)
. scripts/parse-config

if [ "$ROCK_DEBUG_RESCUE_NOSTAGE2" != 1 ]
then
	. $base/target/$target/build_stage2.sh
fi

if [ "$ROCK_DEBUG_RESCUE_NOSTAGE1" != 1 ]
then
	. $base/target/$target/build_stage1.sh
fi

if [ -f $base/target/$target/$arch/build.sh ]; then
	. $base/target/$target/$arch/build.sh
fi


echo_header "Creating ISO filesystem description."
cd $disksdir
rm -rf isofs
mkdir -p isofs

echo_status "Creating rescue/isofs directory.."
ln system.tar.bz2 isofs/
ln *.img isofs/ 2>/dev/null || true # might not exist on some architectures

echo_status "Creating isofs.txt file .."
echo "DISK1	build/${ROCKCFG_ID}/rescue/isofs/ `
	`${ROCKCFG_SHORTID}/" > ../isofs_generic.txt
cat ../isofs_*.txt > ../isofs.txt

