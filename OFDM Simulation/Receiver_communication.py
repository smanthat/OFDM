import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from Demapper import demapper
import pandas as pd

from transmitter_main import N_symbols  # data symbols only (16, 64)

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

rx_signal = pd.read_csv("OFDM Simulation Radar/Recieved_waveform.csv",comment="#",)                       

i_signals = pd.to_numeric(rx_signal["Channel 1 (V)"], errors="coerce").to_numpy(dtype=float)
q_signals = pd.to_numeric(rx_signal["Channel 2 (V)"], errors="coerce").to_numpy(dtype=float)
mask = ~(np.isnan(i_signals) | np.isnan(q_signals))
i_signals, q_signals = i_signals[mask], q_signals[mask]
complex_samples = i_signals + 1j * q_signals
complex_samples = np.array(complex_samples, dtype=complex)



# ---- COMMS path: demodulate the clean transmitted stream ----
# The radar_target_channel applies range delay + heavy attenuation, which
# misaligns OFDM frame timing and corrupts the comms data. Communications
# demodulation must use the undelayed signal; the radar channel below is
# only used to build the range-Doppler map.
                     # (17, 64): preamble + data


preamble_freq = np.zeros(N, dtype=complex)
preamble_freq[::2] = 1 + 1j

r = complex_samples

# -- True Schdl - Cox channel estimate from the known preamble ---
# find the timing metric by correlating with the known preamble
num = len(r)-N
metric = []
L = N//2
for d in range(num):
    p = 0
    r_c = 0
    for m in range(L):
        p += np.conj(r[d+m]) * r[d+m+L]
        r_c += np.abs(r[d+m+L])**2
    metric.append(np.abs(p)**2 / (r_c**2 + 1e-12))
d_peak = np.argmax(metric)

NUM_BLOCKS = 17
BLOCK_LEN = N + CP_LEN
frame_start = d_peak
if frame_start < 0:
    print("Warning: Detected frame start is before the beginning of the received signal. Adjusting to 0.")
    frame_start = 0
comms_samples = complex_samples[frame_start:frame_start + BLOCK_LEN * NUM_BLOCKS]
comms_without_CP = comms_samples.reshape(-1, BLOCK_LEN)[:, CP_LEN:]
freq = np.fft.fft(comms_without_CP, axis=1)


# ---- channel estimate from the preamble, then equalize the data ----
H_est = freq[0] / preamble_freq                         # per-subcarrier channel
data_freq = freq[1:]                                    # drop preamble -> (16, 64)
data_eq = data_freq / (H_est[np.newaxis, :] + 1e-12)    # zero-forcing equalize

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
print(f"Bit Error Rate (BER): {ber:.20f}")