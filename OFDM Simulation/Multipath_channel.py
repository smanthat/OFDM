import numpy as np
import scipy.stats as stats

def multipath_channel(tx_signal, N, snr_db = 20):
    h = np.zeros(N, dtype=complex)

    h[0] = 1.0
    h[3] = 0.5
    h[7] = 0.2

    rx_signal = np.convolve(tx_signal, h)

    H = np.fft.fft(h, N)
    #AWGN noise
    P_signal = np.mean(np.abs(rx_signal)**2)
    noise_power = P_signal / (10 ** (snr_db / 10))
    channel_capacity = 20e6 * np.log2(1 + P_signal / noise_power) # Assuming noise power of 1e-9 W

    noise = np.sqrt(noise_power/2) * (np.random.randn(len(rx_signal)) + 1j * np.random.randn(len(rx_signal)))
    rx_signal += noise
    


    return rx_signal, H, h