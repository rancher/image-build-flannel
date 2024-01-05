SEVERITIES = HIGH,CRITICAL

UNAME_M = $(shell uname -m)
ARCH=
ifeq ($(UNAME_M), x86_64)
	ARCH=amd64
else ifeq ($(UNAME_M), aarch64)
	ARCH=arm64
else 
	ARCH=$(UNAME_M)
endif

BUILD_META=-build$(shell date +%Y%m%d)
ORG ?= rancher
PKG ?= github.com/flannel-io/flannel
SRC ?= github.com/flannel-io/flannel
TAG ?= v0.24.0$(BUILD_META)
K3S_ROOT_VERSION ?= v0.12.2

ifneq ($(DRONE_TAG),)
	TAG := $(DRONE_TAG)
endif

ifeq (,$(filter %$(BUILD_META),$(TAG)))
	$(error TAG needs to end with build metadata: $(BUILD_META))
endif

.PHONY: image-build
image-build:
	docker build \
		--pull \
		--build-arg ARCH=$(ARCH) \
		--build-arg PKG=$(PKG) \
		--build-arg SRC=$(SRC) \
		--build-arg TAG=$(TAG:$(BUILD_META)=) \
		--tag $(ORG)/hardened-flannel:$(TAG) \
		--tag $(ORG)/hardened-flannel:$(TAG)-$(ARCH) \
		--build-arg K3S_ROOT_VERSION=$(K3S_ROOT_VERSION) \
		.

.PHONY: image-push
image-push:
	docker push $(ORG)/hardened-flannel:$(TAG)-$(ARCH)

.PHONY: image-manifest
image-manifest:
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend \
		$(ORG)/hardened-flannel:$(TAG) \
		$(ORG)/hardened-flannel:$(TAG)-$(ARCH)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push \
		$(ORG)/hardened-flannel:$(TAG)

.PHONY: image-scan
image-scan:
	trivy image --severity $(SEVERITIES) --no-progress --ignore-unfixed $(ORG)/hardened-flannel:$(TAG)
