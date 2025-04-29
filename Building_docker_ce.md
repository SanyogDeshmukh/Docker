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
### 3.1. Build containerd binaries

```bash
cd $CURDIR/go/src/github.com/docker
git clone https://github.com/docker/containerd-packaging
cd containerd-packaging
git checkout $CONTAINERD_REF
curl -s $PATCH_URL/containerd-makefile.diff | git apply
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/

#Build RHEL-8 containerd binaries
mkdir -p $SOURCE_ROOT/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi8/ubi
cp build/rhel/8/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-8/

#Build RHEL-9 containerd binaries
mkdir -p $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9
make REF=v$CONTAINERD_VERSION BUILD_IMAGE=registry.access.redhat.com/ubi9/ubi
cp build/rhel/9/s390x/*.rpm $CURDIR/${PACKAGE_NAME}-${PACKAGE_VERSION}-binaries/containerd/rhel-9/
```

* For IBM Semeru or Temurin JDKs only
```bash
git fetch --depth 1 origin "178324f2dd7f5b010cd93a17a414cd82d916d9b5"
git checkout "178324f2dd7f5b010cd93a17a414cd82d916d9b5"
sed -i "s#FROM.*#FROM rockylinux:9 AS rockylinux9#g" Dockerfile
sed -i "s#RUN export#RUN yum install -y glibc-langpack-en \&\& \\\\\n    yum clean all \&\& \\\\\n    export#" Dockerfile
cp $SOURCE_ROOT/jre.tar.gz .
docker build -t "alfresco/alfresco-base-java:jre17-rockylinux9" . \
  --build-arg JAVA_PKG="jre.tar.gz" \
  --build-arg CREATED="$(date --iso-8601=seconds)" \
  --build-arg REVISION="$(git rev-parse --verify HEAD)" \
  --no-cache
```
* For IBM Semeru or Temurin JDKs only
```bash
git fetch --depth 1 origin "23a182196c8e56aff4142a7db977a6faddb00bfb"
git checkout "23a182196c8e56aff4142a7db977a6faddb00bfb"

# Only if Building for Sles 15.6 Distribution
docker pull rockylinux:9
docker tag rockylinux:9 rockylinux:8.8

# Execute the Build Command
docker build -t "alfresco/alfresco-base-java:jre${jver}-rockylinux9" . \
  --build-arg DISTRIB_NAME=rockylinux --build-arg DISTRIB_MAJOR=9 \
  --build-arg JAVA_MAJOR="17" --build-arg JDIST=jre \
  --build-arg CREATED="$(date --iso-8601=seconds)" \
  --build-arg REVISION="$(git rev-parse --verify HEAD)" --no-cache
```

#### 3.2. Build alfresco-base-tomcat image

```bash
cd "$SOURCE_ROOT"
git clone --depth 1 -b master https://github.com/Alfresco/alfresco-docker-base-tomcat 
cd alfresco-docker-base-tomcat
git fetch --depth 1 origin "4b5c48ba4e89acd45274dee518e39588d8fa0f5d"
git checkout "4b5c48ba4e89acd45274dee518e39588d8fa0f5d"
curl -sSL "${PATCH_URL}/base-tomcat.patch" | git apply -

# Only if Building for Rhel Distributions
sed -i '98s|^RUN |RUN rm -rf /var/cache/dnf/* \&\& |' Dockerfile
sed -i '/^RUN if \[ "\$DISTRIB_MAJOR" -eq 8 \]; then \\/i RUN rm -rf /var/cache/dnf/* && dnf clean all' Dockerfile
sed -i 's|dnf clean all \&\& \\|rm -rf /var/cache/dnf/* \&\& dnf clean all \&\& \\|' Dockerfile
sed -i 's|dnf clean all; \\|rm -rf /var/cache/dnf/* \&\& dnf clean all; \\|' Dockerfile

# Execute the Build Command
DOCKER_BUILDKIT=0 docker build -t "alfresco/alfresco-base-tomcat:tomcat10-jre17-rockylinux9" . \
    --build-arg DISTRIB_NAME=rockylinux --build-arg DISTRIB_MAJOR=9 \
    --build-arg JAVA_MAJOR="17" --build-arg TOMCAT_MAJOR=10 \
    --build-arg TOMCAT_VERSION="$(jq -r .tomcat_version tomcat10.json)" \
    --build-arg TOMCAT_SHA512="$(jq -r .tomcat_sha512 tomcat10.json)" \
    --build-arg TCNATIVE_VERSION="$(jq -r .tcnative_version tomcat10.json)" \
    --build-arg TCNATIVE_SHA512="$(jq -r .tcnative_sha512 tomcat10.json)" \
    --build-arg APR_VERSION="$(jq -r .apr_version tomcat10.json)" \
    --build-arg APR_SHA256="$(jq -r .apr_sha256 tomcat10.json)" \
    --build-arg CREATED="$(date --iso-8601=seconds)" \
    --build-arg REVISION="$(git rev-parse --verify HEAD)" \
    --no-cache
```

#### 3.3. Build alfresco-community-repo

