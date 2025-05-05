# Building Docker-CE on RHEL

The instructions provided below specify the steps to build [Docker](https://www.docker.com/) version 27.5.1 on Linux on IBM Z for RHEL 9.x:

## Prerequisites:

* Docker needs to be installed by following the instructions [here](https://docs.docker.com/engine/install/#server).
* Redhat subscription is needed to enable `codeready-builder` repository. Redhat username and password are needed in the form of secrets stored as `/run/secrets/rh-user` and `/run/secrets/rh-pass`
* CONTAINERD_REF is the commit id of `release pull request` (For here: [1.27.7](https://github.com/docker/containerd-packaging/commit/2d17c55a6af6c3e48e0fdf19e7239f65ceb61d69)) on the main branch of [containerd-packaging](https://github.com/docker/containerd-packaging/commits/main/) repository.
* DOCKER_CLI_REF is the latest commit id from release tag(For here: 27.5.1) of [docker-cli](https://github.com/docker/cli) repository.
* DOCKER_ENGINE_REF is the latest commit id from release tag(For here: 27.5.1) of [moby](https://github.com/moby/moby) repository.
* DOCKER_PACKAGING_REF can be obtained from official docker engine [release notes](https://docs.docker.com/engine/release-notes/28/). Check for pull request link in 
  packaging updates. If packaging updates are missing for a release, then use commit of last release. (For here: [27.5.1](https://docs.docker.com/engine/release-notes/27/#2751))
  

## 1. Set References and create necessary directories 

  ```bash
  export SOURCE_ROOT=/<source_root>/
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

## 2. Install dependencies

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
git apply $SOURCE_ROOT/containerd-makefile.diff #Please see attached patch.
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/
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
git apply $SOURCE_ROOT/docker-makefile.diff #Please see attached patch.
make DOCKER_CLI_REF=v$PACKAGE_VERSION DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF checkout
cd $SOURCE_ROOT/go/src/github.com/docker/docker-ce-packaging
make -C rpm VERSION=$PACKAGE_VERSION DOCKER_CLI_REF=$DOCKER_CLI_REF DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF rpmbuild/bundles-ce-rhel-9-s390x.tar.gz
cp rpm/rpmbuild/bundles-ce-rhel-9-s390x.tar.gz $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
```

## 4. Install binaries

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

