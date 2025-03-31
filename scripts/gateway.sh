#!/usr/bin/bash

BRIDGE=br0
GWNSIP=172.16.118.1/24
GWIP=172.16.118.254

check_user() {
    echo "# Check user ..."
    grep clash /etc/passwd || useradd -M -s /sbin/nologin -G root --uid 1086 clash
    echo "# Check user done"
}

gw_exec() {
    ip netns exec gateway $@
}

create_ns() {
    echo "# Create gateway ..."
    ip netns add gateway
    ip netns exec gateway ip l set lo up
    ip l add bTg type veth peer name gTb
    ip l set bTg master $BRIDGE
    ip l set bTg up
    ip l set gTb netns gateway
    gw_exec ip a add $GWNSIP dev gTb
    gw_exec ip l set gTb up
    gw_exec ip r replace default via $GWIP
    echo "# Create gateway done"
}

destroy_ns() {
    echo "# Destroy gateway ..."
    ip netns del gateway
    ip l del bTg
    echo "# Destroy gateway done"
}

start_dns() {
    echo "# Start dns and dhcp ..."
    gw_exec /usr/sbin/dnsmasq -C /opt/gateway/dnsmasq.conf --test
    gw_exec /usr/sbin/dnsmasq -C /opt/gateway/dnsmasq.conf
    echo "# Start dns and dhcp done"
}

stop_dns() {
    echo "# Stop dns and dhcp ..."
    pid=`ps -ef |grep '/opt/gateway/dnsmasq.conf' | grep -v grep | awk '{ print $2 }'`
    kill $pid
    echo "# Stop dns and dhcp done"
}

start_tproxy() {
    echo "# Start tproxy ..."
    gw_exec bash /opt/gateway/tproxy.sh start
    echo "# Start tproxy done"
}

stop_tproxy() {
    echo "# Stop tproxy ..."
    gw_exec bash /opt/gateway/tproxy.sh stop
    echo "# Stop tproxy done"
}

start() {
    check_user
    create_ns
    start_dns
    start_tproxy
}

destroy() {
    stop_tproxy
    stop_dns
    destroy_ns
}

restart() {
    destroy
    start
}

main() {
    if [ $# -eq 0 ]; then
        echo "usage: $0 start|stop ..."
        return 1
    fi

    for funcname in "$@"; do
        if [ "$(type -t $funcname)" != 'function' ]; then
            echo "'$funcname' not a shell function"
            return 1
        fi
    done

    for funcname in "$@"; do
        $funcname
    done
    return 0
}

main "$@"