```bash
export PACKAGE_VERSION="25.1.0"
export COMMUNITY_REPO_VERSION="25.1.0.71"
cd $SOURCE_ROOT
git clone --depth 1 -b "${COMMUNITY_REPO_VERSION}" https://github.com/Alfresco/alfresco-community-repo.git
cd alfresco-community-repo

sed -i "s/FROM.*/FROM alfresco\/alfresco-base-tomcat:tomcat10-jre17-rockylinux9/g" packaging/docker-alfresco/Dockerfile
mvn clean install -DskipTests=true -Dversion.edition=Community -Pbuild-docker-images -Dimage.tag="${COMMUNITY_REPO_VERSION}"
```

#### 3.4. Build Alfresco share

```bash
export COMMUNITY_SHARE_VERSION="25.1.0.56"
cd $SOURCE_ROOT
git clone --depth 1 -b "${COMMUNITY_SHARE_VERSION}" https://github.com/Alfresco/alfresco-community-share.git
cd alfresco-community-share
sed -i "s/FROM.*/FROM alfresco\/alfresco-base-tomcat:tomcat10-jre17-rockylinux9/g" packaging/docker/Dockerfile
mvn clean install -DskipTests=true -Dmaven.javadoc.skip=true -Pbuild-docker-images -Dimage.tag="${COMMUNITY_SHARE_VERSION}" -Drepo.image.tag="${COMMUNITY_REPO_VERSION}"
docker tag "alfresco/alfresco-share-base:${COMMUNITY_SHARE_VERSION}" "alfresco/alfresco-share:${PACKAGE_VERSION}"
```

#### 3.5. Build acs-community-packaging

```bash
cd "$SOURCE_ROOT"
git clone --depth 1 -b "${PACKAGE_VERSION}" https://github.com/Alfresco/acs-community-packaging.git
cd acs-community-packaging
mvn clean install -DskipTests=true -Pbuild-docker-images -Dmaven.javadoc.skip=true -Dimage.tag="${PACKAGE_VERSION}" -Drepo.image.tag="${COMMUNITY_REPO_VERSION}" -Dshare.image.tag="${COMMUNITY_SHARE_VERSION}"
```

#### 3.6. Build Alfresco Search Services

```bash
export SEARCH_SERVICES_COMMIT="6e2f1e1f8e7a833ef23c12587b2cf51a28d34070"
export SEARCH_SERVICES_VERSION="2.0.15"
cd "$SOURCE_ROOT"
git clone --depth 1 -b master https://github.com/Alfresco/SearchServices.git
cd SearchServices/
git fetch --depth 1 origin "${SEARCH_SERVICES_COMMIT}"
git checkout "${SEARCH_SERVICES_COMMIT}"
sed -i "s/FROM.*/FROM alfresco\/alfresco-base-java:jre17-rockylinux9/g" search-services/packaging/src/docker/Dockerfile
cd search-services/
curl -sSL "${PATCH_URL}/search-restlet.patch" | git apply -
mvn clean install -DskipTests=true
cd packaging/target/docker-resources

# Only if Building for Rhel Distributions
sed -i '22i RUN rm -rf /var/cache/dnf/*' Dockerfile

docker build -t alfresco/alfresco-search-services:${SEARCH_SERVICES_VERSION} .
```

#### 3.7. Build Alfresco Activemq

```bash
export ACTIVEMQ_VERSION="5.18.3"
export ACTIVEMQ_COMMIT="f7283c546ec8a1c137a38ea3fc1db8b93299cc35"
cd "$SOURCE_ROOT"
git clone --depth 1 -b master https://github.com/Alfresco/alfresco-docker-activemq.git
cd alfresco-docker-activemq/
git fetch --depth 1 origin "${ACTIVEMQ_COMMIT}"
git checkout "${ACTIVEMQ_COMMIT}"
DOCKER_BUILDKIT=0 docker build -t "alfresco/alfresco-activemq:${ACTIVEMQ_VERSION}-jre${jver}-rockylinux9" . --build-arg ACTIVEMQ_VERSION=${ACTIVEMQ_VERSION} --build-arg DISTRIB_NAME=rockylinux --build-arg DISTRIB_MAJOR=9 --build-arg JAVA_MAJOR="17" --build-arg JDIST=jre --no-cache
```

#### 3.8. Build Alfresco transform core

```bash
export TRANSFORM_CORE_VERSION="5.1.7"
cd "$SOURCE_ROOT"
git clone --depth 1 -b "${TRANSFORM_CORE_VERSION}" https://github.com/Alfresco/alfresco-transform-core.git
cd alfresco-transform-core
grep -RiIl 'jre17-rockylinux9@sha256' | xargs sed -i "s/jre17-rockylinux9@sha256.*/jre17-rockylinux9/g"
grep -RiIl '5.18.3-jre17-rockylinux8' | xargs sed -i "s/5.18.3-jre17-rockylinux8/${ACTIVEMQ_VERSION}-jre17-rockylinux9/g"
mvn clean install -pl '!engines/aio,!engines/pdfrenderer,!engines/tika,!engines/imagemagick,!engines/libreoffice' -Plocal,docker-it-setup -DskipTests=true
```

