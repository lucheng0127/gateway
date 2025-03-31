#!/usr/bin/bash
set -ex

# create nologin user first
# useradd -M -s /sbin/nologin -G root --uid 1086 clash

create_noproxy_set() {
    # create set to match noproxy nets
    ipset create noproxy hash:net

    ipset add noproxy 0.0.0.0/8
    ipset add noproxy 10.0.0.0/8
    ipset add noproxy 127.0.0.0/8
    ipset add noproxy 172.16.0.0/12
    ipset add noproxy 169.254.0.0/16
    ipset add noproxy 192.168.0.0/16
    ipset add noproxy 224.0.0.0/4
    ipset add noproxy 240.0.0.0/4
}

teardown_noproxy_set() {
    ipset destroy noproxy
}

create_policy_route() {
    ip rule add fwmark 0x162 lookup 0x162
    ip r replace local 0.0.0.0/0 dev lo table 0x162
}

teardown_policy_route() {
    ip rule del fwmark 0x162 lookup 0x162
}

create_iptables() {
    iptables -t mangle -N clash

    iptables -t mangle -A clash -m set --match-set noproxy dst -j RETURN
    iptables -t mangle -A clash -p tcp -j TPROXY --on-port 7891 --tproxy-mark 0x162
    iptables -t mangle -A clash -p udp -j TPROXY --on-port 7891 --tproxy-mark 0x162
    iptables -t mangle -A PREROUTING -j clash

    iptables -t mangle -N clash_local
    iptables -t mangle -A clash_local -m set --match-set noproxy dst -j RETURN
    iptables -t mangle -A clash_local -p tcp -j MARK --set-mark 0x162
    iptables -t mangle -A clash_local -p udp -j MARK --set-mark 0x162
    iptables -t mangle -A OUTPUT -p tcp -m owner --uid-owner clash -j RETURN
    iptables -t mangle -A OUTPUT -p udp -m owner --uid-owner clash -j RETURN
    iptables -t mangle -A OUTPUT -j clash_local

    # Redirect dns lookup
    iptables -t nat -N clash_dns_external
    iptables -t nat -A clash_dns_external -p udp -m udp --dport 53 -j REDIRECT --to-ports 5353

    iptables -t nat -N clash_dns_local
    iptables -t nat -A clash_dns_local -p udp -m udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -t nat -A clash_dns_local -m owner --uid-owner clash -j RETURN

    iptables -t nat -A PREROUTING -p udp -j clash_dns_external
    iptables -t nat -A OUTPUT -p udp -j clash_dns_local
}

teardown_iptables() {
    iptables -t mangle -D OUTPUT -p tcp -m owner --uid-owner clash -j RETURN
    iptables -t mangle -D OUTPUT -p udp -m owner --uid-owner clash -j RETURN
    iptables -t mangle -D PREROUTING -j clash
    iptables -t mangle -D OUTPUT -j clash_local
    iptables -t mangle -F clash
    iptables -t mangle -F clash_local
    iptables -t mangle -X clash
    iptables -t mangle -X clash_local

    iptables -t nat -F clash_dns_external 
    iptables -t nat -F clash_dns_local
    iptables -t nat -X clash_dns_external
    iptables -t nat -X clash_dns_local
}

start_tproxy() {
    create_noproxy_set
    create_policy_route
    create_iptables
}

stop_tproxy() {
    teardown_iptables
    teardown_policy_route
    teardown_noproxy_set
}

start_clash() {
  setcap 'cap_net_admin,cap_net_bind_service=+ep' /usr/local/bin/mihomo
  su - clash -c "/usr/local/bin/mihomo -d /opt/mihomo/ > /tmp/clash.log 2>&1"
}

stop_clash() {
    killall mihomo
}

start() {
    start_tproxy
    start_clash
}

stop() {
    stop_tproxy
    stop_clash
}

restart() {
    stop
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