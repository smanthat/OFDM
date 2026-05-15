import numpy as np

def symbol_mapper(bits, N):
    bits = np.array(bits, dtype=complex)

    original_len_symbol = len(bits)

    remainder = len(bits) % N

    if remainder != 0:
        padding_needed = N - remainder
        padding = np.zeros(padding_needed, dtype=complex)
        bits = np.concatenate((bits, padding))

    N_symbols = bits.reshape(-1, N)

    return N_symbols, original_len_symbol