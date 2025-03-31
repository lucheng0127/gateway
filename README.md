# 网关配置

通过linux netns创建网关，并通过dnsmasq提供dns和dhcp服务。通过clash透明代理全局流量。

## How to
将dnsmasq和scripts中的脚本移至/opt/gateway目录，正确配置clash后启动gateway服务。
```
systemctl enable --now gateway
```
启动后本地创建gateway netns，里面跑clash和dnsmasq并配置透明代理iptables规则。