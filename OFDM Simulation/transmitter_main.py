import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from QPSK_Mapper import qpsk_mapper
from Symbol_Mapper import symbol_mapper

N = 64
BANDWIDTH = 20_000_000
CARRIER_SPACING = BANDWIDTH/N
T = 1/CARRIER_SPACING
SAMPLE_RATE = N * CARRIER_SPACING


with open("/Users/sravanthimanthati/Sourish/OFDM/OFDM Simulation/bits.txt", "r") as f:
    bit_string = f.read().strip()

bit_string = "".join(bit_string.split())

complex_bits, original_len = qpsk_mapper(bit_string)


N_symbols, original_len_symbol = symbol_mapper(complex_bits, N)

time_domain_signals = np.fft.ifft(N_symbols, axis=1)
TS = 1 / SAMPLE_RATE

signal = time_domain_signals.flatten()


with open("/Users/sravanthimanthati/Sourish/OFDM/OFDM Simulation/transmitted_bits.txt", "w") as f:
    f.write("sample_index,time_seconds,real,imag\n")

    for i, sample in enumerate(signal):
        time = i * TS
        f.write(f"{i},{time},{sample.real},{sample.imag}\n")
    
    f.write("orignal_length,original_len_symbol,N,BANDWIDTH\n")
    f.write(f"{original_len},{original_len_symbol},{N},{BANDWIDTH}\n")