import numpy as np


def qpsk_mapper(bit_string):
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

    return complex_bits, orginal_len
