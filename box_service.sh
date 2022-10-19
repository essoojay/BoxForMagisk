#!/system/bin/sh

(
until [ $(getprop init.svc.bootanim) = "stopped" ] ; do
    sleep 5
done

chmod 755 /data/box/scripts/start.sh
/data/box/scripts/start.sh
)&