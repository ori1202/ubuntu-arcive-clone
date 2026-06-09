#!/bin/bash
set -e

echo "Updating package lists and installing prerequisites..."
apt-get update
apt-get install -y wget gnupg2

echo "Adding aptly repository key..."
mkdir -p /etc/apt/keyrings
chmod 755 /etc/apt/keyrings
wget -O /etc/apt/keyrings/aptly.asc https://www.aptly.info/pubkey.txt
echo "deb [signed-by=/etc/apt/keyrings/aptly.asc] http://repo.aptly.info/release focal main" > /etc/apt/sources.list.d/aptly.list

echo "Installing aptly..."
apt-get update
apt-get install -y aptly

echo "Creating Docker mirrors..."

if ! aptly mirror show docker-focal-amd64 > /dev/null 2>&1; then
    aptly mirror create \
        -ignore-signatures \
        -architectures=amd64 \
        docker-focal-amd64 \
        https://download.docker.com/linux/ubuntu \
        focal stable
else
    echo "Mirror 'docker-focal-amd64' already exists, skipping creation."
fi

if ! aptly mirror show docker-focal-arm64 > /dev/null 2>&1; then
    aptly mirror create \
        -ignore-signatures \
        -architectures=arm64 \
        docker-focal-arm64 \
        https://download.docker.com/linux/ubuntu \
        focal stable
else
    echo "Mirror 'docker-focal-arm64' already exists, skipping creation."
fi

echo "Updating mirrors (this may take a while)..."
aptly mirror update -ignore-signatures docker-focal-amd64
aptly mirror update -ignore-signatures docker-focal-arm64

echo "Creating snapshots..."

if ! aptly snapshot show docker-focal-amd64-snapshot > /dev/null 2>&1; then
    aptly snapshot create docker-focal-amd64-snapshot from mirror docker-focal-amd64
else
    echo "Snapshot 'docker-focal-amd64-snapshot' already exists, skipping creation."
fi

if ! aptly snapshot show docker-focal-arm64-snapshot > /dev/null 2>&1; then
    aptly snapshot create docker-focal-arm64-snapshot from mirror docker-focal-arm64
else
    echo "Snapshot 'docker-focal-arm64-snapshot' already exists, skipping creation."
fi

echo "Publishing snapshots (without signing)..."

if ! aptly publish show focal download.docker.com > /dev/null 2>&1; then
    aptly publish snapshot -skip-signing \
        -distribution=focal \
        docker-focal-amd64-snapshot \
        docker-focal-arm64-snapshot
else
    echo "Docker focal snapshots already published, skipping."
fi

echo "Done!"
