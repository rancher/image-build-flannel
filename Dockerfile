ARG BCI_IMAGE=registry.suse.com/bci/bci-busybox:15.7
ARG GO_IMAGE=rancher/hardened-build-base:v1.23.12b1
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
ARG K3S_ROOT_VERSION=v0.14.1
ARG TAG=v0.27.2
ARG PKG="github.com/flannel-io/flannel"
ARG SRC="github.com/flannel-io/flannel"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN go mod download
ARG TARGETPLATFORM
# build and assert statically linked executable(s)
ENV GO_LDFLAGS="-X ${PKG}/version.Version=${TAG}"
RUN export GOOS=$(xx-info os) &&\
    export GOARCH=$(xx-info arch) &&\
    export ARCH=$(xx-info arch) && \
    if [ "$(xx-info arch)" = "amd64" ]; then \
        go-build-static.sh -gcflags=-trimpath=${GOPATH}/src -o bin/flanneld .; \
    else \
        # flannel doesn't compile with CGO_ENABLED=1 when the arch is not amd64
        CGO_ENABLED=0  go build -ldflags "-extldflags \"-static -Wl,--fatal-warnings\" ${GO_LDFLAGS}" -gcflags=-trimpath=${GOPATH}/src -o bin/flanneld .; \
    fi
RUN export GOOS=$(xx-info os) &&\
    export GOARCH=$(xx-info arch) &&\
    export ARCH=$(xx-info arch) &&\
    go-assert-static.sh bin/*
RUN if [ "$(xx-info arch)" = "amd64" ]; then \
        go-assert-boring.sh bin/* ; \
    fi

# Get xtables files from k3s-root
RUN mkdir -p /opt/xtables/
RUN export ARCH=$(xx-info arch) &&\
    wget https://github.com/rancher/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-xtables-${ARCH}.tar -O /opt/xtables/k3s-root-xtables.tar
RUN tar xvf /opt/xtables/k3s-root-xtables.tar -C /opt/xtables

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=builder /go/src/github.com/flannel-io/flannel/bin/flanneld /flanneld
RUN strip /flanneld

FROM bci
COPY --from=builder /opt/xtables/bin/ /usr/sbin/
COPY --from=strip_binary /flanneld /opt/bin/
