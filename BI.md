# Building Docker-CE on RHEL

The instructions provided below specify the steps to build [Docker](https://www.docker.com/) version 27.5.1 on Linux on IBM Z for RHEL 9.x:

## Prerequisites:

* Docker needs to be installed by following the instructions [here](https://docs.docker.com/engine/install/#server).
* Redhat subscription is needed to enable `codeready-builder` repository. Redhat username and password are needed in the form of secrets stored as `/run/secrets/rh-user` and `/run/secrets/rh-pass`

## 1. Build using build script.

If you want to build docker-ce using manual steps, go to STEP 2.

* Before running the build script, please set references for CONTAINERD_REF, DOCKER_CLI_REF, DOCKER_ENGINE_REF, DOCKER_PACKAGING_REF, DOCKER_COMPOSE_REF and DOCKER_BUILDX_REF
inside the build script. These references are required to build binaries.
  * CONTAINERD_REF is the commit id of a `release pull request` on the main branch of [containerd-packaging](https://github.com/docker/containerd-packaging/commits/main/) repository. (For v1.27.7 [see commit](https://github.com/docker/containerd-packaging/commit/2d17c55a6af6c3e48e0fdf19e7239f65ceb61d69))
  * DOCKER_CLI_REF is the latest commit id from release tag of [docker-cli](https://github.com/docker/cli) repository.
  * DOCKER_ENGINE_REF is the latest commit id from release tag of [moby](https://github.com/moby/moby) repository. 
  * DOCKER_PACKAGING_REF is the commit id of a merged pull request to docker-ce-packaging repository can be obtained from official docker engine [release notes](https://docs.docker.com/engine/release-notes/28/). Check for the pull request link for docker/docker-ce-packaging in the packaging updates section. If packaging updates are missing for a release, then use commit id of last release. (For [v27.5.1](https://docs.docker.com/engine/release-notes/27/#2751))
  * DOCKER_COMPOSE_REF and DOCKER_BUILDX_REF are docker-compose and docker buildx versions mentioned in the release notes of [moby](https://github.com/moby/moby) repository. If versions are not mentioned in the release notes, use versions mentioned in previous release. For v27.5.1: https://github.com/moby/moby/releases/tag/v27.5.1

```bash
bash build_docker.sh 
```
## 2. Set References and create necessary directories 

* Before executing the build steps, please set references for CONTAINERD_REF, DOCKER_CLI_REF, DOCKER_ENGINE_REF, DOCKER_PACKAGING_REF, DOCKER_COMPOSE_REF and DOCKER_BUILDX_REF as environement variables. Details are provided in STEP 1.
  ```bash
  export SOURCE_ROOT=/<source_root>/
  export PACKAGE_NAME="docker"
  export PACKAGE_VERSION=       # Add docker-ce version. For example 27.5.1
  export CONTAINERD_VERSION=    # Add containerd version. For example 1.7.25
  export CONTAINERD_REF=
  export DOCKER_CLI_REF=
  export DOCKER_ENGINE_REF=
  export DOCKER_PACKAGING_REF=

  mkdir -p $SOURCE_ROOT/go/src/github.com/docker
  mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries
  mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
  
  ```

## 3. Install dependencies

  ```bash
sudo yum install -y wget tar make jq git
```

## 4. Build binaries
### 4.1. Build containerd.io binary

```bash
cd $SOURCE_ROOT/go/src/github.com/docker
git clone https://github.com/docker/containerd-packaging
cd containerd-packaging
git checkout $CONTAINERD_REF   # For CONTAINERD_REF, refer STEP 1 and set as environment variable as shown in STEP 2. 
git apply $SOURCE_ROOT/containerd-makefile.diff # Please see attached patch.
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi9/ubi
cp build/rhel/9/s390x/*.rpm $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/
```
### 4.2. Build Docker-CE binaries (docker-ce, docker-compose, docker-ce-cli, docker-buildx-plugin, docker-ce-rootless-extras)

```bash
cd $SOURCE_ROOT/go/src/github.com/docker
git clone https://github.com/docker/docker-ce-packaging
cd docker-ce-packaging/
git checkout $DOCKER_PACKAGING_REF      # For DOCKER_PACKAGING_REF, please refer STEP 1 and set as environement variable as shown in STEP 2
git apply $SOURCE_ROOT/docker-makefile.diff # Please see attached patch.

# For DOCKER_CLI_REF, DOCKER_ENGINE_REF, DOCKER_COMPOSE_REF, DOCKER_BUILDX_REF, please refer STEP 1 and set as environement variables as shown in STEP 2
make DOCKER_CLI_REF=v$PACKAGE_VERSION DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF checkout
cd $SOURCE_ROOT/go/src/github.com/docker/docker-ce-packaging
make -C rpm VERSION=$PACKAGE_VERSION DOCKER_CLI_REF=$DOCKER_CLI_REF DOCKER_ENGINE_REF=$DOCKER_ENGINE_REF DOCKER_PACKAGING_REF=$DOCKER_PACKAGING_REF DOCKER_COMPOSE_REF=$DOCKER_COMPOSE_REF DOCKER_BUILDX_REF=$DOCKER_BUILDX_REF rpmbuild/bundles-ce-rhel-9-s390x.tar.gz
cp rpm/rpmbuild/bundles-ce-rhel-9-s390x.tar.gz $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
```

## 5. Install binaries

```bash
cd $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries-tar/
tar -xzf bundles-ce-rhel-9-s390x.tar.gz
sudo yum install -y $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/containerd.io-${CONTAINERD_VERSION}-3.1.el9.s390x.rpm
sudo yum install -y bundles/$DOCKER_VERSION/build-rpm/rhel-9/RPMS/s390x/*.rpm
```

## 6. Verify
```
sudo systemctl start docker
docker login -u <username> -p <password>
docker info
docker run hello-world | grep "Hello from Docker!"
```

