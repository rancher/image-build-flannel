ARG UBI_IMAGE=registry.access.redhat.com/ubi7/ubi-minimal:latest
ARG GO_IMAGE=rancher/hardened-build-base:v1.14.2-amd64

FROM ${UBI_IMAGE} as ubi

FROM ${GO_IMAGE} as builder
ARG TAG="" 
ARG K3S_ROOT_VERSION=v0.6.0-rc3
RUN apt update     && \ 
    apt upgrade -y && \ 
    apt install -y ca-certificates git

RUN mkdir -p /tmp/xtables && \
    curl -L https://github.com/rancher/k3s-root/releases/download/${K3S_ROOT_VERSION}/k3s-root-xtables-amd64.tar -o /tmp/xtables/k3s-root-xtables.tar && \
    tar -C /tmp/xtables -xvf /tmp/xtables/k3s-root-xtables.tar

RUN git clone --depth=1 https://github.com/rancher/flannel.git /go/src/github.com/rancher/flannel
RUN cd /go/src/github.com/rancher/flannel && \
    git fetch --all --tags --prune       && \
    git checkout tags/${TAG} -b ${TAG}   && \
    make dist/flanneld

FROM ubi
RUN microdnf update -y          && \
    microdnf install -y yum     && \
    yum install -y ca-certificates \
    strongswan net-tools which  && \
    rm -rf /var/cache/yum       && \
    mkdir -p /opt/bin

COPY --from=builder /tmp/xtables/bin/* /usr/sbin/

COPY --from=builder /go/src/github.com/rancher/flannel/dist/flanneld /opt/bin

