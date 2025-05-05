#!/usr/bin/env bash
# Execute build script: bash build_docker_ce.sh (provide -h for help)
# Please set the below mentioned references before running the build script. (References for containerd v1.7.25 and docker-ce v27.5.1 are already set in below script)
# CONTAINERD_REF is the commit id of a "release pull request" on the main branch of containerd-packaging repository (https://github.com/docker/containerd-packaging/commits/main/). For v1.7.25: https://github.com/docker/containerd-packaging/commit/32f5c873ffc9cfbce7c20524c2296a2507e0d045
# DOCKER_CLI_REF is the latest commit id of a release tag of docker-cli repository. (https://github.com/docker/cli). For example, commit id of tag v27.5.1 is used in the script. 
# DOCKER_ENGINE_REF is the latest commit id of a release tag of moby repository (https://github.com/moby/moby). For example, commit id of tag v27.5.1 is used in the script.
# DOCKER_PACKAGING_REF is the commit id of a merged pull request to docker-ce-packaging that can be obtained from official docker engine release notes(https://docs.docker.com/engine/release-notes/28/). Check for the pull request link for docker/docker-ce-packaging in the packaging updates section. 
# If packaging updates are missing for a release, then use commit id mentioned in the packaging updates of last release. (For v27.5.1, check here (https://docs.docker.com/engine/release-notes/27/#2751))
# DOCKER_COMPOSE_REF and DOCKER_BUILDX_REF are docker-compose and docker buildx versions mentioned in the release notes of moby repository(https://github.com/moby/moby). If versions are not mentioned in the release notes, use versions mentioned in previous release.For v27.5.1: https://github.com/moby/moby/tag/v27.5.1
set -e -o pipefail
PACKAGE_NAME="docker"
PACKAGE_VERSION=27.5.1
CONTAINERD_VERSION=1.7.25
CONTAINERD_REF=32f5c873ffc9cfbce7c20524c2296a2507e0d045
DOCKER_CLI_REF=9f9e4058019a37304dc6572ffcbb409d529b59d8
DOCKER_ENGINE_REF=4c9b3b011ae4c30145a7b344c870bdda01b454e2
DOCKER_PACKAGING_REF=773cdc7708a56583c46cea090889b91fb45b56b2
VERSION=27.5.1
DOCKER_COMPOSE_REF=v2.32.2
DOCKER_BUILDX_REF=v0.21.0
CURDIR="$(pwd)"
FORCE="false"
LOG_FILE="$CURDIR/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
trap cleanup 0 1 2 ERR
#Check if directory exsists
if [ ! -d "$CURDIR/logs" ]; then
        mkdir -p "$CURDIR/logs"
fi
if [ -f "/etc/os-release" ]; then
        source "/etc/os-release"
