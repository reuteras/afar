#!/bin/bash
# Yara output used in summary report
VIRUS_FULL_PATH="$1"
#VIRUS_DIR_PATH="$(dirname "$1")"
#VIRUS_FILE_NAME=$(basename "$VIRUS_FULL_PATH")

[[ -d /tmp/all ]] && rm -rf /tmp/all
mkdir /tmp/all
cd /tmp/all || exit 1

if [ -d /home/malware/src/git/rules ]; then
    yara_rules="$(mktemp)"
    cat /home/malware/src/git/rules/malware/*.yar \
        /home/malware/src/git/rules/malware/Operation_Blockbuster/*.yara \
        > "$yara_rules"
    yara "$yara_rules" "$VIRUS_FULL_PATH" > /tmp/all/yara_malware.txt
    cat /home/malware/src/git/rules/*.yar > "$yara_rules"
    yara "$yara_rules" "$VIRUS_FULL_PATH" > /tmp/all/yara.txt
    cat /home/malware/src/git/rules/Malicious_Documents/*.yar > "$yara_rules"
    yara "$yara_rules" "$VIRUS_FULL_PATH" > /tmp/all/yara_documents.txt
    rm -f "$yara_rules"
fi
# Move to sift vm?
#/usr/bin/bulk_extractor -R "$VIRUS_DIR_PATH" -o /tmp/all/bulk_extractor > /tmp/all/bulk_extractor_output.txt 2>&1
[[ -f /usr/bin/densityscout ]] && /usr/bin/densityscout -pe -a "$VIRUS_FULL_PATH" > /tmp/all/densityscout.txt 2>&1
[[ -f /opt/remnux-didier/byte-stats.py ]] && /opt/remnux-didier/byte-stats.py -a "$VIRUS_FULL_PATH" > /tmp/all/byte-stats.txt 2>&1

# Remove empty files
find /tmp/all/bulk_extractor -type f -size 0c -exec rm {} \; || true
find /tmp/all/yara*.txt -type f -size 0c -exec rm {} \; || true

cd /tmp/all || exit 1
rm -f ../all_report.zip
zip -r ../all_report.zip -- *

