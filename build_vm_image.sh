#!/bin/sh
#
# Creates VM image
#
# Requires the following environment variables to be set:
#
# PROVIDER       - hypervisor to use: kvm, virtualbox, vmware
# OSNAME         - target operating system name (CentOS, OracleLinux, etc)
# OSVERSION      - target OS version (example: 7.1, 6.5)
# OSBUILDVERSION - target OS build version (example: 5123)
#
# Optional:
# VAGRANT        - if set to true, will creates a vagrant box for VirtualBox
# SKIPBUILD      - Set to 1 to skip running Packer. Useful for debugging


error_msg()
{
    echo $1 >&2
    exit 1
}


SCRIPT_DIR=$(dirname $0)
# Go to the script's directory
echo "Changing dir to ${SCRIPT_DIR}"
cd "${SCRIPT_DIR}" || error_msg "Unable to chdir to ${SCRIPT_DIR}"
if [ ${SCRIPT_DIR} == '.' ]; then

    SCRIPT_DIR=`pwd`
fi
WORK_DIR=${SCRIPT_DIR}/work



if [ -z "${PROVIDER}" ]; then
    error_msg "Please supply PROVIDER environment variable"
fi
if [ -z "${OSNAME}" ]; then
    error_msg "Please supply OSNAME environment variable"
fi
if [ -z "${OSVERSION}" ]; then
    error_msg "Please supply OSVERSION environment variable"
fi
if [ -z "${OSBUILDVERSION}" ]; then
    error_msg "Please supply OSBUILDVERSION environment variable"
fi

source ./settings.sh

# print some info
echo "######################################################################"
echo ""
echo "Provider: ${PROVIDER}"
echo "Target OS: ${OSNAME}, version: ${OSVERSION}, build: ${OSBUILDVERSION}"
echo ""
if [ "${VAGRANT}" == 'true' ]; then
    echo "Output: Vagrant box for Virtualbox"
else
    echo "Output: image file for ${PROVIDER}"
fi
echo ""
echo "######################################################################"
echo "Note for running builds on KVM VM:"
echo "Please ensure that you have enabled running KVM inside the VM this"
echo "script runs on."
echo "For more details, see:"
echo "https://fedoraproject.org/wiki/How_to_enable_nested_virtualization_in_KVM"
echo ""
echo "The simplest way to do this is open the VM settings in virt-manager"
echo "click on Processor, and select Copy the host CPU configuration to the VM's CPU"
echo "######################################################################"
echo ""



# build version for the image by TMS
# the version will be the Jenkins build number if exists
# otherwise, will default to "SNAPSHOT"
if [ -z "${BUILD_NUMBER}" ]; then
    IMAGE_BUILD_VERSION='SNAPSHOT'
else
    IMAGE_BUILD_VERSION="${BUILD_NUMBER}"
fi

# Figure out the major OS version
IFS="." read -a osversion_array <<< "${OSVERSION}"

OSFAMILY="NA"
case "${OSNAME}" in
    'CentOS')
        OSFAMILY="redhat"
        ;;
    'OracleLinux')
        OSFAMILY="redhat"
        ;;
    *)
        # no OS family for this Linux distribution
        OSFAMILY="NA"
        ;;
esac
echo "OS Family detected: ${OSFAMILY}"
OSMAJORVERSION=${osversion_array[0]}
echo "OS Major version detected: ${OSMAJORVERSION}"

# Figure out which Packer configuration file to use based on the OSNAME
# 1. ExactOSName-ExactVersion-Provider.json
# 2. ExactOSName-MajorVersion-Provider.json
# 3. OSFamilyName-ExactVersion-Provider.json
# 4. OSFamilyName-MajorVersion-Provicer.json
#

PACKER_CONFS_ARRAY[0]="${OSNAME}${OSVERSION}-${PROVIDER}.json"
PACKER_CONFS_ARRAY[1]="${OSNAME}${OSMAJORVERSION}.x-${PROVIDER}.json"
if [ ${OSFAMILY} != "NA" ]; then
    PACKER_CONFS_ARRAY[2]="${OSFAMILY}${OSVERSION}-${PROVIDER}.json"
    PACKER_CONFS_ARRAY[3]="${OSFAMILY}${OSMAJORVERSION}.x-${PROVIDER}.json"
fi

