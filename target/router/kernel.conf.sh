
echo "router target -> disabling some settings ..."

sed -e "s/CONFIG_VIDEO\(.*\)=./# CONFIG_VIDEO\1 is not set/" \
    -e "s/CONFIG_PHONE\(.*\)=./# CONFIG_PHONE\1 is not set/" \
    -e "s/CONFIG_RADIO\(.*\)=./# CONFIG_RADIO\1 is not set/" \
    -e "s/CONFIG_HAMRADIO\(.*\)=./# CONFIG_HAMRADIO\1 is not set/" \
    -e "s/CONFIG_SMP\(.*\)=./# CONFIG_SMP\1 is not set/" \
    -e "s/CONFIG_SOUND_\(.*\)=./# CONFIG_SOUND_\1 is not set/" \
    -e "s/CONFIG_PCI_NAMES\(.*\)=./# CONFIG_PCI_NAMES\1 is not set/" \
    -e "s/CONFIG_INPUT\(.*\)=./# CONFIG_INPUT\1 is not set/" \
    -e "s/CONFIG_GAMEPORT\(.*\)=./# CONFIG_GAMEPORT\1 is not set/" \
    -e "s/CONFIG_SCSI\(.*\)=./# CONFIG_SCSI\1 is not set/" \
    $1 > .config.router

mv .config.router $1