fi
function checkPrequisites() {
        if command -v "sudo" >/dev/null; then
                printf -- 'Sudo : Yes\n' >>"$LOG_FILE"
        else
                printf -- 'Sudo : No \n' >>"$LOG_FILE"
                printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
                exit 1
        fi
        if [[ "$FORCE" == "true" ]]; then
                printf -- 'Force attribute provided hence continuing with install without confirmation message\n' |& tee -a "$LOG_FILE"
        else
                # Ask user for prerequisite installation
                printf -- "\nAs part of the installation , dependencies would be installed/upgraded.\n"
                while true; do
                        read -r -p "Do you want to continue (y/n) ? :  " yn
                        case $yn in
                        [Yy]*)
                                printf -- 'User responded with Yes. \n' >>"$LOG_FILE"
                                break
                                ;;
                        [Nn]*) exit ;;
                        *) echo "Please provide confirmation to proceed." ;;
                        esac
                done
        fi
}
function cleanup() {
        if [ -f ${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz ]; then
                sudo rm ${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz
        fi
}
function configureAndInstall() {
        printf -- 'Configuration and Installation started \n'
        cd "$CURDIR"
        mkdir -p $CURDIR/go/src/github.com/docker
        mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries
        mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar

        if [ -d ""$CURDIR"/go/src/github.com/docker/docker-ce-packaging" ]; then
           echo "Removing the dir."
           sudo rm -rf $CURDIR/go/src/github.com/docker/docker-ce-packaging
        else
           echo "$CURDIR/go/src/github.com/docker/docker-ce-packaging does not exist!"
        fi

        if [ -d ""$CURDIR"/go/src/github.com/docker/containerd-packaging" ]; then
            echo "Removing the dir."
            sudo rm -rf $CURDIR/go/src/github.com/docker/containerd-packaging
        else
            echo "$CURDIR/go/src/github.com/docker/containerd-packaging does not exist!"
        fi
         ## Build Containerd
         cd $CURDIR/go/src/github.com/docker
         git clone https://github.com/docker/containerd-packaging
         cd containerd-packaging
         git checkout $CONTAINERD_REF
         git apply $CURDIR/containerd-makefile.diff 
         mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/

         #Build RHEL-9 containerd binaries
         mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9
         make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi9/ubi
         cp build/rhel/9/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/

         #Docker-CE
         cd $CURDIR/go/src/github.com/docker
         git clone https://github.com/docker/docker-ce-packaging
         cd docker-ce-packaging/
         git checkout $DOCKER_PACKAGING_REF
         git apply $CURDIR/docker-makefile.diff 
         make DOCKER_CLI_REF=v$PACKAGE_VERSION DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF checkout

         #Building Rhel 9 Docker-ce Binaries
         cd $CURDIR/go/src/github.com/docker/docker-ce-packaging
         make -C rpm VERSION=$PACKAGE_VERSION DOCKER_CLI_REF=$DOCKER_CLI_REF DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF rpmbuild/bundles-ce-rhel-9-s390x.tar.gz
         cp rpm/rpmbuild/bundles-ce-rhel-9-s390x.tar.gz $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
         echo "Completed building RHEL-9 docker-ce binaries"
  
}

function logDetails() {
        printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
        if [ -f "/etc/os-release" ]; then
                cat "/etc/os-release" >>"$LOG_FILE"
        fi
        cat /proc/version >>"$LOG_FILE"
        printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"
        printf -- "Detected %s \n" "$PRETTY_NAME"
        printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" |& tee -a "$LOG_FILE"
}
# Print the usage message
function printHelp() {
        echo
        echo "Usage: "
        echo "  build_docker.sh [-d debug]  [-y install-without-confirmation] "
        echo
}
while getopts "h?yd" opt; do
        case "$opt" in
        h | \?)
                printHelp
                exit 0
                ;;
        d)
                set -x
                ;;
        y)
                FORCE="true"
                ;;
        esac
done
function gettingStarted() {
        printf -- "*************************************************************************"
        printf -- "\n\nUsage: \n"
        printf -- "  Docker Binaries installed successfully !!!  \n"
        printf -- "\n ***********Binaries will be created in the following folders************* \n "
        printf -- "\n ************************************************************************ \n "
        printf -- "\$CURDIR/docker-${PACKAGE_VERSION}-binaries/containerd \n"
        printf -- "\$CURDIR/docker-${PACKAGE_VERSION}-binaries/static \n "
        printf -- "\$CURDIR/docker-${PACKAGE_VERSION}-binaries/ubuntu-debs/ \n "
        printf -- "\n************************************************************************** \n"
        printf -- "For building containerd binaries you should first have a tagged release on the containerd(https://github.com/containerd/containerd/releases) repository."
        printf -- '\n'
}
###############################################################################################################
logDetails
checkPrequisites #Check Prequisites
DISTRO="$ID-$VERSION_ID"

printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "$LOG_FILE"
printf -- 'Installing the dependencies for Docker from repository \n' |& tee -a "$LOG_FILE"
sudo yum install -y wget tar make jq git |& tee -a "$LOG_FILE"
configureAndInstall |& tee -a "$LOG_FILE"
gettingStarted |& tee -a "$LOG_FILE"
