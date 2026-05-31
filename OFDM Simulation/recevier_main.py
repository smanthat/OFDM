import numpy as np
from Demapper import demapper
from Multipath_channel import multipath_channel
import matplotlib.pyplot as plt
from radar_target_channel import radar_target_channel
from transmitter_main import N_symbols


targets = [{"range" : 100, "velocity" : 5, "rcs" : 1},
]

filename = "OFDM Simulation/transmitted_bits.txt"

CARRIER_FREQ = 24e9

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
metadata = metadata_values.split(",")

original_length = int(metadata[0])
original_len_symbol = int(metadata[1])
N = int(metadata[2])
BANDWIDTH = int(metadata[3])
CP_LEN = int(metadata[4])
TS = float(metadata[5])

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

rx_signal = radar_target_channel(complex_samples, 1/TS, CARRIER_FREQ, targets,None)

BLOCK_LEN = N + CP_LEN
num_blocks = len(rx_signal) // BLOCK_LEN
rx_signal = rx_signal[:num_blocks * BLOCK_LEN]


# Reshape 1D sample stream into OFDM symbols
rx_signal = rx_signal.reshape(-1, N+CP_LEN)


#remove cyclic prefix
rx_signal = rx_signal[:,CP_LEN:]


frequency_domian_signals = np.fft.fft(rx_signal,axis = 1)

X = N_symbols[:frequency_domian_signals.shape[0], :]

H_est = frequency_domian_signals / (X + 1e-12)

range_profile = np.fft.ifft(H_est, axis=1)

range_doppler = np.fft.fftshift(
    np.fft.fft(range_profile, axis=0), axes=0
)
rd_map_db = 20 * np.log10(np.abs(range_doppler) + 1e-12)

plt.figure()
plt.imshow(rd_map_db, aspect="auto", origin="lower")
plt.title("OFDM Radar Range-Doppler Map")
plt.xlabel("Range Bin")
plt.ylabel("Doppler Bin")
plt.colorbar(label="Magnitude (dB)")
plt.show()

X_hat = frequency_domian_signals.flatten()
X_hat = X_hat[:original_len_symbol]
rx_bits = demapper(X_hat,original_length,original_len_symbol)
print(rx_bits)

with open("OFDM Simulation/bits.txt", "r") as f:
    tx_bits = f.read().strip()

tx_bits = np.array([int(b) for b in tx_bits])

rx_bits = np.array(rx_bits, dtype=int)

num_errors = np.sum(tx_bits != rx_bits)
print(f"Number of bit errors: {num_errors} out of {len(tx_bits)}")

ber = num_errors / len(tx_bits)
print(f"Bit Error Rate (BER): {ber:.6f}")

