#!/bin/bash

echo "========================================"
echo "Starting STCS Data Architecture Stack"
echo "========================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Stop any existing containers
echo "Stopping existing containers..."
docker-compose down

# Start the stack
echo "Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to initialize..."
sleep 10

# Check Trino
echo "Checking Trino status..."
until curl -s http://localhost:8080/v1/info > /dev/null 2>&1; do
    echo "Waiting for Trino to start..."
    sleep 5
done
echo "✓ Trino is running at http://localhost:8080"

# Check Cube.js
echo "Checking Cube.js status..."
until curl -s http://localhost:4000/cubejs-api/v1/meta > /dev/null 2>&1; do
    echo "Waiting for Cube.js to start..."
    sleep 5
done
echo "✓ Cube.js is running at http://localhost:4000"
echo "✓ Cube.js Dev Playground at http://localhost:3001"

echo ""
echo "========================================"
echo "Stack is ready!"
echo "========================================"
echo ""
echo "Service URLs:"
echo "  - Trino UI: http://localhost:8080"
echo "  - Cube.js API: http://localhost:4000"
echo "  - Cube.js Dev Playground: http://localhost:3001"
echo "  - Cube.js SQL API: localhost:15432"
echo ""
echo "Sigma Connection Details:"
echo "  Host: localhost"
echo "  Port: 15432"
echo "  Database: cube"
echo "  Username: cube"
echo "  Password: stcs-production-secret-2024"
echo ""
echo "To stop the stack, run: docker-compose down"
echo "To view logs, run: docker-compose logs -f [service-name]"
echo ""