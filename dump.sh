#!/bin/bash
#
# SPDX-FileCopyrightText: luk1337
# SPDX-License-Identifier: MIT
#

set -ex

# Extract full update
aria2c -x5 $1 -o input.tar.zst
mkdir ota
tar -I zstd -xf input.tar.zst -C ota
TAG="${1##*/}"
TAG="${TAG%.tar.zst}"
BODY="[$TAG]($1) (full)"
rm input.tar.zst

# Apply incrementals
for i in ${@:2}; do
    aria2c -x5 $i -o ota.zip
    unzip ota.zip payload.bin
    wait
    mv payload.bin payload_working.bin
    TAG="`unzip -p ota.zip META-INF/com/android/metadata | grep post-build-incremental | cut -d= -f2`"
    BODY="$BODY -> [$TAG]($i)"
    rm ota.zip

    (
        mkdir ota_new
        ./bin/ota_extractor -input-dir ota -output_dir ota_new -payload payload_working.bin

        cp -r ota_new/* ota/
        rm -rf ota_new

        rm payload_working.bin
    ) & # Allow subsequent downloads to be done in parallel
done
wait

# Compress with zstd
zstd -T0 --rm ota/*

# Split to 2000M parts
find ota/* -size +2000M -exec split -b 2000M --numeric-suffixes {} {}. \; -delete

# Echo tag name and release body
echo "tag=$TAG" >> "$GITHUB_OUTPUT"
echo "body=$BODY" >> "$GITHUB_OUTPUT"
