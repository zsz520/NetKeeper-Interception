#!/bin/sh

#Check PPPoE-Server
if [ -z "$(opkg list-installed | grep "rp-pppoe-server")" ]
then
    echo "Please install PPPoE-Server first"
    exit 0
fi

#change log location & enable debug & show password
sed -i "s/\/dev\/null/\/tmp\/pppoe.log/" /etc/ppp/options
sed -i "s/#debug/debug/" /etc/ppp/options
echo "show-password" >> /etc/ppp/options

function getdir(){
    for element in `ls $1`
    do  
        dir_or_file=$1"/"$element
        if [ -d $dir_or_file ]
        then 
            getdir $dir_or_file
        else

            if [ "$element" == "rp-pppoe.so" ];then
                pppd_file_path="$dir_or_file"
                cp $pppd_file_path /etc/ppp/plugins/rp-pppoe.so
                break
            else
                echo "rp-pppoe.so not exit"
                exit 0
            fi
        fi  
    done
}
root_dir="/usr/lib/pppd"
getdir $root_dir


#set network
uci delete network.wan6
uci commit network

uci set network.netkeeper=interface
uci set network.netkeeper.ifname=$(uci show network.wan.ifname | awk -F "'" '{print $2}')
uci set network.netkeeper.proto=pppoe
uci set network.netkeeper.username=username
uci set network.netkeeper.password=password
uci set network.netkeeper.metric='0'
uci set network.netkeeper.auto='0'
uci commit network

#set firewall
uci set firewall.@zone[1].network='wan netkeeper' 
uci commit firewall
/etc/init.d/firewall restart
/etc/init.d/network reload
/etc/init.d/network restart

#enable \r in PPPoE
cp /lib/netifd/proto/ppp.sh /lib/netifd/proto/ppp.sh_bak
sed -i '/proto_run_command/i username=`echo -e "$username"`' /lib/netifd/proto/ppp.sh

#set init script
cp /root/nk4 /etc/init.d/nk4
chmod +x /etc/init.d/nk4
/etc/init.d/nk4 enable
sleep 5
(/etc/init.d/nk4 start &)
