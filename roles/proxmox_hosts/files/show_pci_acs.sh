#!/bin/bash
lspci -vvvv 2>&1|awk 'BEGIN{ show=0}  /^[0-9]/ { pci=$0 } /[ |\t]+Capabilities/ { show=0} /Access Control Service/ { show=1; print pci;print}  /[ |\t]+ACS/{ if (show == 1 ) print }' 
