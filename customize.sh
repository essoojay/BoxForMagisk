SKIPUNZIP=1
ASH_STANDALONE=1

status=""
architecture=""
uid="0"
gid="3005"
box_data_dir="/data/box"
modules_dir="/data/adb/modules"
bin_path="/system/bin/"
dns_path="/system/etc"
box_adb_dir="/data/adb"
box_service_dir="/data/adb/service.d"
busybox_data_dir="/data/adb/magisk/busybox"
ca_path="${dns_path}/security/cacerts"
box_data_dir_kernel="${box_data_dir}/kernel"
box_data_sc="${box_data_dir}/scripts"
mod_config="${box_data_sc}/settings.ini"
yacd_dir="${box_data_dir}/dashboard"
latest=$(date +%Y%m%d%H%M)

if [ $BOOTMODE ! = true ] ; then
	ui_print "- Installing through TWRP Not supported"
	ui_print "- Intsall this module via Magisk Manager"
	abort "- ! Aborting installation !"
fi

ui_print "- Installing Clash for Magisk"

if [ -d "${box_data_dir}" ] ; then
    ui_print "- backup clash"
    rm -rf ${box_data_dir}/${latest}
    mkdir -p ${box_data_dir}/${latest}
    mv ${box_data_dir}/* ${box_data_dir}/${latest}/
fi

ui_print "- create folder box."
mkdir -p ${box_data_dir}
mkdir -p ${box_data_dir_kernel}
mkdir -p ${MODPATH}${ca_path}
mkdir -p ${box_data_dir}/dashboard
mkdir -p ${MODPATH}/system/bin
mkdir -p ${box_data_dir}/run
mkdir -p ${box_data_dir}/scripts
mkdir -p ${box_data_dir}/xray/confs
mkdir -p ${box_data_dir}/v2fly/confs
mkdir -p ${box_data_dir}/sing-box
mkdir -p ${box_data_dir}/clash

case "${ARCH}" in
    arm)
        architecture="armv7"
        ;;
    arm64)
        architecture="armv8"
        ;;
    x86)
        architecture="386"
        ;;
    x64)
        architecture="amd64"
        ;;
esac

unzip -o "${ZIPFILE}" -x 'META-INF/*' -d $MODPATH >&2

ui_print "- extract dashboard"
unzip -o ${MODPATH}/dashboard.zip -d ${box_data_dir}/dashboard/ >&2

ui_print "- move scripts clash"
mv ${MODPATH}/scripts/* ${box_data_dir}/scripts/
mv ${box_data_dir}/scripts/template ${box_data_dir}/

ui_print "- move cert&geo"
mv ${box_data_dir}/scripts/cacert.pem ${MODPATH}${ca_path}
mv ${MODPATH}/GeoX/* ${box_data_dir}/clash/
cp ${box_data_dir}/clash/GeoIP.dat ${box_data_dir}/xray/geoip.dat
cp ${box_data_dir}/clash/GeoSite.dat ${box_data_dir}/xray/geosite.dat
cp ${box_data_dir}/clash/GeoIP.dat ${box_data_dir}/v2fly/geoip.dat
cp ${box_data_dir}/clash/GeoSite.dat ${box_data_dir}/v2fly/geosite.dat

if [ ! -d /data/adb/service.d ] ; then
    ui_print "- make folder service"
    mkdir -p /data/adb/service.d
fi

#ui_print "- Create resolv.conf"
#if [ ! -f "${dns_path}/resolv.conf" ] ; then
#    touch ${MODPATH}${dns_path}/resolv.conf
#    echo nameserver 8.8.8.8 > ${MODPATH}${dns_path}/resolv.conf
#    echo nameserver 1.1.1.1 >> ${MODPATH}${dns_path}/resolv.conf
#    echo nameserver 9.9.9.9 >> ${MODPATH}${dns_path}/resolv.conf
#    echo nameserver 149.112.112.112 >> ${MODPATH}${dns_path}/resolv.conf
#fi

ui_print "- make packages.list"
if [ ! -f "${box_data_dir}/scripts/packages.list" ] ; then
    touch ${box_data_dir}/packages.list
fi
# temporary fix for Redmi K50, need a generic fix for devices imcompatible with the entry "wlan+" here and instead replace with "ap+"
# $echo "" > /data/box/ignore_out.list
# [ "$(getprop ro.product.device)" = "rubens" ] && echo "ap+" > /data/adb/box/ap.list || echo "wlan+" > /data/box/ap.list

unzip -j -o "${ZIPFILE}" 'service.sh' -d ${MODPATH} >&2
unzip -j -o "${ZIPFILE}" 'uninstall.sh' -d ${MODPATH} >&2
unzip -j -o "${ZIPFILE}" 'box_service.sh' -d ${box_service_dir} >&2

ui_print "- extract binary-$ARCH "
tar -xjf ${MODPATH}/binary/${ARCH}.tar.bz2 -C ${box_data_dir_kernel}/&& echo "- extar kernel Succes" || echo "- extar kernel gagal"
mv ${box_data_dir_kernel}/setcap ${MODPATH}${bin_path}/
mv ${box_data_dir_kernel}/getpcaps ${MODPATH}${bin_path}/
mv ${box_data_dir_kernel}/getcap ${MODPATH}${bin_path}/
mv ${box_data_dir}/scripts/settings.ini ${box_data_dir}/
mv ${box_data_dir}/scripts/xray/confs ${box_data_dir}/xray/
mv ${box_data_dir}/scripts/v2fly/confs ${box_data_dir}/v2fly/
mv ${box_data_dir}/scripts/sing-box ${box_data_dir}/
mv ${box_data_dir}/scripts/clash/* ${box_data_dir}/clash/

if [ ! -f "${bin_path}/ss" ] ; then
    mv ${box_data_dir_kernel}/ss ${MODPATH}${bin_path}/
else
    rm -rf ${box_data_dir_kernel}/ss
fi

rm -rf ${box_data_dir}/scripts/xray
rm -rf ${box_data_dir}/scripts/v2fly
rm -rf ${MODPATH}/dashboard.zip
rm -rf ${MODPATH}/scripts
rm -rf ${MODPATH}/GeoX
rm -rf ${MODPATH}/binary
rm -rf ${MODPATH}/box_service.sh
rm -rf ${box_data_dir}/scripts/config.yaml
rm -rf ${box_data_dir}/scripts/clash
rm -rf ${box_data_dir_kernel}/curl

sleep 1

if [ -d ${box_data_dir}/${latest}/clash ]
then
    ui_print "- restore clash"
    mv ${box_data_dir}/${latest}/clash/* ${box_data_dir}/clash/
fi

if [ -d ${box_data_dir}/${latest}/sing-box ]
then
    ui_print "- restore sing-box"
    mv ${box_data_dir}/${latest}/sing-box/* ${box_data_dir}/sing-box/
fi

if [ -d ${box_data_dir}/${latest}/xray ]
then
    ui_print "- restore xray"
    mv ${box_data_dir}/${latest}/xray/confs/* ${box_data_dir}/xray/confs/
fi

if [ -d ${box_data_dir}/${latest}/v2fly ]
then
    ui_print "- restore v2fly"
    mv ${box_data_dir}/${latest}/v2fly/confs/* ${box_data_dir}/v2fly/confs/
fi

ui_print "- Set Permissons"
set_perm_recursive ${MODPATH} 0 0 0755 0644
set_perm_recursive ${box_data_dir} ${uid} ${gid} 0755 0644
set_perm_recursive ${box_data_dir}/scripts ${uid} ${gid} 0755 0755
set_perm_recursive ${box_data_dir}/kernel ${uid} ${gid} 0755 0755
set_perm_recursive ${box_data_dir}/dashboard ${uid} ${gid} 0755 0644
set_perm  ${MODPATH}/service.sh  0  0  0755
set_perm  ${MODPATH}/uninstall.sh  0  0  0755
set_perm  ${MODPATH}${ca_path}/cacert.pem 0 0 0644
set_perm  ${MODPATH}${dns_path}/resolv.conf 0 0 0755
set_perm  ${box_service_dir}/box_service.sh  0  0  0755
chmod ugo+x ${MODPATH}/system/bin/*
chmod ugo+x ${box_data_dir}/*
chmod ugo+x ${box_data_dir}/scripts/*
chmod ugo+x ${box_data_dir}/kernel/lib/*
ui_print "- Installation is complete, reboot your device"
