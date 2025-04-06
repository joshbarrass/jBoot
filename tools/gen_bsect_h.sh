#!/bin/bash

echo "load_file_offset equ 0x$(awk '/load_file:/{getline; print $2}' bsect.lst)" > bsect.h
