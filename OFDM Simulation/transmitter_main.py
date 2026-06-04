import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from QPSK_Mapper import qpsk_mapper
from Symbol_Mapper import symbol_mapper

N = 64
BANDWIDTH = 500_000
CARRIER_SPACING = BANDWIDTH/N
T = 1/CARRIER_SPACING
SAMPLE_RATE = N * CARRIER_SPACING
T_GI = 0.8e-6 # which should be equal to the time of the multipath channel
CP_LEN = int(np.ceil(T_GI * BANDWIDTH))


NUM_OFDM_SYMBOLS = 16
BITS_PER_QPSK = 2


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

# Known frequency-domain preamble across 64 subcarriers
# Use a fixed QPSK-like pattern
preamble_freq = np.ones(N, dtype=complex)

# Alternate signs to make it easier to detect
preamble_freq[::2] = 1 + 1j
preamble_freq[1::2] = -1 - 1j

# Make it shape (1, N), so it acts like one OFDM symbol
preamble_freq = preamble_freq.reshape(1, N)

# Add preamble before data OFDM symbols
tx_symbols_with_preamble = np.vstack((preamble_freq, N_symbols))


time_domain_signals = np.fft.ifft(tx_symbols_with_preamble, axis=1)
TS = 1 / SAMPLE_RATE

#add cyclic prefix
gi = time_domain_signals[:,-CP_LEN:]
time_domain_signals = np.concatenate((gi,time_domain_signals),axis = 1)


signal = time_domain_signals.flatten()

max_amplitude = np.max(np.abs(signal))
signal_ad2 = signal / max_amplitude * 0.8

i_wave = signal_ad2.real
q_wave = signal_ad2.imag


np.savetxt("OFDM Simulation/ad2_i_waveform.csv", i_wave, delimiter=",")
np.savetxt("OFDM Simulation/ad2_q_waveform.csv", q_wave, delimiter=",")

with open("OFDM Simulation/transmitted_bits.txt", "w") as f:
    f.write("sample_index,time_seconds,real,imag\n")

    for i, sample in enumerate(signal):
        time = i * TS
        f.write(f"{i},{time},{sample.real},{sample.imag}\n")
    
    f.write("orignal_length,original_len_symbol,N,BANDWIDTH,CP_LEN,TS\n")
    f.write(f"{original_len},{original_len_symbol},{N},{BANDWIDTH},{CP_LEN},{TS}\n")


