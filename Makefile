SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t rancher/flannel:$(TAG) .

.PHONY: image-push
image-push:
	docker push rancher/flannel:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed rancher/flannel:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect rancher/flannel:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create rancher/flannel:$(TAG) \
		$(shell docker image inspect rancher/flannel:$(TAG) | jq -r '.[] | .RepoDigests[0]')
