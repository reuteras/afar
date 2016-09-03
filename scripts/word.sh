#!/bin/bash

VIRUS_FULL_PATH="$1"
#VIRUS_DIR_PATH=$(dirname "$VIRUS_FULL_PATH")
#VIRUS_FILE_NAME=$(basename "$VIRUS_FULL_PATH")

[[ -d /tmp/word ]] && rm -rf /tmp/word
mkdir /tmp/word
cd /tmp/word || exit 1

/opt/remnux-oletools/olevba.py "$VIRUS_FULL_PATH" > /tmp/word/olevba.txt 2>&1 || rm /tmp/word/olevba.txt
/opt/remnux-oletools/oleid.py "$VIRUS_FULL_PATH" > /tmp/word/oleid.txt 2>&1 || rm /tmp/word/oleid.txt
/opt/remnux-oletools/olemeta.py "$VIRUS_FULL_PATH" > /tmp/word/olemeta.txt 2>&1 || rm /tmp/word/olemeta.txt
/opt/remnux-oletools/oletimes.py "$VIRUS_FULL_PATH" > /tmp/word/oletimes.txt 2>&1 || rm /tmp/word/oletimes.txt
/opt/remnux-oletools/oletimes.py "$VIRUS_FULL_PATH" > /tmp/word/oletimes.txt 2>&1 || rm /tmp/word/oletimes.txt
/opt/remnux-oletools/pyxswf.py "$VIRUS_FULL_PATH" > /tmp/word/pyxswf.txt 2>&1 || rm /tmp/word/pyxswf.txt
/opt/remnux-didier/oledump.py "$VIRUS_FULL_PATH" > /tmp/word/oledump.txt
if [[ -e /home/malware/src/git/DidierStevensSuite/oledump.py ]]; then
   python /home/malware/src/git/DidierStevensSuite/oledump.py "$VIRUS_FULL_PATH" > /tmp/word/oledump-latest.txt 2>&1
fi
if [[ -d /home/malware/src/git/oletools ]]; then
   /home/malware/src/git/oletools/oletools/mraptor.py "$VIRUS_FULL_PATH" > /tmp/word/mraptor-latest.txt 2>&1
   /home/malware/src/git/oletools/oletools/olevba.py "$VIRUS_FULL_PATH" > /tmp/word/olevba-latest.txt 2>&1
fi
mkdir /tmp/word/officeparser
/opt/remnux-scripts/officeparser.py -o /tmp/word/officeparser --extract-streams --extract-ole-streams --extract-macros "$VIRUS_FULL_PATH" >  /tmp/word/officeparser.txt 2>&1
/opt/remnux-scripts/pyOLEScanner.py "$VIRUS_FULL_PATH" > /tmp/word/pyOLEScanner.txt 2>&1

cd /tmp/word || exit 1
rm -f ../word_report.zip
find /tmp/word -empty -type f -delete
zip -r ../word_report.zip -- *

