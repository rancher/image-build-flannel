ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.15.2b5
FROM ${UBI_IMAGE} as ubi
FROM ${GO_IMAGE} as builder
# setup required packages
RUN set -x \
 && apk --no-cache add \
    file \
    gcc \
    git \
    linux-headers \
    make
# setup the build
ARG ARCH="amd64"
ARG K3S_ROOT_VERSION="v0.6.0-rc3"
ADD https://github.com/rancher/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-xtables-${ARCH}.tar /opt/xtables/k3s-root-xtables.tar
RUN tar xvf /opt/xtables/k3s-root-xtables.tar -C /opt/xtables
ARG TAG="v0.13.0-rancher1"
ARG PKG="github.com/coreos/flannel"
ARG SRC="github.com/rancher/flannel"
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune
RUN git checkout tags/${TAG} -b ${TAG}
RUN echo 'GO_BUILD_FLAGS=" \
         -gcflags=-trimpath=/go/src \
         "' \
    >> ./go-build-static
RUN echo 'GO_LDFLAGS=" \
         -X ${PKG}/version.Version=${TAG} \
         -linkmode=external -extldflags \"-static -Wl,--fatal-warnings\""' \
    >> ./go-build-static
RUN echo 'go build ${GO_BUILD_FLAGS} -ldflags "${GO_LDFLAGS}" "${@}"' \
    >> ./go-build-static
## build statically linked executables
RUN sh -ex ./go-build-static -o bin/flanneld .
# assert statically linked executables
RUN echo '[ -e $1 ] && (file $1 | grep -E "executable, x86-64, .*, statically linked")' \
    >> ./assert-static
RUN sh -ex ./assert-static bin/flanneld
RUN ./bin/flanneld --version
# assert goboring symbols
RUN echo '[ -e $1 ] && (go tool nm $1 | grep Cfunc__goboring > .boring; if [ $(wc -l <.boring) -eq 0 ]; then exit 1; fi)' \
    >> ./assert-boring
RUN sh -ex ./assert-boring bin/flanneld
# install (with strip) to /usr/local/bin
RUN install -s bin/* /usr/local/bin

FROM ubi
RUN microdnf update -y          && \
    microdnf install -y yum     && \
    yum install -y ca-certificates \
    strongswan net-tools which  && \
    rm -rf /var/cache/yum
COPY --from=builder /opt/xtables/bin/ /usr/sbin/
COPY --from=builder /usr/local/bin/ /opt/bin/
