#!/bin/bash

VIRUS_FULL_PATH="$1"
#VIRUS_DIR_PATH=$(dirname "$VIRUS_FULL_PATH")
#VIRUS_FILE_NAME=$(basename "$VIRUS_FULL_PATH")

[[ -d /tmp/pdf ]] && rm -rf /tmp/pdf
mkdir /tmp/pdf
cd /tmp/pdf || exit 1

if [[ -e /home/malware/src/bin/floss ]]; then
    /home/malware/src/bin/floss "$VIRUS_FULL_PATH" > /tmp/word/floss.txt 2>&1 || rm /tmp/word/floss.txt
fi
/opt/remnux-scripts/AnalyzePDF.py "$VIRUS_FULL_PATH" > /tmp/pdf/AnalyzePDF.txt 2>&1
/opt/remnux-didier/pdfid.py -e -f "$VIRUS_FULL_PATH" > /tmp/pdf/pdfid-e-f.txt 2>&1
/opt/remnux-didier/pdfid.py -e -f -a "$VIRUS_FULL_PATH" > /tmp/pdf/pdfid-e-f-a.txt 2>&1
/opt/remnux-didier/pdf-parser.py "$VIRUS_FULL_PATH" > /tmp/pdf/pdf-parser.txt 2>&1
/opt/remnux-didier/pdf-parser.py -a "$VIRUS_FULL_PATH" > /tmp/pdf/pdf-parser-a.txt 2>&1
/opt/remnux-didier/pdf-parser.py -f "$VIRUS_FULL_PATH" > /tmp/pdf/pdf-parser-f.txt 2>&1
/opt/remnux-didier/pdf-parser.py -f -w "$VIRUS_FULL_PATH" > /tmp/pdf/pdf-parser-f-w.txt 2>&1
/opt/remnux-peepdf/peepdf.py -f -l -g "$VIRUS_FULL_PATH" > /tmp/pdf/peepdf.txt 2>&1
/opt/remnux-peepdf/peepdf.py -f -l -g -x "$VIRUS_FULL_PATH" > /tmp/pdf/peepdf.xml 2> /tmp/pdf/peepdf.xml.error.txt
[[ -e /tmp/pdf/peepdf.xml.error.txt ]] && [[ ! -S /tmp/pdf/peepdf.xml.error.txt ]] && rm -f /tmp/pdf/peepdf.xml.error.txt
cd /tmp/pdf || exit 1
rm -f ../pdf_report.zip
zip -r ../pdf_report.zip -- *

