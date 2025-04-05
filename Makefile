bsect.bin: bsect.nasm
	nasm -f bin -o bsect.bin -l bsect.lst bsect.nasm

boot.img: bsect.bin ./misc/TEST.TXT ./misc/TEST2.TXT
	rm -f boot.img
	mkfs.msdos -F 12 -C boot.img 1440
	dd if=bsect.bin of=boot.img conv=notrunc
	mcopy -i boot.img ./misc/TEST.TXT ::TEST.TXT
	mcopy -i boot.img ./misc/TEST2.TXT ::TEST2.TXT

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
