# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

.EXPORT_ALL_VARIABLES:
export GO111MODULE=on

DOCKER_REPO=quay.io/pmackay
DOMAIN=domain
APP_NAME=app
NAMESPACE=$(DOMAIN)--$(APP_NAME)

KUBECONFIG ?= $(PWD)/.kube/config

VERSIONFILE=$(PWD)/Version
VERSION = $(shell cat $(VERSIONFILE))
BASE_DEPLOYMENT = $(PWD)/deploy/base/deployment.yaml
BRANCH_NAME ?= $(shell git branch | grep '*' | awk '{print $$2}')

.PHONY: help clean test fmt vet lint run build version check

GO_SOURCES	:=$(shell go list -f '{{ range $$element := .GoFiles }}{{ $$.Dir }}/{{ $$element }}{{ "\n" }}{{ end }}' ./...)

CGO_ENABLED := 0

SYSTEM:=$(shell uname)
ifeq ($(SYSTEM), Darwin)
BUILD_DATE	:=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GOOS := darwin
else
BUILD_DATE	:=$(shell date --iso-8601=seconds --utc)
GOOS := linux
endif

META_PACKAGE_IMPORT_PATH := $(shell go list -f '{{ .ImportPath }}' ./meta)
GO_FLAGS	:="-ldflags -X $(META_PACKAGE_IMPORT_PATH).Version=$(VERSION) -X $(META_PACKAGE_IMPORT_PATH).BuildTime=$(BUILD_DATE)"

all: deps build 


build: test $(GO_SOURCES) ## Build the app binary
	@touch meta/meta.go
	@go build $(GO_FLAGS) -o build/$(BINARY_NAME) ./...
	
test: fmt check $(GO_SOURCES)
	@go test ./...

fmt: $(GO_SOURCES)
ifneq ($(shell gofmt -d -l .),)
	@echo "Please run 'gofmt -w .'"
	@gofmt -d -l . && exit 1
endif

check: vet lint

deps: ## Get dependencies
	@go build -v ./...

vet: $(GO_SOURCES)
	@go vet ./...

lint: $(GO_SOURCES)
	@golint -set_exit_status=1  ./...

.PHONY: tidy
tidy:   ## Update go.mod and go.sum
	@go mod tidy

.PHONY: prepare-commit
prepare-commit: tidy build tests ## Update dependencies, build and run tests and then format the code just in case
	@go fmt ./... ## Format go code

# DOCKER TASKS
# Build the container
docker-build: ## Build the container
	@docker build --build_arg GO_FLAGS=$(GO_FLAGS) -t $(DOCKER_REPO)/$(APP_NAME) ./...

run: ## Run container
	@docker run -i -t --rm --name="$(APP_NAME)" -p 8080:8080 -p 6565:6565 $(DOCKER_REPO)/$(APP_NAME)

stop: ## Stop and remove a running container
	@docker stop $(DOCKER_REPO)/$(APP_NAME); docker rm $(DOCKER_REPO)/$(APP_NAME)

release: update-version build publish ## Make a release by building and publishing the `{version}`

# Docker publish
publish: tag-version ## Publish the `{version}` tag
	@echo 'publish $(APP_NAME):$(VERSION) to $(DOCKER_REPO)'
	@docker push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

update-version:
	@echo "Updating $$(cat $(VERSIONFILE))..."
	@echo `version=$$(cat $(VERSIONFILE)) && echo $$version | sed 's/\(.*-\).*/\1'$$(($$(echo $$version | sed 's/.*-\(.*\)/\1/g') + 1))'/g'` > $(VERSIONFILE)
	@echo "New Version: $$(cat $(VERSIONFILE))"
	@echo `new_version=$$(cat $(VERSIONFILE)) && \
				old_version=$$(cat $(BASE_DEPLOYMENT) | grep image: | cut -d: -f3 | sed 's/[^0-9]*\(.*\)/\1/g') && \
				sed -i "s/$$old_version/$$new_version/g" $(BASE_DEPLOYMENT) > /dev/null 2>&1`
	@echo `new_version=$$(cat $(VERSIONFILE)) && \
	       old_version=$$(cat $(BASE_DEPLOYMENT) | grep image: | cut -d: -f3 | sed 's/[^0-9]*\(.*\)/\1/g') && \
		   if [ $${old_version} != $${new_version} ]; then \
			sed -i '' "s/$$old_version/$$new_version/g" $(BASE_DEPLOYMENT) > /dev/null 2>&1;\
		   fi`
	@echo "New Deployment Image Version: $$(cat $(BASE_DEPLOYMENT) | grep image:  | cut -d: -f3 | sed 's/[^0-9]*\(.*\)/\1/g')"

# Docker tagging
tag-version: ## Create the tag for this version
	@echo 'create tag $(APP_NAME):$(VERSION)'
	@docker tag $(DOCKER_REPO)/$(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

deploy-dev: release ## Deploy to k8s dev
	@echo 'Deploying to Dev'
	# need to change kubectl config
	@kustomize build deploy/base | kubectl --cluster=dev apply -f -

deploy-stage: release ## Deploy to k8s stage
	@echo	'Deploying to Stage'
	# need to change kubectl config
	@kustomize build deploy/overlays/stage | kubectl --cluster=stage apply -f -

deploy-prod: release ## Deploy to k8s prod
	@echo 'Deploying to Production'
	# need to change kubectl config
	@kustomize build deploy/overlays/production | kubectl --cluster=prod apply -f -

clean: ## Cleanup and remove image and any containers created
	@echo 'cleaning all images and containers'
	@go clean
	@rm -f build/$(BINARY_NAME)

	# use - to not fail if these command error out because there aren't any images or containers
	-docker rm $(DOCKER_REPO)/$(APP_NAME)
	-docker rm $(DOCKER_REPO)/$(APP_NAME):$(VERSION)
	-docker rmi $(DOCKER_REPO)/$(APP_NAME) --force
	-docker rmi $(DOCKER_REPO)/$(APP_NAME):$(VERSION) --force

	@bazel clean --expunge

version: ## Output the current version
	@echo $(VERSION)
	
