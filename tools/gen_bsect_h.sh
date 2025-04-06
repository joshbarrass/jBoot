#!/bin/bash

echo "load_file_offset equ 0x$(awk '/load_file:/{getline; print $2}' bsect.lst)" > bsect.h
echo "get_cluster_of_file_offset equ 0x$(awk '/get_cluster_of_file:/{getline; print $2}' bsect.lst)" >> bsect.h
echo "jboot_segment equ $(awk '/RELOCATION_SEGMENT equ/{print $4}' bsect.lst)" >> bsect.h
