import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from Demapper import demapper
import pandas as pd
from preamble_gen import timing_preamble_gen, channel_preamble_gen

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
NUM_BLOCKS = int(metadata[6]) 

rx_signal = pd.read_csv("OFDM Simulation/Recieved_waveform.csv",comment="#",)                       

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




r = complex_samples

# -- True Schdl - Cox channel estimate from the known preamble ---
# find the timing metric by correlating with the known preamble
num = len(r)-N
metric = []
energy = []
L = N//2
for d in range(num):
    p = 0
    r_c = 0
    for m in range(L):
        p += np.conj(r[d+m]) * r[d+m+L]
        r_c += np.abs(r[d+m+L])**2
    metric.append(np.abs(p)**2 / (r_c**2 + 1e-12))
    energy.append(r_c)

metric = np.array(metric)
energy = np.array(energy)

typical = np.median(energy[energy > 0])

metric[energy < 0.2 * typical] = 0  # mask out low-energy peaks

d_peak = int(np.argmax(metric))

BLOCK_LEN = N + CP_LEN
frame_start = d_peak
if frame_start < 0:
    print("Warning: Detected frame start is before the beginning of the received signal. Adjusting to 0.")
    frame_start = 0
comms_samples = complex_samples[frame_start : frame_start + BLOCK_LEN * NUM_BLOCKS]
assert len(comms_samples) == BLOCK_LEN * NUM_BLOCKS, \
    f"short frame: got {len(comms_samples)}, need {BLOCK_LEN*NUM_BLOCKS} — d_peak too close to end of capture"
comms_without_CP = comms_samples.reshape(-1, BLOCK_LEN)[:, CP_LEN:]
freq = np.fft.fft(comms_without_CP, axis=1)


# ---- channel estimate from the preamble, then equalize the data ----
H_est = freq[1] / channel_preamble_gen(N)                         # per-subcarrier channel
data_freq = freq[2:]                                    # drop preamble -> (16, 64)
data_eq = data_freq / (H_est[np.newaxis, :] + 1e-12)    # zero-forcing equalize


plt.scatter(data_eq.real, data_eq.imag)
plt.title("Received OFDM Signal Constellation")
plt.xlabel("In-phase")
plt.ylabel("Quadrature")
plt.grid(True)
plt.savefig("OFDM Simulation/constellation.png")

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