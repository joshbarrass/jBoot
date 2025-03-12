bsect.bin: bsect.nasm
	nasm -f bin -o bsect.bin bsect.nasm

boot.img: bsect.bin
	rm -f boot.img
	mkfs.msdos -F 12 -C boot.img 1440
	dd if=bsect.bin of=boot.img conv=notrunc
	mcopy -i boot.img ./OS.BIN ::OS.BIN

.PHONY: test
test: boot.img
	qemu-system-i386 -drive file=boot.img,index=0,if=floppy,format=raw -gdb tcp::9000 -audiodev pa,id=snd0 -soundhw pcspk

.PHONY: clean
clean:
	rm -f boot.img
	rm -f bsect.bin
