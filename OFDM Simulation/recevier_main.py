import numpy as np
from Demapper import demapper
from Multipath_channel import multipath_channel



filename = "/Users/sravanthimanthati/Sourish/OFDM/OFDM Simulation/transmitted_bits.txt"

complex_samples = []

with open(filename, "r") as f:
    lines = f.readlines()

# First line: sample header
header = lines[0].strip()

# Last two lines: metadata
metadata_header = lines[-2].strip()
metadata_values = lines[-1].strip()

# Middle lines: actual transmitted samples
data_lines = lines[1:-2]

# Read metadata
original_length, original_len_symbol, N, BANDWIDTH,CP_LEN= map(int, metadata_values.split(","))

# Read complex samples
for line in data_lines:
    line = line.strip()

    if line == "":
        continue

    sample_index, time_seconds, real, imag = line.split(",")

    real = float(real)
    imag = float(imag)

    sample = real + 1j * imag

    complex_samples.append(sample)

complex_samples = np.array(complex_samples)

rx_signal, H, h = multipath_channel(complex_samples, N)

BLOCK_LEN = N + CP_LEN
num_blocks = len(rx_signal) // BLOCK_LEN
rx_signal = rx_signal[:num_blocks * BLOCK_LEN]


# Reshape 1D sample stream into OFDM symbols
rx_signal = rx_signal.reshape(-1, N+CP_LEN)


#remove cyclic prefix
rx_signal = rx_signal[:,CP_LEN:]


frequency_domian_signals = np.fft.fft(rx_signal,axis = 1)

#equalizer
X_hat =  frequency_domian_signals / (H + 1e-12)


# remove padded symbols
frequency_domian_signals = frequency_domian_signals[:original_len_symbol]
frequency_domian_signals = frequency_domian_signals.flatten()





print(demapper(frequency_domian_signals,original_length,original_len_symbol))
