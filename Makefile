bsect.bin: bsect.nasm
	nasm -f bin -o bsect.bin bsect.nasm

.PHONY: test
test: bsect.bin
	qemu-system-i386 -fda bsect.bin
