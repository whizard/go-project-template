# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help


DOCKER_REPO=quay.io/pmackay
APP_NAME=appDb

VERSIONFILE=$(PWD)/Version
VERSION=`cat $(VERSIONFILE)`

# DOCKER TASKS
# Build the container
build: ## Build the container
	-cp ../platform.sql .
	docker build -t $(DOCKER_REPO)/$(APP_NAME) .
	-rm ./platform.sql

run: ## Run container
	docker run -i -t --rm --env-file=./config.env -p=$(PORT):$(CONTAINER_PORT) --name="$(APP_NAME)" $(DOCKER_REPO)/$(APP_NAME)

stop: ## Stop and remove a running container
	docker stop $(APP_NAME); docker rm $(APP_NAME)

clean: ## Cleanup and remove image and any containers created
	@echo 'cleaning all images and containers'
	-docker rm $(DOCKER_REPO)/$(APP_NAME) --force
	-docker rm $(DOCKER_REPO)/$(APP_NAME):$(VERSION)  --force
	-docker rm $(DOCKER_REPO)/$(APP_NAME):latest --force
	-docker rmi $(DOCKER_REPO)/$(APP_NAME) --force
	-docker rmi $(DOCKER_REPO)/$(APP_NAME):$(VERSION) --force
	-docker rmi $(DOCKER_REPO)/$(APP_NAME):latest --force

version: ## Output the current version
	@echo $(VERSION)
	
