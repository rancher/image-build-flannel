SEVERITIES = HIGH,CRITICAL

.PHONY: all
all:
	docker build --build-arg TAG=$(TAG) -t ranchertest/flannel:$(TAG) .

.PHONY: image-push
image-push:
	docker push ranchertest/flannel:$(TAG) >> /dev/null

.PHONY: scan
image-scan:
	trivy --severity $(SEVERITIES) --no-progress --skip-update --ignore-unfixed ranchertest/flannel:$(TAG)

.PHONY: image-manifest
image-manifest:
	docker image inspect ranchertest/flannel:$(TAG)
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create ranchertest/flannel:$(TAG) \
		$(shell docker image inspect ranchertest/flannel:$(TAG) | jq -r '.[] | .RepoDigests[0]')
