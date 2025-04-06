#!/bin/bash

echo "jboot_segment equ $(awk '/RELOCATION_SEGMENT equ/{print $4}' bsect.lst)" > bsect.h
echo "load_file_offset equ 0x$(awk '/load_file:/{getline; print $2}' bsect.lst)" >> bsect.h
echo "get_cluster_of_file_offset equ 0x$(awk '/get_cluster_of_file:/{getline; print $2}' bsect.lst)" >> bsect.h

echo -e "get_cluster_of_file:\n        call jboot_segment:get_cluster_of_file_offset\n        ret" >> bsect.h
echo -e "load_file:\n        push word jboot_segment\n        pop ds\n        call jboot_segment:load_file_offset\n        push word 7c0h\n        pop ds\n        ret" >> bsect.h
