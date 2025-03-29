# jBoot

A floppy disk FAT12 bootloader written in NASM assembly.

--------------------------------------------------------

## Memory Map

| start      | end        | size      | description                  |
|:----------:|:----------:|:---------:|:-----------------------------|
| 0x00000000 | 0x000004FF | 1.25 KiB  | Reserved                     |
| 0x00000500 | 0x000075FF | 28.25 KiB | Stack                        |
| 0x00007600 | 0x000079FF | 1 KiB     | FAT working space            |
| 0x00007A00 | 0x00007BFF | 512 B     | Root directory working space |
| 0x00007C00 | 0x00007DFF | 512 B     | jBoot Sector                 |
| 0x00007E00 | 0x0007FFFF | 480.5 KiB | Free Memory                  |

Adapted from [OSDev Wiki](https://wiki.osdev.org/Memory_Map_(x86)#Overview)
