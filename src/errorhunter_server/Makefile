.PHONY: build run test clean docker-build docker-run lint fmt deps

# Variables
APP_NAME := errorhunter-server
BUILD_DIR := ./bin
MAIN_FILE := ./cmd/server/main.go
CONFIG_FILE := ./configs/config.yaml

# Build
build:
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	go build -ldflags="-w -s" -o $(BUILD_DIR)/$(APP_NAME) $(MAIN_FILE)
	@echo "Build complete: $(BUILD_DIR)/$(APP_NAME)"

# Run
run: build
	@echo "Running $(APP_NAME)..."
	CONFIG_PATH=$(CONFIG_FILE) $(BUILD_DIR)/$(APP_NAME)

# Run with hot reload (requires air: go install github.com/cosmtrek/air@latest)
dev:
	air

# Test
test:
	@echo "Running tests..."
	go test -v -race -cover ./...

test-coverage:
	@echo "Running tests with coverage..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Clean
clean:
	@echo "Cleaning..."
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html

# Docker
docker-build:
	@echo "Building Docker image..."
	docker build -t $(APP_NAME):latest .

docker-run:
	@echo "Running with docker-compose..."
	docker-compose -f docker-compose.dev.yml up -d

docker-stop:
	docker-compose -f docker-compose.dev.yml down

docker-logs:
	docker-compose -f docker-compose.dev.yml logs -f server

# Code quality
lint:
	@echo "Running linter..."
	golangci-lint run ./...

fmt:
	@echo "Formatting code..."
	go fmt ./...
	goimports -w .

# Dependencies
deps:
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy

deps-update:
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy

# Database
db-migrate:
	@echo "Running database migrations..."
	# TODO: Add migration tool

# Generate
generate:
	@echo "Generating code..."
	go generate ./...

# Help
help:
	@echo "Available targets:"
	@echo "  build          - Build the application"
	@echo "  run            - Build and run the application"
	@echo "  dev            - Run with hot reload (requires air)"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo "  clean          - Clean build artifacts"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-run     - Run with docker-compose"
	@echo "  docker-stop    - Stop docker containers"
	@echo "  docker-logs    - View server logs"
	@echo "  lint           - Run linter"
	@echo "  fmt            - Format code"
	@echo "  deps           - Download dependencies"
	@echo "  deps-update    - Update dependencies"
	@echo "  help           - Show this help"
