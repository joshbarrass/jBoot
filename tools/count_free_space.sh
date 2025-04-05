#!/bin/bash

xxd -p "$1" | tr -d '\n' | awk '{for(i=length($0)-4; i>0; i-=2) {if(substr($0,i-1,2)=="00") count++; else break}} END {print count, "bytes free"}'
