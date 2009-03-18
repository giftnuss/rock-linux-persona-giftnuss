
cd $disksdir

echo "Cleaning boot directory:"
find boot/ -name "*.b" ! -name "second.b" -exec rm -f {} +
#
echo "Creating silo config file."
cp -v $confdir/sparc/{silo.conf,boot.msg,help1.txt} boot/
#
cat > $root/ROCK/isofs_arch.txt <<- EOT
	BOOT	-G build/${ROCKCFG_ID}/boot/isofs.b -B ...
EOT
