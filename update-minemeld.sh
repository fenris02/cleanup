#!/bin/bash

PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

[ -d /root/minemeld-ansible ] || /bin/git clone https://github.com/PaloAltoNetworks/minemeld-ansible.git

cd /root/minemeld-ansible || exit 1
/bin/ansible-playbook -K -i 127.0.0.1, local.yml

#EOF
