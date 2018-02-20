#!/bin/bash

# shellcheck disable=SC1091
. /etc/bash_completion.d/virtualenvwrapper
workon cuckoo
cuckoo api > /home/cuckoo/src/cuckoo/log/api.log 2>&1 &
