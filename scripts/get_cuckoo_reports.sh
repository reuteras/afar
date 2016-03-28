#!/bin/bash

done="no"

while [[ $done != "yes" ]]; do
    reported=$(/usr/bin/curl -s http://localhost:8090/cuckoo/status | grep reported | tail -1 | awk '{print $2}' | cut -d, -f1)

    total=$(/usr/bin/curl -s http://localhost:8090/cuckoo/status | grep total | tail -1 | awk '{print $2}')

    if [[ "$reported" == "$total" ]]; then
        done="yes"
    fi
    sleep 1
done

[[ -d /tmp/cuckoo ]] && rm -rf /tmp/cuckoo
mkdir /tmp/cuckoo
cd /tmp/cuckoo || exit 1

/usr/bin/curl -s http://localhost:8090/cuckoo/status -o cuckoo_status.txt
sleep 1

for id in $(/usr/bin/curl -s http://localhost:8090/tasks/list | grep "\"id\":"| awk '{print $2}'|sort|uniq |cut -f1 -d,); do
    /usr/bin/curl -s http://localhost:8090/tasks/report/"$id"/all -o "$id".tar.bz2
    sleep 1
done

cd /tmp || exit 1
rm -f cuckoo_reports.zip
zip -r cuckoo_reports.zip cuckoo/*.bz2 cuckoo/*.txt

