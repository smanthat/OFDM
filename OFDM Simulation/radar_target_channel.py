import numpy as np
def radar_target_channel(tx_signal, sample_rate,carrier_freq, targets, snr_db = 20):
    """
    Simulate the radar target channel by applying time delays and Doppler shifts to the transmitted signal.

    Parameters:
    tx_signal (numpy array): The transmitted radar signal.
    sample_rate (float): The sampling rate of the signal in Hz.
    carrier_freq (float): The carrier frequency of the signal in Hz.
    targets (list of dict): A list of target dictionaries, each containing 'range' (in meters) and 'velocity' (in m/s).

    Returns:
    numpy array: The received radar signal after passing through the target channel.
    """


    c = 3e8  # Speed of light in m/s
    rx_signal = np.zeros_like(tx_signal)

    for target in targets:
        range_m = target['range']
        velocity_m_s = target['velocity']

        rcs = target['rcs']

        # Calculate time delay based on range
        time_delay = 2 * range_m / c  # Round trip time
        sample_delay = int(time_delay * sample_rate)  # Convert time delay to samples

        amplitude = 10000 * np.sqrt(target['rcs']) / (target['range'] ** 2)  # Amplitude based on radar cross section


        # Calculate Doppler shift based on velocity
        doppler_shift = 2 * velocity_m_s * carrier_freq / c  # Doppler shift in Hz
        doppler_phase_shift = 2 * np.pi * doppler_shift * np.arange(len(tx_signal)) / sample_rate


        delayed_signal  = np.zeros_like(tx_signal, dtype=complex)

        if(sample_delay == 0):
            delayed_signal = tx_signal.copy()
        elif(sample_delay < len(tx_signal)):
            delayed_signal[sample_delay:] = tx_signal[:-sample_delay]
    
        rx_signal += amplitude * delayed_signal * np.exp(1j * doppler_phase_shift)

    #AWGN noise
    if snr_db is not None:
        P_signal = np.mean(np.abs(rx_signal)**2)
        noise_power = P_signal / (10 ** (snr_db / 10))

        noise = np.sqrt(noise_power / 2) * (
        np.random.randn(len(rx_signal)) + 1j * np.random.randn(len(rx_signal))
        )

        rx_signal += noise
    

    return rx_signal

    