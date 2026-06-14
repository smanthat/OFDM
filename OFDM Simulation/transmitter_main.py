import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
from QPSK_Mapper import qpsk_mapper
from Symbol_Mapper import symbol_mapper
from fixed_point_reference import dec_to_fixed_point, fixed_point_to_dec, export_fixed_point
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
F = 13


with open("OFDM Simulation/bits.txt", "r") as f:
    bit_string = f.read().strip()

bit_string = "".join(bit_string.split())

complex_bits, original_len = qpsk_mapper(bit_string)


N_symbols, original_len_symbol = symbol_mapper(complex_bits, N)

N_symbols_real = dec_to_fixed_point(N_symbols.real, F, W)
N_symbols_imag = dec_to_fixed_point(N_symbols.imag, F, W)



plt.scatter(N_symbols.real, N_symbols.imag)
plt.title("Transmitted OFDM Signal Constellation")
plt.xlabel("In-phase")
plt.ylabel("Quadrature")
plt.grid(True)



# --Schmidl-Cox preamble pattern: on even subcarriers: 1 + 1j
timing_preamble = timing_preamble_gen(N)
channel_preamble = channel_preamble_gen(N)

i_preamble = dec_to_fixed_point(timing_preamble.real, F, W)
q_preamble = dec_to_fixed_point(timing_preamble.imag, F, W)

i_channel_preamble = dec_to_fixed_point(channel_preamble.real, F, W)
q_channel_preamble = dec_to_fixed_point(channel_preamble.imag, F, W)

    
preamble_freq = np.vstack((timing_preamble, channel_preamble))

# Add preamble before data OFDM symbols
tx_symbols_with_preamble = np.vstack((preamble_freq, N_symbols))




time_domain_signals_before_cp = np.fft.ifft(tx_symbols_with_preamble, axis=1)
time_domain_signals_before_cp = time_domain_signals_before_cp.reshape(-1,N)




#add cyclic prefix
gi = time_domain_signals_before_cp[:,-CP_LEN:]
time_domain_signals = np.concatenate((gi,time_domain_signals_before_cp),axis = 1)



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
    
    f.write("orignal_length,original_len_symbol,N,BANDWIDTH,CP_LEN,TS,NUM_BLOCKS\n")
    f.write(f"{original_len},{original_len_symbol},{N},{BANDWIDTH},{CP_LEN},{TS},{NUM_BLOCKS}\n")


VDIR = "OFDM Simulation/Verification_Files"
export_fixed_point(N_symbols,        f"{VDIR}/data_symbols.txt",    F, W)
export_fixed_point(timing_preamble,  f"{VDIR}/preamble_timing.txt", F, W)
export_fixed_point(channel_preamble, f"{VDIR}/preamble_channel.txt",F, W)
# before IFFT:
export_fixed_point(tx_symbols_with_preamble, f"{VDIR}/frame_freq.txt", F, W)
#after IFFT, before CP:
export_fixed_point(time_domain_signals_before_cp,       f"{VDIR}/frame_time.txt", F, W)
# after CP:
export_fixed_point(time_domain_signals,       f"{VDIR}/frame_with_cp.txt", F, W)
# final flattened (pre-0.8-scaling, at fixed-point scale):
export_fixed_point(signal,                    f"{VDIR}/signal.txt", F, W)

peak = np.max(np.abs(np.concatenate([time_domain_signals_before_cp.real.flatten(),
                                     time_domain_signals_before_cp.imag.flatten()])))
print(f"Peak IFFT sample magnitude: {peak:.4f}")
print(f"F=13 representable range: ±{2**(W-1-F):.2f}")   # ±4.0
print(f"Headroom: {2**(W-1-F) / peak:.2f}x")
print(f"Overflow risk: {'YES' if peak >= 2**(W-1-F) else 'no'}")

