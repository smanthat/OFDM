import numpy as np


def apply_target_effects(tx, tau, fD, sample_rate):
    n = np.arange(len(tx))
    delayed_signal = np.concatenate((np.zeros(tau,dtype=complex),tx))[:len(tx)]
    rx_signal = delayed_signal * np.exp(1j * 2 * np.pi * fD * n / sample_rate)

    return rx_signal

def compute_range_doppler(Y,X):

    H = Y/X

    rd_map = np.fft.fft( np.fft.ifft(H, axis=0),axis = 1)

    return rd_map

def add_noise(rx_signal,snr_db):
            #AWGN noise
    if snr_db is not None:
        P_signal = np.mean(np.abs(rx_signal)**2)
        noise_power = P_signal / (10 ** (snr_db / 10))

        noise = np.sqrt(noise_power / 2) * (
        np.random.randn(len(rx_signal)) + 1j * np.random.randn(len(rx_signal))
        )

        rx_signal = rx_signal + noise
    return rx_signal

def peak_to_floor_db(rd_map, n_targets=2):
    mag = np.abs(rd_map)
    # peak power: mean of the top-n_targets cells (one per target)
    flat = mag.flatten()
    top = np.sort(flat)[-n_targets:]
    peak_power = np.mean(top**2)
    # noise floor: median power of the rest
    rest = np.sort(flat)[:-n_targets]
    floor_power = np.median(rest**2)
    return 10 * np.log10(peak_power / floor_power)