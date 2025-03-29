# jBoot

A floppy disk FAT12 bootloader written in NASM assembly.

--------------------------------------------------------

## Memory Map

| start      | end        | size      | description          |
|:----------:|:----------:|:---------:|:---------------------|
| 0x00000000 | 0x000004FF | 1.25 KiB  | Reserved             |
| 0x00000500 | 0x00007BFF | 29.75 KiB | Stack                |
| 0x00007C00 | 0x00007DFF | 512 B     | jBoot Sector         |
| 0x00007E00 | 0x0000A1FF | 9 KiB     | FATs                 |
| 0x0000A200 | 0x0000BDFF | 7 KiB     | Root directory entry |
| 0x0000BE00 | 0x0007FFFF | 464.5 KiB | Free memory          |

Adapted from [OSDev Wiki](https://wiki.osdev.org/Memory_Map_(x86)#Overview)
