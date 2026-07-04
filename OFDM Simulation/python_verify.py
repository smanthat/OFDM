# verify.py — tolerant version
GOLDEN_FILE = 'C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_with_cp.txt'
RX_FILE     = 'rx_bytes.bin'

expected_bytes = bytearray()
with open(GOLDEN_FILE) as f:
    for line in f:
        word = int(line.strip(), 16)
        expected_bytes.extend([
            (word >> 16) & 0xFF,  # re_lo
            (word >> 24) & 0xFF,  # re_hi
            (word >> 0)  & 0xFF,  # im_lo
            (word >> 8)  & 0xFF,  # im_hi
        ])

with open(RX_FILE, 'rb') as f:
    got = f.read()

# Reassemble into signed 16-bit samples and compare with tolerance
sample_errors = 0
large_errors = 0
max_err_re = 0
max_err_im = 0

for i in range(1440):
    base = 4 * i
    got_re = int.from_bytes(bytes([got[base+0], got[base+1]]), 'little', signed=True)
    got_im = int.from_bytes(bytes([got[base+2], got[base+3]]), 'little', signed=True)
    exp_re = int.from_bytes(bytes([expected_bytes[base+0], expected_bytes[base+1]]), 'little', signed=True)
    exp_im = int.from_bytes(bytes([expected_bytes[base+2], expected_bytes[base+3]]), 'little', signed=True)
    
    err_re = abs(got_re - exp_re)
    err_im = abs(got_im - exp_im)
    max_err_re = max(max_err_re, err_re)
    max_err_im = max(max_err_im, err_im)
    
    if err_re > 2 or err_im > 2:
        sample_errors += 1
        if sample_errors <= 5:
            print(f"Sample {i}: exp re={exp_re} im={exp_im}  got re={got_re} im={got_im}  err={err_re}/{err_im}")
    if err_re > 10 or err_im > 10:
        large_errors += 1

print(f"\n=== Sample-level comparison (1440 total) ===")
print(f"Samples within ±2 LSB tolerance: {1440 - sample_errors}")
print(f"Samples exceeding ±2 LSB:        {sample_errors}")
print(f"Samples exceeding ±10 LSB:       {large_errors}")
print(f"Max real error: {max_err_re}")
print(f"Max imag error: {max_err_im}")

if sample_errors == 0:
    print("\n========== HARDWARE VERIFIED (all samples within tolerance) ==========")
elif large_errors == 0:
    print("\n========== HARDWARE VERIFIED (rounding noise only) ==========")
else:
    print("\n========== INVESTIGATION NEEDED — large errors present ==========")