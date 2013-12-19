#!/bin/bash
# -*- coding: utf-8 -*-
# Copyright (c) 2013, Craig Tracey <craigtracey@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

set -e

KICKSTART="kickstart.cfg"
RPM_REPO="http://bay.uchicago.edu/centos/5/os/x86_64/"
BRIDGE="br100"

function usage {
    RET=$1
    echo "$0 -n <name of image> [ -k <kickstart file> -r <rpm repo> -b <bridge> ]"
    exit $RET
}

while getopts "b:k:r:n:h" arg; do
    case $arg in
        b)
            BRIDGE=$OPTARG
            ;;
        k)
            KICKSTART=$OPTARG
            ;;
        r)
            RPM_REPO=$OPTARG
            ;;
        n)
            NAME=$OPTARG
            ;;
        h)
            usage 0
            ;;
    esac
done

if [ -z $NAME ]; then
    echo "You must provide a name for this image"
    exit -1
fi

if [ ! -f $KICKSTART ]; then
    echo "Kickstart file '$KICKSTART' does not exist."
    exit -1
fi

if [ $UID != 0 ]; then
    echo "You must run this as root"
    exit -1
fi

VMSTATUS=`virsh list | tail -n+3 | grep $NAME | awk '{print $3}'`

if [ ! -e $VMSTATUS ]; then
    if [ "$VMSTATUS" == "running" ]; then
        echo "There is already a virtual machine running with name: $NAME"
        read -p "Would you like to destroy and undefine this virtual machine (y/n)? "
        REPLY=`echo $REPLY | awk '{print tolower($0)}'`
        if [ "$REPLY" == "n" ]; then
            echo "Exiting"
            exit -1
        fi
        virsh destroy $NAME
        virsh undefine $NAME
    fi
fi

TEMPDIR=`mktemp -d`
ln -s `realpath $KICKSTART` $TEMPDIR/ks.cfg

virt-install --accelerate --name=$NAME \
    --noreboot \
    --ram=1024 \
    --file=$NAME.img \
    --file-size=10 \
    --machine=pc \
    --location $RPM_REPO \
    --graphics vnc,listen=0.0.0.0 \
    --noautoconsole \
    --initrd-inject=$TEMPDIR/ks.cfg --extra-args "ks=file:/ks.cfg stage2=$RPM_REPO/images/install.img text" \
    -w bridge:$BRIDGE \
    --wait=-1

rm -rf $TEMPDIR

virsh undefine $NAME
