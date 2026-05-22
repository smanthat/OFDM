import numpy as np

def multipath_channel(tx_signal, N):
    h = np.zeros(N, dtype=complex)

    h[0] = 1.0
    h[3] = 0.5
    h[7] = 0.2

    rx_signal = np.convolve(tx_signal, h)

    H = np.fft.fft(h, N)

    return rx_signal, H, h