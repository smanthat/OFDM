import numpy as np
SC_SEED = 0xB00B3E5
CH_SEED = 0xDEADBEEF
_QPSK_MAP = np.array([1+1j, 1-1j, -1+1j, -1-1j])

def timing_preamble_gen(N):
    rng = np.random.default_rng(SC_SEED)
    preamble_freq = np.zeros(N, dtype=complex)
    preamble_freq[::2] = _QPSK_MAP[rng.integers(0, 4, size=N//2)] *np.sqrt(2)  # scale to unit power
    return preamble_freq
def channel_preamble_gen(N):
    rng = np.random.default_rng(CH_SEED)
    return _QPSK_MAP[rng.integers(0, 4, size=N)]