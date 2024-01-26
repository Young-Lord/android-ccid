#!/bin/bash
export CCIDFD=$1
./usbtest
gdb --args pcscd -f -d -a