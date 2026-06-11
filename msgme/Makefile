BIN := msgme
PREFIX ?= $(HOME)/.local
INSTALL_DIR := $(PREFIX)/bin

.PHONY: build install test vet run clean

build:
	go build -o ./bin/$(BIN) .

install: build
	mkdir -p $(INSTALL_DIR)
	install -m 0755 ./bin/$(BIN) $(INSTALL_DIR)/$(BIN)
	@echo "installed $(INSTALL_DIR)/$(BIN)  (ensure $(INSTALL_DIR) is on your PATH)"

test:
	go test ./...

vet:
	go vet ./...

run: build
	./bin/$(BIN)

clean:
	rm -rf ./bin