PACKER_CONF=""
for i in "${PACKER_CONFS_ARRAY[@]}"
do
    echo "Searching for Packer configuration ${i}.."
    if [ -f ${i} ]; then
        PACKER_CONF="$i"
        echo "found $i !"
        break
    fi
done
if [ -z "${PACKER_CONF}" ]; then
    error_msg "Could not find suitable Packer configuration for this OS and version, or alternatively for the OS family"
fi


BUILD_DIR=${WORK_DIR}/build
VAGRANT_BUILD_DIR=${WORK_DIR}/buildvagrant

# name of OS iso file:
SOURCE_ISO_NAME="${OSNAME}-${OSVERSION}-${OSBUILDVERSION}.iso"
# location of OS iso file on disk (optional for installations from laptop)
SOURCE_ISO_PATH="${SCRIPT_DIR}/source_iso"
echo "Looking for ISO in ${SOURCE_ISO_PATH}/${SOURCE_ISO_NAME}..."
# location of OS iso file on repository (used by Jenkins when running on a builder server)
SOURCE_ISO_URL="${SETTINGS_SOURCE_ISO_HTTP_SERVER}/${OSNAME}/${OSVERSION}-${OSBUILDVERSION}/${SOURCE_ISO_NAME}"

echo "Detecting which MD5 location to use"
if [ -f "${SOURCE_ISO_PATH}/${SOURCE_ISO_NAME}" ]; then
    # Full absolute path must be used here, otherwise Packer will not be able to find the md5 file
    SOURCE_ISO_MD5_URL="file://${SOURCE_ISO_PATH}/${SOURCE_ISO_NAME}.md5"
else
    SOURCE_ISO_MD5_URL="${SOURCE_ISO_URL}.md5"
fi
echo "Using MD5 from ${SOURCE_ISO_MD5_URL}"


# clean up the build directory
if [ "${SKIPBUILD}" != "1" ]; then
    echo "Cleaning build directories"
    rm -rf ${BUILD_DIR}
    rm -rf ${VAGRANT_BUILD_DIR}
fi


# run Packer
PACKER_BIN="SETTINGS_PACKER_BIN"
if [ ! -x "${PACKER_BIN}" ]; then
    # if Packer is not in its default path, then try to run it from somewhere else
    # (good when running on laptop)
    PACKER_BIN="packer"
fi

export OSNAME
export OSVERSION
export OSBUILDVERSION
export IMAGE_BUILD_VERSION
export SOURCE_ISO_NAME
export SOURCE_ISO_PATH
export SOURCE_ISO_URL
export SOURCE_ISO_MD5_URL

# Packer env vars
export PACKER_LOG=1
# we must change Packer temp dir, otherwise it will use /tmp which may not have enough space
export TMPDIR="${WORK_DIR}/tmp"
mkdir -p "${TMPDIR}" || error_msg "Unable to create temp dir in ${TMPDIR}"
if [ "${SKIPBUILD}" != "1" ]; then
    ${PACKER_BIN} build ./${PACKER_CONF}
    RES=$?
    if [ ${RES} != 0 ]; then
        error_msg "Packer build failed"
    fi
fi


if [ "${VAGRANT}" == 'true' ]; then
    SRC_ARTIFACT_FILE="${VAGRANT_BUILD_DIR}/vagrant.box"
    OUT_FILE="${OSNAME}-${OSVERSION}-${OSBUILDVERSION}-${PROVIDER}-${IMAGE_BUILD_VERSION}.box"
else
    SRC_ARTIFACT_FILE="${BUILD_DIR}/out.img"
    OUT_FILE="${OSNAME}-${OSVERSION}-${OSBUILDVERSION}-${PROVIDER}-${IMAGE_BUILD_VERSION}.img"
fi

DEST=${SETTINGS_ARTIFACTS_BASE_DIR}/${PROVIDER}/${OSNAME}/${OSVERSION}-${OSBUILDVERSION}-${PROVIDER}-${IMAGE_BUILD_VERSION}

# Copy the build to the master repository
echo "Creating destination path on remote repository ${DEST}"
mkdir -p ${DEST} || error_msg "Unable to create destination directory in the repository"
echo "Copying build ${SRC_ARTIFACT_FILE} to remote repository"
cp ${SRC_ARTIFACT_FILE} ${DEST}/${OUT_FILE} || error_msg "Cannot copy output image file to repository"

