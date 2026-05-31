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
T_GI = 0.8e-6 # which should be equal to the time of the multipath channel
CP_LEN = int(np.ceil(T_GI * BANDWIDTH))

import numpy as np

N = 64
NUM_OFDM_SYMBOLS = 64
BITS_PER_QPSK = 2

num_bits = N * NUM_OFDM_SYMBOLS * BITS_PER_QPSK
bits = np.random.randint(0, 2, num_bits)

with open("OFDM Simulation/bits.txt", "w") as f:
    f.write("".join(str(b) for b in bits))


with open("OFDM Simulation/bits.txt", "r") as f:
    bit_string = f.read().strip()

bit_string = "".join(bit_string.split())

complex_bits, original_len = qpsk_mapper(bit_string)


N_symbols, original_len_symbol = symbol_mapper(complex_bits, N)

plt.scatter(N_symbols.real, N_symbols.imag)
plt.title("Transmitted OFDM Signal Constellation")
plt.xlabel("In-phase")
plt.ylabel("Quadrature")
plt.grid(True)

plt.show()


time_domain_signals = np.fft.ifft(N_symbols, axis=1)
TS = 1 / SAMPLE_RATE

#add cyclic prefix
gi = time_domain_signals[:,-CP_LEN:]
time_domain_signals = np.concatenate((gi,time_domain_signals),axis = 1)


signal = time_domain_signals.flatten()


with open("OFDM Simulation/transmitted_bits.txt", "w") as f:
    f.write("sample_index,time_seconds,real,imag\n")

    for i, sample in enumerate(signal):
        time = i * TS
        f.write(f"{i},{time},{sample.real},{sample.imag}\n")
    
    f.write("orignal_length,original_len_symbol,N,BANDWIDTH,CP_LEN,TS\n")
    f.write(f"{original_len},{original_len_symbol},{N},{BANDWIDTH},{CP_LEN},{TS}\n")