import numpy as np

with open("bits.txt", "r") as f:
    bit_string = f.read().strip()



orginal_len = len(bit_string)

if len(bit_string) % 2 != 0:
    bit_string += "0"

bits = np.array([int(b) for b in bit_string])

bit_pairs = bits.reshape(-1, 2)

# Store complex QPSK symbols here
#Gray code
complex_bits = []

for s, e in bit_pairs:
    if s == 0 and e == 0:
        complex_bits.append(1 + 1j)
    elif s == 0 and e == 1:
        complex_bits.append(-1 + 1j)
    elif s == 1 and e == 1:
        complex_bits.append(-1 - 1j)
    elif s == 1 and e == 0:
        complex_bits.append(1 - 1j)

# Convert list into NumPy array
complex_bits = np.array(complex_bits)

print("Original bits:")
print(bits)

print("\nBit pairs:")
print(bit_pairs)

print("\nQPSK symbols:")
print(complex_bits)

print("\nNumber of bits:", len(bits))
print("Number of QPSK symbols:", len(complex_bits))