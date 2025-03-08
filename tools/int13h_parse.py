"""int13h_parse.py

Allows you to calculate the CHS for a given LBA and compare this with
the actual values stored in the registers.

This is useful for testing/debugging an LBA->CHS routine.
"""

def get_CHS(LBA, SPT=18, HEADS=2):
    temp = LBA // SPT
    sector = (LBA%SPT) + 1
    head = temp % HEADS
    cylinder = temp // HEADS
    return cylinder, head, sector

def parse_registers(AX, CX, DX):
    AL = 0xff & AX
    AH = AX >> 8
    assert AH == 0x2
    print(f"N = {AL}")
    sector = CX & 0b111111
    print(f"sector = {sector}")
    cylinder = (((CX & 0xC0) << 8) + CX & 0xff00) >> 8
    print(f"cylinder = {cylinder}")
    DL = 0xff & DX
    DH = DX >> 8
    print(f"head = {DH}")
    print(f"drive = {DL}")
