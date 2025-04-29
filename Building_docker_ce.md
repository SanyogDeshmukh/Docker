# Building Docker-CE on RHEL

The instructions provided below specify the steps to build [Docker](https://www.docker.com/) version 28.1.0 on Linux on IBM Z for following distributions:

* RHEL (8.8, 8.10, 9.2, 9.4, 9.5)

_**General Notes:**_

* _When following the steps below please use a standard permission user unless otherwise specified._
* _A directory `/<source_root>/` will be referred to in these instructions, this is a temporary writable directory anywhere you'd like to place it._

## Prerequisites:

* Docker packages for RHEL can be installed by following the instructions [here](https://docs.docker.com/engine/install/#server).


## 1. Build using script

If you want to build Docker-ce using manual steps, go to STEP 2.

Use the following commands to build Docker-ce using the build [script](https://github.com/linux-on-ibm-z/scripts/tree/master/Docker-ce). Please make sure you have wget installed.

```bash
wget -q https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Docker-ce/28.1.0/build_docker_ce.sh

# Build Alfresco
bash build_docker-ce.sh
```

## 2. Install dependencies

  ```bash
  export SOURCE_ROOT=/<source_root>/
  export PATCH_URL="https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Docker-ce/28.1.0/patch"
  mkdir -p $SOURCE_ROOT/go/src/github.com/docker
  mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries
  mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
  ```

  * RHEL (8.8, 8.10, 9.2, 9.4, 9.5)
  ```bash
    sudo yum install -y wget tar make jq git
  ```


## 3. Build binaries
### 3.1. Build containerd.io binary

```bash
cd $CURDIR/go/src/github.com/docker
git clone https://github.com/docker/containerd-packaging
cd containerd-packaging
git checkout $CONTAINERD_REF
curl -s $PATCH_URL/containerd-makefile.diff | git apply
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/
```

- For RHEL 8.x
```bash
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi8/ubi
cp build/rhel/8/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8/
```

- For RHEL 9.x
```bash
mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi9/ubi
cp build/rhel/9/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/
```
### 3.2. Build Docker-CE binaries (docker-ce, docker-compose, docker-ce-cli, docker-buildx-plugin, docker-ce-rootless-extras)

```bash
cd $SOURCE_ROOT/go/src/github.com/docker
git clone https://github.com/docker/docker-ce-packaging
cd docker-ce-packaging/
git checkout $DOCKER_PACKAGING_REF
curl -s $PATCH_URL/docker-makefile.diff | git apply
make DOCKER_CLI_REF=v$PACKAGE_VERSION DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF checkout
```

- For RHEL 8.x
```bash
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi8/ubi
cp build/rhel/8/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8/
```

- For RHEL 9.x
```bash
mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi9/ubi
cp build/rhel/9/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/
```






#### 5.3. Start Alfresco

The Docker Compose plugin is required to start the alfresco docker-compose.yml script. Please ensure the docker-compose-plugin package is installed based on your distro.

```bash
cd $SOURCE_ROOT/docker-compose-source
docker compose up
```

### Reference:

- https://www.alfresco.com/
