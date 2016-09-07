# firewall-stutz
IPTables based firewall with various capabilities: NAT in/out, QoS, routing, multi-wan, common attack protection

If you are willing to use IPTable for firewalling, this project is a good start point. I've been using this setup for almost a decade among some clients. 

Now I recomend using PF (Packet Filter) from OpenBSD for common firewall/router boxes, but multi-wan and QoS works beatifully on the scripts from this repo.

# Initial setup
## Copy "etc/firewall-stutz" folder to your Linux distribution over "/etc/firewall-stutz"
## run "ln -s /etc/firewall-stutz/test-default-gateways /etc/cron.d/test-default-gateways"
### Make sure cron service is running
### This will test whatever your configured default routes (multi-wan) are up or down and perform modifications on default routes depending on link status
## run "ln -s /etc/firewall-stutz/firewall /etc/init.d/firewall"
### after this you can start/restart the firewall using "service firewall start|stop|restart"
## Edit files on /etc/firewall-stutz/conf
### There is an extensive example there. Remember to comment out the parts you don't need
## run "service firewall start"
