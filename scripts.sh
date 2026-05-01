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

echo "Creating mirror..."
# Check if mirror already exists to avoid errors on rerun
if ! aptly mirror show interhost > /dev/null 2>&1; then
    aptly mirror create -architectures=amd64 interhost https://ubuntu-archive.interhost.co.il/ubuntu focal main
else
    echo "Mirror 'interhost' already exists, skipping creation."
fi

echo "Updating mirror (this may take a while)..."
aptly mirror update interhost

echo "Creating snapshot..."
# Check if snapshot already exists
if ! aptly snapshot show interhost-snapshot > /dev/null 2>&1; then
    aptly snapshot create interhost-snapshot from mirror interhost
else
    echo "Snapshot 'interhost-snapshot' already exists, skipping creation."
fi

echo "Publishing snapshot (without signing)..."
# Check if it's already published
if ! aptly publish show focal > /dev/null 2>&1; then
    aptly publish snapshot -skip-signing interhost-snapshot
else
    echo "Snapshot already published."
fi

echo "Done!"