#### 3.9. Install qemu x86_64 emulator

```bash
export QEMU_VERSION="v7.1.0"
cd "$SOURCE_ROOT"
mkdir qemu
cd qemu
curl -sSL "${PATCH_URL}/qus-Dockerfile" > Dockerfile
curl -sSL "${PATCH_URL}/qus-configure-qemu.sh" > configure-qemu.sh 
curl -sSL "https://raw.githubusercontent.com/tonistiigi/binfmt/refs/heads/master/patches/preserve-argv0/0001-linux-user-default-to-preserve-argv0.patch" > linux-user-default-to-preserve-argv0.patch
curl -sSL "${PATCH_URL}/qus-register.sh" > register.sh
docker build -t "qus:${QEMU_VERSION}" --build-arg "QEMU_TAG=${QEMU_VERSION}" .
docker run --rm --privileged "qus:${QEMU_VERSION}"
```

#### 3.10. Build Alfresco content app

```bash
export CONTENT_APP_VERSION="6.0.0"
cd "$SOURCE_ROOT"
git clone --depth 1 -b "${CONTENT_APP_VERSION}" https://github.com/Alfresco/alfresco-content-app.git
cd alfresco-content-app/
docker run --rm -it --platform=linux/amd64 \
    --mount type=bind,source="${SOURCE_ROOT}",target=/src \
    amd64/node:20 \
    sh -c "cd /src/alfresco-content-app && npm install && npm run build.release"
sudo chown -R "$(id -u):$(id -g)" .
docker build -t "alfresco/alfresco-content-app:${CONTENT_APP_VERSION}" . --build-arg PROJECT_NAME=content-ce
```

#### 3.11. Pull Traefik and Postgres Images

```bash
docker pull postgres:14.4
docker pull traefik:3.1
```

### 4. Execute Test Suite (Optional)

Run a subset of tests that do not require a full Alfresco development environment to be setup.

```bash
cd "$SOURCE_ROOT/alfresco-community-repo"
mvn -B test -pl core,data-model -am -DfailIfNoTests=false
mvn -B test -pl "repository,mmt" -am "-Dtest=AllUnitTestsSuite,AllMmtUnitTestSuite" -DfailIfNoTests=false
cd "$SOURCE_ROOT/alfresco-transform-core"
mvn -U -Dmaven.wagon.http.pool=false clean test -DadditionalOption=-Xdoclint:none -Dmaven.javadoc.skip=true -Dparent.core.deploy.skip=true -Dtransformer.base.deploy.skip=true -Plocal,docker-it-setup,misc,pdf-renderer,tika
```
_*Note:*_ _The following test-case failures may be observed in alfresco-transform-core tests within the Misc module, on Rhel 8.x and SLES 15.6 distributions: `MiscTest.testNonAsciiRFC822ToText`, `MiscTest.testHTMLtoString`, `HtmlParserContentTransformerTest.testEncodingHandling`. These test-cases failures appear on intel as well._

### 5 Start Alfresco service

#### 5.1. Get Alfresco docker compose file

```bash
export ACS_DOCKER_COMPOSE_COMMIT="54f99daa658ba8822b845975ca56fd66336b49a8"
cd "$SOURCE_ROOT"
mkdir -p docker-compose-source
cd docker-compose-source
wget -O docker-compose.yml https://raw.githubusercontent.com/Alfresco/acs-deployment/${ACS_DOCKER_COMPOSE_COMMIT}/docker-compose/community-compose.yaml
```

_*Note:*_ _Some third party Alfresco transformers are not available on s390x. Please follow the steps given below to remove code relevant to these transformers and enable the available transformers._

```bash
sed -i '58,75d' docker-compose.yml
sed -i "/^  share:/i \\
transform-misc:\\
image: alfresco/alfresco-transform-misc:latest\\
mem_limit: 1536m\\
environment:\\
  JAVA_OPTS: \" -XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=80\"\\
ports:\\
  - \"8094:8090\"" docker-compose.yml
sed -i "128s|alfresco/alfresco-activemq:5.18-jre17-rockylinux8|alfresco/alfresco-activemq:${ACTIVEMQ_VERSION}-jre${jver}-rockylinux9|" docker-compose.yml
sed -i '155,170d' docker-compose.yml
sed -i '50s/timeout: 3s/timeout: 5s/' docker-compose.yml
```
#### 5.2. Get the Base Configuration Template
```bash
mkdir -p commons
cd commons
wget https://raw.githubusercontent.com/Alfresco/acs-deployment/${ACS_DOCKER_COMPOSE_COMMIT}/docker-compose/commons/base.yaml
```

#### 5.3. Start Alfresco

The Docker Compose plugin is required to start the alfresco docker-compose.yml script. Please ensure the docker-compose-plugin package is installed based on your distro.

```bash
cd $SOURCE_ROOT/docker-compose-source
docker compose up
```

### Reference:

- https://www.alfresco.com/
