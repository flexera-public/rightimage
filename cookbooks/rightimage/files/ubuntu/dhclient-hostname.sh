#!/bin/sh

# This script can be installed in /etc/dhclient-enter-hooks to set the client's
# hostname based either on the hostname that the DHCP server supplied or the
# hostname in whatever ptr record exists for the assigned IP address.
# Less aggressive than the contrib ones, which always sets the hostname.  This
# only sets on first boot, when /etc/hostname has been axed to mimic default
# behavior of most other systems

if [ -e /etc/hostname ]; then
  return
fi

if [ x$new_host_name = x ]; then
  ptrname=`echo $new_ip_address \
           |sed -e \
  's/\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\4.\3.\2.\1.in-addr.arpa/'`
  (echo "set type=ptr"; echo "$ptrname") |nslookup >/tmp/nslookup.$$
  set `sed -n -e "s/$ptrname[   ]*\(canonical \)*name *= *\(.*\)/\2 \1/p" \
                                                        < /tmp/nslookup.$$` _
  if [ x$1 = x_ ]; then
    new_host_name=""
  else
    if [ $# -gt 1 ] && [ x$2 = xcanonical ]; then
      new_host_name=`sed -n -e "s/$1[   ]*name *= *\(.*\)/\1/p" \
                                                        </tmp/nslookup.$$`
    else
      new_host_name=$1
    fi
  fi
  rm /tmp/nslookup.$$
fi
if [ x$new_host_name != x ]; then
  echo "$new_host_name" > /etc/hostname
  hostname $new_host_name
fi
