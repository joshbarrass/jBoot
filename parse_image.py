import struct

with open("boot.img", "rb") as f:
    header = f.read(512)

# struct reference
# 1 byte = db = 'B'
# n-byte string = db = 'ns'
# 2 byte = dw = 'H'
# 4 byte = dd = 'I'
unpack_format = "<3s8sHBHBHHBHHHIIBBBI11s8s"
JMP, OEM_LABEL, BPS, SPC, RS, FATS, ROOTS, N_SECTORS, MDT, SPF, SPT, N_HEADS, HIDDEN_SECTORS, LSC, DRIVE_NUMBER, NT_FLAGS, SIGNATURE, VOLUME_ID, VOLUME_LABEL, SYSTEM_ID = struct.unpack(unpack_format, header[:54+8])
print("OEM_LABEL db", OEM_LABEL)
print("BYTES_PER_SECTOR dw", BPS)
print("SECTORS_PER_CLUSTER db", SPC)
print("RESERVED_SECTORS dw", RS)
print("N_FATS db", FATS)
print("N_ROOTS dw", ROOTS)
print("N_SECTORS dw", N_SECTORS)
print("MDT db", MDT)
print("SECTORS_PER_FAT dw", SPF)
print("SECTORS_PER_TRACK dw", SPT)
print("N_HEADS dw", N_HEADS)
print("N_HIDDEN_SECTORS dd", HIDDEN_SECTORS)
print("LARGE_SECTOR_COUNT dd", LSC)
print("DRIVE_NUMBER db", DRIVE_NUMBER)
print("NT_FLAGS db", NT_FLAGS)
print("SIGNATURE db", SIGNATURE)
print("VOLUME_ID dd", VOLUME_ID)
print("VOLUME_LABEL db", VOLUME_LABEL)
print("SYSTEM_ID db", SYSTEM_ID)
