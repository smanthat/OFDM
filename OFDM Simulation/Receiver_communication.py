import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from Demapper import demapper
from radar_target_channel import radar_target_channel
from transmitter_main import N_symbols  # data symbols only (16, 64)

targets = [{"range": 10000, "velocity": 0, "rcs": 1}]
filename = "OFDM Simulation/transmitted_bits.txt"
CARRIER_FREQ = 24e9

# ---- read transmitted samples + metadata ----
with open(filename, "r") as f:
    lines = f.readlines()

metadata = lines[-1].strip().split(",")
original_length     = int(metadata[0])
original_len_symbol = int(metadata[1])
N                   = int(metadata[2])
BANDWIDTH           = int(metadata[3])
CP_LEN              = int(metadata[4])
TS                  = float(metadata[5])

complex_samples = []
for line in lines[1:-2]:
    line = line.strip()
    if not line:
        continue
    _, _, real, imag = line.split(",")
    complex_samples.append(float(real) + 1j * float(imag))
complex_samples = np.array(complex_samples)

# ---- COMMS path: demodulate the clean transmitted stream ----
# The radar_target_channel applies range delay + heavy attenuation, which
# misaligns OFDM frame timing and corrupts the comms data. Communications
# demodulation must use the undelayed signal; the radar channel below is
# only used to build the range-Doppler map.
BLOCK_LEN = N + CP_LEN
num_blocks = len(complex_samples) // BLOCK_LEN
comms = complex_samples[:num_blocks * BLOCK_LEN].reshape(-1, BLOCK_LEN)
comms = comms[:, CP_LEN:]                                # remove cyclic prefix
freq = np.fft.fft(comms, axis=1)                         # (17, 64): preamble + data

# ---- rebuild the SAME known preamble the transmitter used ----
preamble_freq = np.ones(N, dtype=complex)
preamble_freq[::2]  = 1 + 1j
preamble_freq[1::2] = -1 - 1j

# ---- channel estimate from the preamble, then equalize the data ----
H_est = freq[0] / preamble_freq                         # per-subcarrier channel
data_freq = freq[1:]                                    # drop preamble -> (16, 64)
data_eq = data_freq / (H_est[np.newaxis, :] + 1e-12)    # zero-forcing equalize

# ---------------- RADAR range-Doppler (uses the delayed target channel) ----------------
rx_radar = radar_target_channel(complex_samples, 1 / TS, CARRIER_FREQ, targets, None)
nb_r = len(rx_radar) // BLOCK_LEN
rx_radar = rx_radar[:nb_r * BLOCK_LEN].reshape(-1, BLOCK_LEN)[:, CP_LEN:]
radar_freq = np.fft.fft(rx_radar, axis=1)[1:]            # drop preamble
X = N_symbols[:radar_freq.shape[0], :]
H_radar = radar_freq / (X + 1e-12)
range_profile = np.fft.ifft(H_radar, axis=1)
range_doppler = np.fft.fftshift(np.fft.fft(range_profile, axis=0), axes=0)
rd_map_db = 20 * np.log10(np.abs(range_doppler) + 1e-12)
plt.figure()
plt.imshow(rd_map_db, aspect="auto", origin="lower")
plt.title("OFDM Radar Range-Doppler Map")
plt.xlabel("Range Bin"); plt.ylabel("Doppler Bin")
plt.colorbar(label="Magnitude (dB)")
plt.savefig("OFDM Simulation/range_doppler_fixed.png", dpi=120)

# ---------------- COMMS demap ----------------
X_hat = data_eq.flatten()[:original_len_symbol]
rx_bits = demapper(X_hat, original_length, original_len_symbol)

with open("OFDM Simulation/bits.txt", "r") as f:
    tx_bits = np.array([int(b) for b in f.read().strip()])
rx_bits = np.array(rx_bits, dtype=int)

n = min(len(tx_bits), len(rx_bits))
num_errors = int(np.sum(tx_bits[:n] != rx_bits[:n]))
ber = num_errors / n
print(f"Number of bit errors: {num_errors} out of {n}")
print(f"Bit Error Rate (BER): {ber:.6f}")