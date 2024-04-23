ARG BCI_IMAGE=registry.suse.com/bci/bci-base
ARG GO_IMAGE=rancher/hardened-build-base:v1.21.9b1
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx
FROM --platform=$TARGETPLATFORM ${BCI_IMAGE} as bci
FROM --platform=$TARGETPLATFORM ${GO_IMAGE} as builder
# setup required packages
COPY --from=xx / /
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN set -x && \
    apk --no-cache add \
    file \
    gcc \
    git \
    linux-headers \
    make
# setup the build
ARG K3S_ROOT_VERSION=v0.13.0
RUN xx-info env
RUN mkdir -p /opt/xtables/
RUN export ARCH=$(xx-info arch) &&\
    wget https://github.com/rancher/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-xtables-${ARCH}.tar -O /opt/xtables/k3s-root-xtables.tar
RUN tar xvf /opt/xtables/k3s-root-xtables.tar -C /opt/xtables
ARG TAG=v0.25.1
ARG PKG="github.com/flannel-io/flannel"
ARG SRC="github.com/flannel-io/flannel"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
# build and assert statically linked executable(s)
ENV GO_LDFLAGS="-X ${PKG}/version.Version=${TAG}"
RUN export GOOS=$(xx-info os) &&\
    export GOARCH=$(xx-info arch) &&\
    export ARCH=$(xx-info arch) &&\
    go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/flanneld .
RUN export GOOS=$(xx-info os) &&\
    export GOARCH=$(xx-info arch) &&\
    export ARCH=$(xx-info arch) &&\
    go-assert-static.sh bin/*
RUN if [ "$(xx-info arch)" = "amd64" ]; then \
        go-assert-boring.sh bin/* ; \
    fi
RUN install -s bin/* /usr/local/bin
RUN flanneld --version

FROM bci
RUN zypper install -y which gawk strongswan && \
    zypper clean -a
COPY --from=builder /opt/xtables/bin/ /usr/sbin/
COPY --from=builder /usr/local/bin/ /opt/bin/
