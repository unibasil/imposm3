.PHONY: test all build clean test test-system test-unit update_version docs

PROTOFILES=$(shell find . -name \*.proto | grep -v vendor/ )
PBGOFILES=$(patsubst %.proto,%.pb.go,$(PROTOFILES))
GOFILES=$(shell find . \( -name \*.go ! -name version.go \) | grep -v .pb.go )

# for protoc-gen-go
export PATH := $(GOPATH)/bin:$(PATH)

GOLDFLAGS=-ldflags '-r $${ORIGIN}/lib $(VERSION_LDFLAGS)'

GO:=go

ifdef LEVELDB_POST_121
GOTAGS=-tags="ldbpost121"
endif

BUILD_DATE=$(shell date +%Y%m%d)
BUILD_REV=$(shell git rev-parse --short HEAD)
ifndef IMPOSM_BUILD_RELEASE
BUILD_VERSION=dev-$(BUILD_DATE)-$(BUILD_REV)
endif
VERSION_LDFLAGS=-X github.com/unibasil/imposm3.buildVersion=$(BUILD_VERSION)

all: build test

imposm3: $(PBGOFILES) $(GOFILES)
	$(GO) build $(GOTAGS) $(GOLDFLAGS) ./cmd/imposm3

build: imposm3

clean:
	rm -f imposm3
	(cd test && make clean)

test: imposm3 system-test-files
	$(GO) test $(GOTAGS) -i `$(GO) list ./... | grep -Ev '/vendor'`
	$(GO) test $(GOTAGS) `$(GO) list ./... | grep -Ev '/vendor'`

test-unit: imposm3
	$(GO) test $(GOTAGS) -i `$(GO) list ./... | grep -Ev '/test|/vendor'`
	$(GO) test $(GOTAGS) `$(GO) list ./... | grep -Ev '/test|/vendor'`

test-system: imposm3
	(cd test && make test)

system-test-files:
	(cd test && make files)

%.pb.go: %.proto
	protoc --proto_path=$(GOPATH)/src:$(GOPATH)/src/github.com/unibasil/imposm3/vendor/github.com/gogo/protobuf/protobuf:. --gogofaster_out=. $^

docs:
	(cd docs && make html)

REMOTE_DOC_LOCATION = omniscale.de:/opt/www/imposm.org/docs/imposm3
DOC_VERSION = 3.0.0

upload-docs: docs
	rsync -a -v -P -z docs/_build/html/ $(REMOTE_DOC_LOCATION)/$(DOC_VERSION)


build-license-deps:
	rm LICENSE.deps
	find ./vendor -iname license\* -exec bash -c '\
		dep=$${1#./vendor/}; \
		(echo -e "========== $$dep ==========\n"; cat $$1; echo -e "\n\n") \
		| fold -s -w 80 \
		>> LICENSE.deps \
	' _ {} \;



comma:= ,
empty:=
space:= $(empty) $(empty)
COVER_IGNORE:='/vendor|/cmd'
COVER_PACKAGES:= $(shell $(GO) list ./... | grep -Ev $(COVER_IGNORE))
COVER_PACKAGES_LIST:=$(subst $(space),$(comma),$(COVER_PACKAGES))

test-coverage:
	mkdir -p .coverprofile
	rm -f .coverprofile/*
	$(GO) list -f '{{if gt (len .TestGoFiles) 0}}"$(GO) test -covermode count -coverprofile ./.coverprofile/{{.Name}}-$$$$.coverprofile -coverpkg $(COVER_PACKAGES_LIST) {{.ImportPath}}"{{end}}' ./... \
		| grep -Ev $(COVER_IGNORE) \
		| xargs -n 1 bash -c
	$(GOPATH)/bin/gocovmerge .coverprofile/*.coverprofile > overalls.coverprofile
	rm -rf .coverprofile

test-coverage-html: test-coverage
	$(GO) tool cover -html overalls.coverprofile

