#!/usr/bin/env bash

netstat -np | grep SYN_REC
# Check the number of SYN_REC connections

netstat -np | grep SYN_REC | awk '{print $5}' | awk -F: '{print $1}'
# Check how many IP addresses are sending SYN_REC connections

netstat -np | grep TIME_WAIT | awk '{print $5}' | awk -F: '{print $1}'
# Check how many IP addresses are in the TIME_WAIT state (the Debian default is 60 seconds; see /proc/sys/net/ipv4/tcp_fin_timeout)

netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
# Check the number of connections to the server from each IP address

netstat -anp | grep 'tcp\|udp' | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
# Check the number of TCP and UDP connections to the server from each IP address

netstat -plan | grep :80 | awk {'print $5'} | cut -d: -f 1| sort | uniq -c | sort -nk 1
# Check the number of connections to port 80 from each IP address

netstat -n | awk '/^tcp/ {++state[$NF]} END {for(key in state) print key,"\t",state[key]}'
# List the number of connections in each state (SYN_RECV, TIME_WAIT, ESTABLISHED, etc.)
