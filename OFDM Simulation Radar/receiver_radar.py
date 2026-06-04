    
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from radar_target_channel import radar_target_channel
from transmitter_main import N_symbols  # data symbols only (16, 64)
import pandas as pd


targets = [{"range": 10000, "velocity": 10, "rcs": 1}]
filename = "OFDM Simulation Radar/transmitted_bits.txt"
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

BLOCK_LEN = N + CP_LEN

#---------------------Loop-back the transmitted signal through the radar channel to generate the range-Doppler map---------------------
rx_signal = pd.read_csv("OFDM Simulation Radar/Recieved_waveform.csv",comment="#",)                       

i_signals = pd.to_numeric(rx_signal["Channel 1 (V)"], errors="coerce").to_numpy(dtype=float)
q_signals = pd.to_numeric(rx_signal["Channel 2 (V)"], errors="coerce").to_numpy(dtype=float)

mask = ~(np.isnan(i_signals) | np.isnan(q_signals))
i_signals, q_signals = i_signals[mask], q_signals[mask]

complex_ad2 = i_signals + 1j * q_signals   
complex_ad2 = complex_ad2[:len(N_symbols)]  # trim to same length as transmitted samples
complex_ad2 = np.array(complex_ad2, dtype=complex)
nb_r = len(complex_ad2) // BLOCK_LEN  
rx_radar = complex_ad2[:nb_r * BLOCK_LEN].reshape(-1, BLOCK_LEN)[:, CP_LEN:]
radar_freq = np.fft.fft(rx_radar, axis=1)
X = N_symbols[:radar_freq.shape[0], :]
H_radar = radar_freq / (X + 1e-12)
range_profile = np.fft.ifft(H_radar, axis=1)
range_doppler = np.fft.fftshift(np.fft.fft(range_profile, axis=0), axes=0)
rd_map_db = 20 * np.log10(np.abs(range_doppler) + 1e-12)
plt.figure()
plt.imshow(rd_map_db, aspect="auto", origin="lower")
plt.title("OFDM Radar Range-Doppler Map (AD2 Loopback)")
plt.xlabel("Range Bin"); plt.ylabel("Doppler Bin")
plt.colorbar(label="Magnitude (dB)")
plt.savefig("OFDM Simulation Radar/range_doppler_ad2.png", dpi=120)


# ---------------- RADAR range-Doppler (uses the delayed target channel) ----------------
rx_radar = radar_target_channel(complex_samples, 1 / TS, CARRIER_FREQ, targets, None)
nb_r = len(rx_radar) // BLOCK_LEN
rx_radar = rx_radar[:nb_r * BLOCK_LEN].reshape(-1, BLOCK_LEN)[:, CP_LEN:]
radar_freq = np.fft.fft(rx_radar, axis=1)
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
plt.savefig("OFDM Simulation Radar/range_doppler_fixed.png", dpi=120)