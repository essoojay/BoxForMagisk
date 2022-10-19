#!/system/bin/sh

usage_name=sing-box

getmemory(){
  box_pid=$(cat /data/box/run/${usage_name}.pid)
  box_alive=$(grep VmRSS /proc/${box_pid}/status | /data/adb/magisk/busybox awk -F':' '{print $2}' | /data/adb/magisk/busybox awk '{print $1}')
  if [ ${box_alive} -ge 1024 ]
  then
    box_res="$(expr ${box_alive} / 1024)mb"
  else
    box_res="${box_alive}kb"
  fi

  box_cpu=$(ps -p ${box_pid} -o pcpu | grep -v %CPU | awk '{print $1}' )%
  log_usage="CPU: ${box_cpu} RES: ${box_res}" 
  sed -i "s/CPU:.*/${log_usage}/" /data/box/run/run.logs
}

usage() {
    interval="1"
    while [ -f /data/box/run/${usage_name}.pid ]
    do
        getmemory &> /dev/null
        [ ! -f /data/box/run/${usage_name}.pid ] && break
        now=$(date +%s)
        sleep $(( $interval - $now % $interval ))
    done
}

usage
