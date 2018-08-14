#!/bin/bash -x

LIST="fakenews-gambling-porn-social"
echo 'server:' > "$LIST.conf"
/bin/curl -sk "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/$LIST/hosts" |\
  awk '/^0.0.0.0 0.0.0.0/{next};/^0\.0\.0\.0/{print "    local-zone: \""$2".\" always_nxdomain"}' >> "$LIST.conf"
#  awk '/^0.0.0.0 0.0.0.0/{next};/^0\.0\.0\.0/{print "local-zone: \""$2"\" redirect\nlocal-data: \""$2" A 0.0.0.0\""}' > "$LIST.conf"

/bin/chown root:unbound "$LIST.conf"
/bin/chcon system_u:object_r:named_conf_t:s0 "$LIST.conf"
#read
/bin/mv -i --backup "./$LIST.conf" /etc/unbound/local.d/
/sbin/unbound-control -c /etc/unbound/unbound.conf reload

#EOF
