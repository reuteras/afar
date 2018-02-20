#!/bin/bash

{
    # shellcheck disable=SC1091
    . /etc/bash_completion.d/virtualenvwrapper
    export CUCKOO=/home/cuckoo/src/cuckoo/.conf
    workon cuckoo
    cuckoo submit "$1"
} > /home/cuckoo/src/cuckoo/log/submit.log 2>&1
