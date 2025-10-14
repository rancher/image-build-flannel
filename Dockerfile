ARG BCI_IMAGE=registry.suse.com/bci/bci-busybox:15.7
ARG GO_IMAGE=rancher/hardened-build-base:v1.24.9b1
ARG XX_IMAGE=rancher/mirrored-tonistiigi-xx:1.6.1

FROM --platform=$BUILDPLATFORM ${XX_IMAGE} AS xx
FROM ${BCI_IMAGE} AS bci

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# setup required packages
COPY --from=xx / /
RUN apk add file make git clang lld patch linux-headers
ARG TARGETPLATFORM
RUN set -x && \
    apk --no-cache add \
    gcc \
    musl-dev

FROM --platform=$BUILDPLATFORM base-builder AS builder
# setup the build
ARG K3S_ROOT_VERSION=v0.15.0
ARG TAG=v0.27.4
ARG PKG="github.com/flannel-io/flannel"
ARG SRC="github.com/flannel-io/flannel"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod download
ARG TARGETARCH
ARG TARGETOS
# build and assert statically linked executable(s)
ENV GO_LDFLAGS="-X ${PKG}/version.Version=${TAG}"
RUN export GOOS=${TARGETOS} &&\
    export GOARCH=${TARGETARCH} &&\
    export ARCH=${TARGETARCH} && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/flanneld .; \
    else \
        # flannel doesn't compile with CGO_ENABLED=1 when the arch is not amd64
        CGO_ENABLED=0  go build -ldflags "-extldflags \"-static -Wl,--fatal-warnings\" ${GO_LDFLAGS}" -gcflags=-trimpath=${GOPATH}/src -o bin/flanneld .; \
    fi
RUN export GOOS=${TARGETOS}} &&\
    export GOARCH=${TARGETARCH} &&\
    export ARCH=${TARGETARCH} &&\
    go-assert-static.sh bin/*
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        go-assert-boring.sh bin/* ; \
    fi

# Get xtables files from k3s-root
RUN mkdir -p /opt/xtables/
ADD https://github.com/k3s-io/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-${TARGETARCH}.tar /opt/k3s-root/k3s-root.tar
# exclude 'mount' and 'modprobe' when unpacking the archive
RUN tar xvf /opt/k3s-root/k3s-root.tar -C /opt/xtables --strip-components=3 --exclude=./bin/aux/mo* './bin/aux/'
RUN ls /opt/xtables

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=builder /go/src/github.com/flannel-io/flannel/bin/flanneld /flanneld
RUN strip /flanneld

FROM bci
COPY --from=builder /opt/xtables/ /usr/sbin/
COPY --from=strip_binary /flanneld /opt/bin/
