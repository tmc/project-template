# This non-hermetic Makefile installs core dependencies such as bazel

UNAME ?= $(shell uname -s)
BAZEL ?= $(shell which bazel)
IMAGE ?= project_foo
CACHEDIR ?= .cache

.PHONY: all
all: ci

.PHONY: deps
ifeq ($(UNAME),Darwin)
deps: deps-darwin
endif
ifeq ($(UNAME),Linux)
deps: deps-linux
endif

.PHONY: deps-common
deps-common: deps-bazel

.PHONY: deps-darwin
deps-darwin: deps-common

.PHONY: deps-linux
deps-linux: deps-common
	apt-get install -y build-essential curl unzip


.PHONY: deps-bazel
ifeq "$(BAZEL)" ""
# default to bazel22
deps-bazel: deps-bazel22
else
deps-bazel:
	@echo '[deps-bazel] Bazel already present.'
endif

.PHONY: ci
ci: build test

.PHONY: build
build:
	bazel build //...

.PHONY: test
test:
	bazel test //...

.PHONY: lint
lint:
	bazel run //tools:lint

.PHONY: lintfix
lintfix:
	bazel run //tools:lintfix

.PHONY: linux-ci-image
linux-ci-image: dockerfiles/Dockerfile
	docker build -t ${IMAGE} -f dockerfiles/Dockerfile .

.PHONY: linux-ci-from-host
linux-ci-from-host: linux-ci-image
	docker run \
		-v $(shell pwd):/app \
		-e CACHEDIR=.cache-linux \
		-ti ${IMAGE} make deps ci

.PHONY: linux-ci-from-host-shell
linux-ci-from-host-shell: linux-ci-image
	docker run \
		-v $(shell pwd):/app \
		-e CACHEDIR=.cache-linux \
		-ti ${IMAGE} bash

# requires https://github.com/buildkite/cli
.PHONY: mac-ci-from-host
mac-ci-from-host:
	bk run local

# requires https://circleci.com/docs/2.0/local-cli
.PHONY: circle-ci-from-host
circle-ci-from-host:
	circleci local execute --job build-and-test

# tests with upcoming backwards-compatible changes enabled (https://docs.bazel.build/versions/master/skylark/backward-compatibility.html)
.PHONY: test-upcoming-bazel-changes
test-upcoming-bazel-changes:
	bazel build //... --all_incompatible_changes
	bazel test //... --all_incompatible_changes

.PHONY: deps-bazel22
deps-bazel22: ${CACHEDIR}/bazel-installer-22.sh
	$^ --user

${CACHEDIR}/bazel-installer-22.sh:
ifeq ($(UNAME),Darwin)
	curl -L -o $@ https://github.com/bazelbuild/bazel/releases/download/0.22.0/bazel-0.22.0-installer-darwin-x86_64.sh
	chmod +x $@
endif
ifeq ($(UNAME),Linux)
	curl -L -o $@ https://github.com/bazelbuild/bazel/releases/download/0.22.0/bazel-0.22.0-installer-linux-x86_64.sh
	chmod +x $@
endif

