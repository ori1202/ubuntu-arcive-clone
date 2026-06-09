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

echo "Creating universe nodejs mirror..."

if ! aptly mirror show universe-nodejs > /dev/null 2>&1; then
    aptly mirror create \
        -architectures=amd64 \
        -filter='nodejs | npm | libnode-dev | libnode72' \
        -filter-with-deps \
        universe-nodejs \
        https://ubuntu-archive.interhost.co.il/ubuntu \
        focal universe
else
    echo "Mirror 'universe-nodejs' already exists, skipping creation."
fi

echo "Updating mirror (this may take a while)..."
aptly mirror update universe-nodejs

echo "Creating snapshot..."

if ! aptly snapshot show universe-nodejs-snapshot > /dev/null 2>&1; then
    aptly snapshot create universe-nodejs-snapshot from mirror universe-nodejs
else
    echo "Snapshot 'universe-nodejs-snapshot' already exists, skipping creation."
fi

echo "Publishing snapshot (without signing)..."

if ! aptly publish show focal-universe universe-filtered > /dev/null 2>&1; then
    aptly publish snapshot -skip-signing \
        -distribution=focal-universe \
        universe-nodejs-snapshot \
        universe-filtered
else
    echo "Snapshot 'universe-nodejs-snapshot' already published, skipping."
fi

echo "Done!"
