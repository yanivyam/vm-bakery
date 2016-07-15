#!/usr/bin/env bash

WORK_DIR=$(dirname $0)

PROVIDER='vbox-vagrant'
OSNAME='CentOS'
OSVERSION='7.1'
OSBUILDVERSION='x86_64-Minimal-1511'

VAGRANT="true"

export PROVIDER
export OSNAME
export OSVERSION
export OSBUILDVERSION
export VAGRANT

cd ${WORK_DIR}
sh ./build_vm_image.sh

