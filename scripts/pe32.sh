#!/bin/bash

VIRUS_FULL_PATH="$1"
VIRUS_DIR_PATH=$(dirname "$VIRUS_FULL_PATH")
VIRUS_FILE_NAME=$(basename "$VIRUS_FULL_PATH")

[[ -d /tmp/pe32 ]] && rm -rf /tmp/pe32
mkdir /tmp/pe32
cd /tmp/pe32 || exit 1

/opt/remnux-scripts/packerid -P -a -e -m "$VIRUS_FULL_PATH" > /tmp/pe32/packerid_long.txt 2>&1
/opt/remnux-scripts/packerid "$VIRUS_FULL_PATH" > /tmp/pe32/packerid_short.txt 2>&1
/bin/signsrch "$VIRUS_FULL_PATH" > /tmp/pe32/signsrch.txt 2>&1
/opt/remnux-scripts/pescanner.py "$VIRUS_FULL_PATH" > /tmp/pe32/pescanner.txt 2>&1
/usr/bin/peframe --dump "$VIRUS_FULL_PATH" > /tmp/pe32/peframe-all.txt 2>&1
/usr/local/bin/pedump --all "$VIRUS_FULL_PATH" > /tmp/pe32/pedump-all.txt 2>&1
/usr/bin/objdump -x "$VIRUS_FULL_PATH" > /tmp/pe32/objdump-x.txt 2>&1
cd "$VIRUS_DIR_PATH" || exit 1
cp "$VIRUS_FILE_NAME" "$VIRUS_FILE_NAME".org
/opt/remnux-scripts/exescan.py -a "$VIRUS_FILE_NAME" > /tmp/pe32/exescan-a-advanced.txt 2>&1
cp "$VIRUS_FILE_NAME".org "$VIRUS_FILE_NAME"
/opt/remnux-scripts/exescan.py -b "$VIRUS_FILE_NAME" > /tmp/pe32/exescan-b-basic.txt 2>&1
cp "$VIRUS_FILE_NAME".org "$VIRUS_FILE_NAME"
/opt/remnux-scripts/exescan.py -m "$VIRUS_FILE_NAME" > /tmp/pe32/exescan-m-malware-api.txt 2>&1
cp "$VIRUS_FILE_NAME".org "$VIRUS_FILE_NAME"
/opt/remnux-scripts/exescan.py -i "$VIRUS_FILE_NAME" > /tmp/pe32/exescan-i-import-export.txt 2>&1
cp "$VIRUS_FILE_NAME".org "$VIRUS_FILE_NAME"
/opt/remnux-scripts/exescan.py -p "$VIRUS_FILE_NAME" > /tmp/pe32/exescan-p-pe-header.txt 2>&1
mv "$VIRUS_FULL_PATH".org "$VIRUS_FULL_PATH"

cd /tmp/pe32 || exit 1
rm -f ../pe32_report.zip
zip -r ../pe32_report.zip -- *

