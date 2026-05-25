# Copyright The Helm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BINDIR      := $(CURDIR)/bin
DISTDIR     := $(CURDIR)/_dist
CHARTSDIR   := $(CURDIR)/charts
GO          := go
HELM_BIN    := helm

# Versioning
GIT_COMMIT  := $(shell git rev-parse HEAD 2>/dev/null)
GIT_TAG     := $(shell git describe --tags --abbrev=0 2>/dev/null)
GIT_DIRTY   := $(shell test -n "`git status --porcelain`" && echo "-dirty" || echo "")
GIT_VERSION := $(GIT_TAG)$(GIT_DIRTY)
BUILD_DATE  := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# Go build flags
LDFLAGS := -w -s \
	-X 'helm.sh/helm/v3/internal/version.version=$(GIT_VERSION)' \
	-X 'helm.sh/helm/v3/internal/version.gitCommit=$(GIT_COMMIT)' \
	-X 'helm.sh/helm/v3/internal/version.gitTreeState=$(GIT_DIRTY)' \
	-X 'helm.sh/helm/v3/internal/version.buildDate=$(BUILD_DATE)'

GOFLAGS    := -trimpath
GOBINFLAGS :=

# Use all available CPUs for tests to speed things up locally
# Removed the cap at 4 - modern laptops handle 8 threads fine with better cooling
TEST_PARALLELISM := $(shell nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
TEST_FLAGS := -p $(TEST_PARALLELISM)

.PHONY: all
all: build

# Build the helm binary
.PHONY: build
build:
	@echo "Building helm..."
	$(GO) build $(GOFLAGS) -ldflags '$(LDFLAGS)' -o $(BINDIR)/$(HELM_BIN) ./cmd/helm

# Run all tests
.PHONY: test
test: build
	@echo "Running tests..."
	$(GO) test $(GOFLAGS) $(TEST_FLAGS) ./...

# Run tests with race detector
.PHONY: test-race
test-race: build
	$(GO) test -race $(GOFLAGS) $(TEST_FLAGS) ./...

# Run linter
.PHONY: lint
lint:
	@echo "Running golangci-lint..."
	golangci-lint run ./...

# Format code
.PHONY: fmt
fmt:
	$(GO) fmt ./...

# Tidy go modules
.PHONY: tidy
tidy:
	$(GO) mod tidy

# Build release artifacts for all platforms
.PHONY: build-cross
build-cross: LDFLAGS += -extldflags "-static"
build-cross:
	@echo "Building cross-platform binaries..."
	GOOS=linux   GOARCH=amd64  $(GO) build $(GOFLAGS) -ldflags '$(LDFLAGS)' -o $(DISTDIR)/helm-linux-amd64/helm   ./cmd/helm
	GOOS=linux   GOARCH=arm64  $(GO) build $(GOFLAGS) -ldflags '$(LDFLAGS)' -o $(DISTDIR)/helm-linux-arm64/helm   ./cmd/helm
	GOOS=darwin  GOARCH=amd64  $(GO) build $(GOFLAGS) -ldflags '$(LDFLAGS)' -o $(DISTDIR)/helm-darwin-amd64/helm  ./cmd/helm
	GOOS=darwin  GOARCH=arm64  $(GO) build $(GOFLAGS) -ldflags '$(LDFLAGS)' -o $(DISTDIR)/helm-darwin-arm64/helm  ./cmd/helm
	GOOS=windows GOARCH=amd64  $(GO) build $(GOFLAGS) -ldflags '$(LDFLA
