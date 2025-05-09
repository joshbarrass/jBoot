BOOT_FN ?= BOOT
BOOT_EXT ?= BIN

boot.img: bsect.bin
	rm -f boot.img
	mkfs.msdos -F 12 -C boot.img 1440
	dd if=bsect.bin of=boot.img conv=notrunc

bsect.bin bsect.lst: bsect.nasm
	nasm -DBOOT_FN="'$(BOOT_FN)'" -DBOOT_EXT="'$(BOOT_EXT)'" -f bin -o bsect.bin -l bsect.lst bsect.nasm
	./tools/count_free_space.sh bsect.bin

bsect.h: bsect.bin bsect.lst ./tools/gen_bsect_h.sh
	./tools/gen_bsect_h.sh

.PHONY: test
test: boot.img
	qemu-system-i386 -drive file=boot.img,index=0,if=floppy,format=raw -gdb tcp::9000

.PHONY: debug
debug: boot.img
	qemu-system-i386 -drive file=boot.img,index=0,if=floppy,format=raw -s -S

.PHONY: clean
clean:
	rm -f boot.img
	rm -f bsect.bin
	rm -f bsect.lst
