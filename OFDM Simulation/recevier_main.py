import numpy as np
from Demapper import demapper

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
original_length, original_len_symbol, N, BANDWIDT,CP_LEN= map(int, metadata_values.split(","))

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

# Reshape 1D sample stream into OFDM symbols
complex_samples = complex_samples.reshape(-1, N+CP_LEN)

#remove cyclic prefix
complex_samples = complex_samples[:,CP_LEN:]


frequency_domian_signals = np.fft.fft(complex_samples,axis = 1)


print(demapper(frequency_domian_signals,original_length,original_len_symbol))
