# jBoot

A floppy disk FAT12 bootloader written in NASM assembly.

--------------------------------------------------------

## Memory Map

| start      | end        | size      | description                  |
|:----------:|:----------:|:---------:|:-----------------------------|
| 0x00000000 | 0x000004FF | 1.25 KiB  | Reserved                     |
| 0x00000500 | 0x000008FF | 1 KiB     | FAT working space            |
| 0x00000900 | 0x00000AFF | 512 B     | Root directory working space |
| 0x00000B00 | 0x00000CFF | 512 B     | jBoot                        |
| 0x00000D00 | 0x00007BFF | 27.75 KiB | Stack                        |
| 0x00007C00 | 0x0007FFFF | 481 KiB   | Free Memory                  |

Adapted from [OSDev Wiki](https://wiki.osdev.org/Memory_Map_(x86)#Overview)
