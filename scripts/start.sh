#!/system/bin/sh

moddir="/data/adb/modules/BoxForMagisk"
if [ -n "$(magisk -v | grep lite)" ]
then
  moddir=/data/adb/lite_modules/BoxForMagisk
fi

scripts_dir="/data/box/scripts"
busybox_path="/data/adb/magisk/busybox"
box_run_path="/data/box/run"
box_pid_file="${box_run_path}/*.pid"

start_box() {
    if [ -f ${box_pid_file} ]
    then
        ${scripts_dir}/box.service -k && ${scripts_dir}/box.iptables -k
    fi
}

start_service() {
    if [ ! -f /data/box/manual ]
    then
        echo -n "" > /data/box/run/service.log
        if [ ! -f ${moddir}/disable ]
        then
            ${scripts_dir}/box.service -s
            if [ -f /data/box/run/*.pid ]
                then
                ${scripts_dir}/box.iptables -s
            fi
        fi

        if [ "$?" = 0 ]
        then
           ulimit -SHn 1000000
           inotifyd ${scripts_dir}/box.inotify ${moddir} &>> /dev/null &
        fi
    fi
}

start_box
start_service