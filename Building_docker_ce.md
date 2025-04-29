# Building Docker-CE on RHEL

The instructions provided below specify the steps to build [Docker](https://www.docker.com/) version 27.5.1 on Linux on IBM Z for following distributions:

* RHEL (8.8, 8.10, 9.2, 9.4, 9.5)

_**General Notes:**_

* _When following the steps below please use a standard permission user unless otherwise specified._
* _A directory `/<source_root>/` will be referred to in these instructions, this is a temporary writable directory anywhere you'd like to place it._
* _Building docker-ce and containerd binaries required active redhat subscription.

## Prerequisites:

* Docker needs to be installed by following the instructions [here](https://docs.docker.com/engine/install/#server).
* Redhat subscription is needed to enable `codeready-builder` repository. Redhat username and password are needed in the form of secrets stored as `/run/secrets/rh-user` and `/run/secrets/rh-pass`

## 1. Build using script

If you want to build Docker-ce using manual steps, go to STEP 2.

Use the following commands to build Docker-ce using the build [script](https://github.com/linux-on-ibm-z/scripts/tree/master/Docker-ce). Please make sure you have wget installed.

```bash
wget -q https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Docker-ce/27.5.1/build_docker_ce.sh

# Build Docker-CE
bash build_docker_ce.sh
```

## 2. Install dependencies

  ```bash
  export SOURCE_ROOT=/<source_root>/
  export PATCH_URL="https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Docker-ce/27.5.1/patch"
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
cd $SOURCE_ROOT/go/src/github.com/docker
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
cp build/rhel/8/s390x/*.rpm $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8/
```

- For RHEL 9.x
```bash
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi9/ubi
cp build/rhel/9/s390x/*.rpm $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/
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
cd $SOURCE_ROOT/go/src/github.com/docker/docker-ce-packaging
make -C rpm VERSION=$PACKAGE_VERSION DOCKER_CLI_REF=$DOCKER_CLI_REF DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF rpmbuild/bundles-ce-rhel-8-s390x.tar.gz
cp rpm/rpmbuild/bundles-ce-rhel-8-s390x.tar.gz $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
```

- For RHEL 9.x
```bash
cd $SOURCE_ROOT/go/src/github.com/docker/docker-ce-packaging
make -C rpm VERSION=$PACKAGE_VERSION DOCKER_CLI_REF=$DOCKER_CLI_REF DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF rpmbuild/bundles-ce-rhel-9-s390x.tar.gz
cp rpm/rpmbuild/bundles-ce-rhel-9-s390x.tar.gz $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
```

## 4. Install binaries

- For RHEL 8.x
```bash
cd $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
tar -xzf bundles-ce-rhel-8-s390x.tar.gz
sudo yum install -y $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8/containerd.io-${CONTAINERD_VERSION}-3.1.el8.s390x.rpm
sudo yum install -y bundles/$DOCKER_VERSION/build-rpm/rhel-8/RPMS/s390x/*.rpm
```

- For RHEL 9.x
```bash
cd $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
tar -xzf bundles-ce-rhel-9-s390x.tar.gz
sudo yum install -y $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/containerd.io-${CONTAINERD_VERSION}-3.1.el9.s390x.rpm
sudo yum install -y bundles/$DOCKER_VERSION/build-rpm/rhel-9/RPMS/s390x/*.rpm
```
## 5. Verify
```
sudo systemctl start docker
docker login -u <username> -p <password>
docker info
docker run hello-world | grep "Hello from Docker!"
```

### Reference:

- https://www.docker.com/
- https://github.com/docker/containerd-packaging
- https://github.com/docker/docker-ce-packaging
