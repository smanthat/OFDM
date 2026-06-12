import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from QPSK_Mapper import qpsk_mapper
from Symbol_Mapper import symbol_mapper
from fixed_point_reference import dec_to_fixed_point
from preamble_gen import timing_preamble_gen, channel_preamble_gen

N = 64
BANDWIDTH = 500_000
CARRIER_SPACING = BANDWIDTH/N
T = 1/CARRIER_SPACING
SAMPLE_RATE = BANDWIDTH
T_GI = 0.8e-6 # which should be equal to the time of the multipath channel
CP_LEN = 16
#int(np.ceil(T_GI * BANDWIDTH))
TS = 1 / SAMPLE_RATE
NUM_BLOCKS = 18

NUM_OFDM_SYMBOLS = 16
BITS_PER_QPSK = 2

W = 16  
F = 10


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



# --Schmidl-Cox preamble pattern: on even subcarriers: 1 + 1j
preamble_freq = np.vstack((timing_preamble_gen(N), channel_preamble_gen(N)))

# Add preamble before data OFDM symbols
tx_symbols_with_preamble = np.vstack((preamble_freq, N_symbols))

time_domain_signals = np.fft.ifft(tx_symbols_with_preamble, axis=1)
time_domain_signals = time_domain_signals.reshape(-1,N)

print(time_domain_signals[32:64].shape)  # should be (32, 64)



#add cyclic prefix
gi = time_domain_signals[:,-CP_LEN:]
time_domain_signals = np.concatenate((gi,time_domain_signals),axis = 1)
print(time_domain_signals.shape)  # should be (18, 80)


signal = time_domain_signals.flatten()

max_amplitude = np.max(np.abs(signal))
signal_ad2 = signal / max_amplitude * 0.8

i_wave = signal_ad2.real
q_wave = signal_ad2.imag

i_wave_fixed = i_wave
q_wave_fixed = q_wave


np.savetxt("OFDM Simulation/ad2_i_waveform.csv", i_wave_fixed, delimiter=",")
np.savetxt("OFDM Simulation/ad2_q_waveform.csv", q_wave_fixed, delimiter=",")

with open("OFDM Simulation/transmitted_bits.txt", "w") as f:
    f.write("sample_index,time_seconds,real,imag\n")

    for i, sample in enumerate(signal):
        time = i * TS
        f.write(f"{i},{time},{sample.real},{sample.imag}\n")
    
    f.write("orignal_length,original_len_symbol,N,BANDWIDTH,CP_LEN,TS,NUM_BLOCKS\n")
    f.write(f"{original_len},{original_len_symbol},{N},{BANDWIDTH},{CP_LEN},{TS},{NUM_BLOCKS}\n")


