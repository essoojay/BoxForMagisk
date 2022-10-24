#!/system/bin/sh

scripts=`realpath $0`
scripts_dir=`dirname ${scripts}`
. /data/box/settings.ini

monitor_local_ipv4() {
    change=false

    wifistatus=$(dumpsys connectivity | grep "WIFI" | grep "state:" | /data/adb/magisk/busybox awk -F ", " '{print $2}' | /data/adb/magisk/busybox awk -F "=" '{print $2}' 2>&1)

    if [ ! -z "${wifistatus}" ]
    then
    echo "" >${box_run_path}/lastmobile
        if test ! "${wifistatus}" = "$(cat ${box_run_path}/lastwifi)"
        then
            change=true
            echo "${wifistatus}" >${box_run_path}/lastwifi
        elif [ "$(ip route get 1.2.3.4 | awk '{print $5}' 2>&1)" != "wlan0" ]
        then
            change=true
            echo "${wifistatus}" >${box_run_path}/lastwifi
        fi
    else
        echo "" >${box_run_path}/lastwifi
    fi

    if [ "$(settings get global mobile_data 2>&1)" -eq 1 ] && [ -z "${wifistatus}" ]
    then
        echo "" >${box_run_path}/lastwifi
        card1="$(settings get global mobile_data1 2>&1)"
        card2="$(settings get global mobile_data2 2>&1)"
        if [ "${card1}" = 1 ]
        then
            mobilestatus=1
        fi
        if [ "${card2}" = 1 ]
        then
            mobilestatus=2
        fi

        if [ ! "${mobilestatus}" = "$(cat ${box_run_path}/lastmobile)" ]
        then
            change=true
            echo "${mobilestatus}" >${box_run_path}/lastmobile
        fi
    else
        echo "" >${box_run_path}/lastmobile
    fi

    if [ "${change}" == true ]
    then
        local_ipv4=$(ip a | /data/adb/magisk/busybox awk '$1~/inet$/{print $2}')
        local_ipv6=$(ip -6 a | /data/adb/magisk/busybox awk '$1~/inet6$/{print $2}' | grep '^2')
        rules_ipv4=$(${iptables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $9}' 2>&1)
        rules_ipv6=$(${ip6tables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $8}' 2>&1)

        for rules_subnet in ${rules_ipv4[*]}; do
            ${iptables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet} -j ACCEPT
        done

        for subnet in ${local_ipv4[*]}; do
        	${iptables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet} -j ACCEPT
        done

        for rules_subnet6 in ${rules_ipv6[*]}; do
            ${ip6tables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet6} -j ACCEPT
        done

        for subnet6 in ${local_ipv6[*]}; do
            ${ip6tables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT
        done
    else
        exit 0
    fi

    unset local_ipv4
    unset rules_ipv4
    unset local_ipv6
    unset rules_ipv6
    unset wifistatus
    unset mobilestatus
    unset change
}

find_uid() {
        echo -n "" > ${appuid_file} 
        for package in `cat ${filter_packages_file} | sort -u` ; do
            ${busybox_path} awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
            if [ "${mode}" = "blacklist" ]
            then
                echo $date_log"info: ${package} di filter " >> ${box_logs_file}
            else
                echo $date_log"warn: $box_bin_name doesn't support whitelist" >> ${box_logs_file}
            fi
        done
}

find_packages_uid() {
    if [ "${box_enhanced_mode}" == "redir-host" ]
    then
        echo -n "" > ${appuid_file} 
        for package in `cat ${filter_packages_file} | sort -u` ; do
            ${busybox_path} awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file} >> ${appuid_file}
            if [ "${mode}" = "blacklist" ]
            then
                echo $date_log"info: ${package} di filter " >> ${box_logs_file}
            elif [ "${mode}" = "whitelist" ]
            then
                echo $date_log"info: ${package} diproksi." >> ${box_logs_file}
            fi
        done
    else
        echo $date_log"info: enhanced-mode: $box_enhanced_mode " >> ${box_logs_file}
    fi
}

restart_clash() {
    ${scripts_dir}/box.service -k && ${scripts_dir}/box.iptables -k
    echo -n "disable" > ${box_run_path}/root
    sleep 0.5
    ${scripts_dir}/box.service -s && ${scripts_dir}/box.iptables -s
    if [ "$?" == "0" ]
    then
        echo -n $date_log"info: `date` , " >>${box_logs_file}
        echo "Clash restart" >>${box_logs_file}
    else
        echo $date_log"err: Clash Failed to restart." >>${box_logs_file}
    fi
}

update_file() {
        file="$1"
        file_bak="${file}.bak"
        update_url="$2"
        if [ -f ${file} ]
        then
            mv -f ${file} ${file_bak}
        fi
        echo "curl -k --insecure -L -A 'clash' ${update_url} -o ${file}"
        curl -k --insecure -L -A 'clash' ${update_url} -o ${file} 2>&1
        sleep 0.5
        if [ -f "${file}" ]
        then
            echo ""
        else
            if [ -f "${file_bak}" ]
            then
                mv ${file_bak} ${file}
            fi
        fi
}

auto_update() {
    if [ "${auto_updateGeoX}" == "true" ]
    then
       update_file ${box_GeoIP_file} ${GeoIP_dat_url}
       if [ "$?" = "0" ]
       then
          flag=false
       fi
    fi

    if [ "${auto_updateGeoX}" == "true" ]
    then
       update_file ${box_GeoSite_file} ${GeoSite_url}
       if [ "$?" = "0" ]
       then
          flag=false
       fi
    fi

    if [ ${auto_updateSubcript} == "true" ]
    then
       update_file ${box_config_file} ${Subcript_url}
       if [ "$?" = "0" ]
       then
          flag=true
       fi
    fi

    if [ -f "${box_pid_file}" ] && [ ${flag} == true ]
    then
        restart_clash
    fi
}

config_online() {
    box_pid=`cat ${box_pid_file}`
    match_count=0

    echo $date_log"warn: Download Config online" > ${box_logs_file}
    update_file ${box_config_file} ${Subcript_url} >> ${box_logs_file}

    sleep 0.5

    if [ -f "${box_config_file}" ]
    then
        match_count=$((${match_count} + 1))
    fi

    if [ ${match_count} -ge 1 ]
    then
        echo $date_log"info: download succes." >> ${box_logs_file}
        exit 0
    else
        echo $date_log"err: download failed, Make sure the Url is not empty" >> ${box_logs_file}
        exit 1
    fi
}

port_detection() {
    box_pid=`cat ${box_pid_file}`
    match_count=0
    
    if (ss -h > /dev/null 2>&1)
    then
        box_port=$(ss -antup | grep "$box_bin_name" | ${busybox_path} awk '$7~/'pid="${box_pid}"*'/{print $5}' | ${busybox_path} awk -F ':' '{print $2}' | sort -u)
    else
        echo $date_log"info: skip port detected" >> ${box_logs_file}
        exit 0
    fi

    echo -n $date_log"info: port detected: " >> ${box_logs_file}
    for sub_port in ${box_port[*]} ; do
        sleep 0.5
        echo -n "${sub_port} " >> ${box_logs_file}
    done
        echo "" >> ${box_logs_file} 
}

update_kernel() {
    rm -rf $box_data_dir/box.Meta
    if [ "${use_premium}" == "false" ]
    then
        if [ "${meta_alpha}" == "false" ]
        then
            tag_meta=$(curl -fsSL ${url_meta} | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | head -1)
            filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
            update_file ${box_data_dir}/${file_kernel}.gz ${url_meta}/download/${tag_meta}/${filename}.gz
                if [ "$?" = "0" ]
                then
                    flag=false
                fi
        else
            tag_meta=$(curl -fsSL ${url_meta}/expanded_assets/${tag} | grep -oE "${tag_name}" | head -1)
            filename="${file_kernel}-${platform}-${arch}-${tag_meta}"
            update_file ${box_data_dir}/${file_kernel}.gz ${url_meta}/download/${tag}/${filename}.gz
                if [ "$?" = "0" ]
                then
                    flag=false
                fi
        fi
    else
        filename=$(curl -fsSL ${url_premium}/expanded_assets/premium | grep -oE "clash-${platform}-${arch}-[0-9]+.[0-9]+.[0-9]+" | head -1)
        update_file ${box_data_dir}/"${file_kernel}".gz ${url_premium}/download/premium/${filename}.gz
        if [ "$?" = "0" ]
        then
            flag=false
        fi
    fi

    if [ ${flag} == false ]
    then
        if (gunzip --help > /dev/null 2>&1)
        then
           if [ -f ${box_data_dir}/"${file_kernel}".gz ]
           then
                if (gunzip ${box_data_dir}/"${file_kernel}".gz)
                then
                    echo ""
                else
                    echo $date_log"err: gunzip ${file_kernel}.gz failed"  > ${box_logs_file}
                    echo $date_log"warn: periksa kembali url" >> ${box_logs_file}
                    if [ -f ${box_data_dir}/"${file_kernel}".gz.bak ]
                    then
                        rm -rf ${box_data_dir}/"${file_kernel}".gz.bak
                    else
                        rm -rf ${box_data_dir}/"${file_kernel}".gz
                    fi
                    if [ -f ${box_run_path}/${box_bin_name}.pid ]
                    then
                        echo $date_log"info: Clash service is running (PID: `cat ${box_pid_file}`)" >> ${box_logs_file}
                        echo $date_log"info: Connect" >> ${box_logs_file}
                    fi
                    exit 1
                fi
           else
                echo $date_log"warn: gunzip ${file_kernel}.gz failed"  >> ${box_logs_file}
                echo $date_log"warn: pastikan ada koneksi internet"  >> ${box_logs_file}
                exit 1
            fi
        else
            echo $date_log"err: gunzip not found"  >> ${box_logs_file}
            exit 1
        fi
    fi

    mv -f ${box_data_dir}/"${file_kernel}" ${box_data_dir}/kernel/lib

    if [ "$?" = "0" ]
    then
        flag=true
    fi

    if [ -f "${box_pid_file}" ] && [ ${flag} == true ]
    then
        restart_clash
    else
       echo $date_log"warn: Clash tidak dimulai ulang" >> ${box_logs_file}
    fi
}

cgroup_limit() {
    if [ "${Cgroup_memory_limit}" == "" ]
    then
        return
    fi
    if [ "${Cgroup_memory_path}" == "" ]
    then
        Cgroup_memory_path=$(mount | grep cgroup | ${busybox_path} awk '/memory/{print $3}' | head -1)
    fi
    mkdir -p "${Cgroup_memory_path}/${box_bin_name}"
    echo $(cat ${box_pid_file}) > "${Cgroup_memory_path}/${box_bin_name}/cgroup.procs" \
    && echo $date_log"info: ${Cgroup_memory_path}/${box_bin_name}/cgroup.procs" >> ${box_logs_file}
    echo "${Cgroup_memory_limit}" > "${Cgroup_memory_path}/${box_bin_name}/memory.limit_in_bytes" \
    && echo $date_log"info: ${Cgroup_memory_path}/${box_bin_name}/memory.limit_in_bytes" >> ${box_logs_file}
}

up_dashboard() {
    url_dashboard="https://github.com/taamarin/yacd/archive/refs/heads/gh-pages.zip"
    file_dasboard="${box_data_dir}/dashboard.zip"
    rm -rf ${box_data_dir}/dashboard/dist

    curl -L -A 'clash' ${url_dashboard} -o ${file_dasboard} 2>&1
    unzip -o  "${file_dasboard}" "yacd-gh-pages/*" -d ${box_data_dir}/dashboard >&2
    mv -f ${box_data_dir}/dashboard/yacd-gh-pages ${box_data_dir}/dashboard/dist 
    rm -rf ${file_dasboard}
}

dnstt_client() {
    if [ "${run_dnstt}" == "1" ]
    then
        cp $box_lib/dnstt-client $box_bin
        if [ -f $dnstt_client_bin ]
        then
            chmod 0755 $dnstt_client_bin
            chown root:net_admin ${dnstt_client_bin}
            if [ ! ${nsdomain} == "" ] && [ ! ${pubkey} == "" ]
            then
               nohup ${busybox_path} setuidgid 0:3005 $dnstt_client_bin -udp ${dns_for_dnstt}:53 -pubkey ${pubkey} ${nsdomain} 127.0.0.1:${port_dnstt} > /dev/null 2>&1 &
               echo -n $! > ${box_run_path}/dnstt.pid

               sleep 1
               local dnstt_pid=`cat ${box_run_path}/dnstt.pid 2> /dev/null`
               if (cat /proc/"$dnstt_pid"/cmdline | grep -q $dnstt_bin_name)
               then
                  echo ${date_log}"info: $dnstt_bin_name is enable." >> ${box_logs_file}
               else
                  echo ${date_log}"err: $dnstt_bin_name The configuration is incorrect," >> ${box_logs_file}
                  echo ${date_log}"err: the startup fails, and the following is the error" >> ${box_logs_file}
                  kill -9 `cat ${box_run_path}/dnstt.pid`
               fi
            else
                echo ${date_log}"warn: $dnstt_bin_name tidak aktif,"  >> ${box_logs_file}
                echo ${date_log}"warn: 'nsdomain' & 'pubkey' kosong,"  >> ${box_logs_file}
            fi
        else
            echo ${date_log}"err: kernel $dnstt_bin_name tidak ada." >> ${box_logs_file}
        fi
    else
        echo $date_log"info: $dnstt_bin_name is disabled" >> ${box_logs_file}
    fi
}

while getopts ":fmspokldvg" signal ; do
    case ${signal} in
        f)
            if [ "${Calsh_bin_name}" = "clash" ]
            then
                find_packages_uid
            else
                find_uid
            fi
            ;;
        m)
            if [ "${mode}" = "blacklist" ] && [ -f "${box_pid_file}" ]
            then
                monitor_local_ipv4
            else
                exit 0
            fi
            ;;
        s)
            auto_update
            rm -rf ${box_data_dir}/*dat.bak
            exit 1
            ;;
        p)
            port_detection
            ;;
        l)
            cgroup_limit
            ;;
        k)
            update_kernel
            ;;
        d)
            up_dashboard
            ;;
        v)
            dnstt_client
            ;;
        o)
            config_online
            ;;
        ?)
            echo ""
            ;;
    esac
done