# todome - build/install the terminal todo tracker.
BIN ?= $(HOME)/.local/bin/todome

.PHONY: build install test tidy run clean

build:
	go build -o todome .

install:
	go build -o "$(BIN)" .
	@echo "installed $(BIN)"

test:
	go test ./...

tidy:
	go mod tidy

run:
	go run .

clean:
	rm -f todome
