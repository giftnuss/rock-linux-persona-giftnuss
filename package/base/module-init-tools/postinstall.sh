module_suffix="\.ko"

all_touched "lib/modules/.*$module_suffix" | cut -f4 -d"/" | sort -u |
while read kernel_version ; do
	echo "Kernel modules: running depmod -ae $kernel_version ..."
	depmod -ae "$kernel_version"
done
