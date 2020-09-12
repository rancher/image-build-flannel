SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/hardened-flannel:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/hardened-flannel:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/hardened-flannel:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/hardened-flannel:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/hardened-flannel:$(TAG) \
		$(shell docker image inspect rancher/hardened-flannel:$(TAG) | jq -r '.[] | .RepoDigests[0]')
