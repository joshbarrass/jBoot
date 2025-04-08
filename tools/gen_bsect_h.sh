#!/bin/bash

echo "jboot_offset equ $(awk '/RELOCATION_OFFSET equ/{print $4}' bsect.lst)" > bsect.h
echo "load_file_offset equ 0x$(awk '/load_file:/{getline;while (length($2) == 0 || substr($2,1,1) == ";") {getline;} print $2}' bsect.lst)" >> bsect.h
echo "get_cluster_of_file_offset equ 0x$(awk '/get_cluster_of_file:/{getline;while (length($2) == 0 || substr($2,1,1) == ";") {getline;} print $2}' bsect.lst)" >> bsect.h

echo -e "get_cluster_of_file:\n        call 0:(jboot_offset+get_cluster_of_file_offset)\n        ret" >> bsect.h
echo -e "load_file:\n        push ds\n        push word 0\n        pop ds\n        call 0:(jboot_offset+load_file_offset)\n        pop ds\n        ret" >> bsect.h
