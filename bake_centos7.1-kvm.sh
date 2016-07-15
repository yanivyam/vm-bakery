#!/usr/bin/env bash

WORK_DIR=$(dirname $0)

PROVIDER='kvm'
OSNAME='CentOS'
OSVERSION='7.1'
OSBUILDVERSION='V74844-01'

VAGRANT="false"

export PROVIDER
export OSNAME
export OSVERSION
export OSBUILDVERSION
export VAGRANT

cd ${WORK_DIR}
sh ./build_vm_image.sh

