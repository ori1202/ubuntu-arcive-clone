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

echo "Installing Ubuntu keyring and importing keys for aptly..."
apt-get install -y ubuntu-keyring gnupg
gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg --export | gpg --no-default-keyring --keyring trustedkeys.gpg --import

echo "Creating universe filtered mirror..."

# Migrate old mirror name if present
if aptly mirror show universe-nodejs > /dev/null 2>&1; then
    echo "Renaming old mirror 'universe-nodejs' to 'universe-filtered'..."
    aptly mirror rename universe-nodejs universe-filtered
fi

if ! aptly mirror show universe-filtered > /dev/null 2>&1; then
    aptly mirror create \
        -architectures=amd64 \
        -filter='nodejs | npm | libnode-dev | libnode72 | python3 | python3-pip | python3-venv | python3-dev | jq | tmux | httpie | git-extras | tcpdump | nmap | netcat | cargo | rustc | rustup' \
        -filter-with-deps \
        universe-filtered \
        https://ubuntu-archive.interhost.co.il/ubuntu \
        focal universe
else
    echo "Mirror 'universe-filtered' already exists, skipping creation."
fi

echo "Updating mirror (this may take a while)..."
aptly mirror update universe-filtered

echo "Creating snapshot..."

# Always drop and recreate so the snapshot reflects the latest mirror state
if aptly snapshot show universe-filtered-snapshot > /dev/null 2>&1; then
    echo "Dropping old snapshot 'universe-filtered-snapshot'..."
    aptly snapshot drop universe-filtered-snapshot
fi
aptly snapshot create universe-filtered-snapshot from mirror universe-filtered

echo "Publishing snapshot (without signing)..."

if aptly publish show focal-universe focal-universe-arm64-filtered-snapshot > /dev/null 2>&1; then
    echo "Switching published snapshot to latest..."
    aptly publish switch -skip-signing focal-universe focal-universe-arm64-filtered-snapshot universe-filtered-snapshot
else
    aptly publish snapshot -skip-signing \
        -distribution=focal-universe \
        universe-filtered-snapshot \
        focal-universe-arm64-filtered-snapshot
fi

echo "Done!"
