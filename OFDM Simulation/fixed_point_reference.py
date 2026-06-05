"""
Fixed-point reference + word-length sweep for the QPSK-OFDM comms chain.

Purpose (Step 1 of the FPGA plan):
  - Reproduce the floating-point BER as a baseline.
  - Quantize each block to fixed-point and measure BER vs word length.
  - Show, per block, where precision actually matters, so the RTL bit
    widths are chosen from data instead of guesswork.

Fixed-point convention: signed two's-complement Q(I).(F)
  total width W = I + F + 1 (the +1 is the sign bit)
  We sweep the FRACTIONAL bits F at a few candidate total widths.
"""

import numpy as np
import json

rng = np.random.default_rng(0)   # fixed seed -> repeatable BER

# ----------------------------------------------------------------------
# Chain parameters (from transmitter_main.py)
# ----------------------------------------------------------------------
N        = 64
BANDWIDTH = 500_000
T_GI     = 0.8e-6
CP_LEN   = int(np.ceil(T_GI * BANDWIDTH))     # = 1 ... (kept identical to source)
SNR_DB   = 20

# ----------------------------------------------------------------------
# Quantizer: signed two's-complement, F fractional bits, W total bits.
# Saturates on overflow (what real hardware does if you don't let it wrap).
# ----------------------------------------------------------------------
def quantize(x, W, F):
    """Quantize real array x to Q format with W total bits, F fractional bits."""
    step = 2.0 ** (-F)
    q = np.round(x / step) * step
    # saturation limits for signed W-bit, F-frac
    max_val = (2.0 ** (W - 1) - 1) * step
    min_val = -(2.0 ** (W - 1)) * step
    return np.clip(q, min_val, max_val)

def qc(x, W, F):
    """Quantize a complex array (real and imag separately)."""
    return quantize(x.real, W, F) + 1j * quantize(x.imag, W, F)

# ----------------------------------------------------------------------
# Build the transmit signal once (floating point), exactly like the source.
# ----------------------------------------------------------------------
def load_bits():
    with open("OFDM Simulation\\bits.txt") as f:
        s = "".join(f.read().split())
    return s

def qpsk_map(bitstr):
    if len(bitstr) % 2 != 0:
        bitstr += "0"
    bits = np.array([int(b) for b in bitstr])
    pairs = bits.reshape(-1, 2)
    sym = np.empty(len(pairs), dtype=complex)
    for i, (s, e) in enumerate(pairs):
        if   s == 0 and e == 0: sym[i] =  1 + 1j
        elif s == 0 and e == 1: sym[i] = -1 + 1j
        elif s == 1 and e == 1: sym[i] = -1 - 1j
        else:                   sym[i] =  1 - 1j
    return sym, len(bitstr)

def symbol_map(sym, N):
    olen = len(sym)
    rem = len(sym) % N
    if rem != 0:
        sym = np.concatenate((sym, np.zeros(N - rem, dtype=complex)))
    return sym.reshape(-1, N), olen

def build_tx():
    bitstr = load_bits()
    sym, original_len = qpsk_map(bitstr)
    N_symbols, original_len_symbol = symbol_map(sym, N)

    preamble = np.ones(N, dtype=complex)
    preamble[::2]  = 1 + 1j
    preamble[1::2] = -1 - 1j
    preamble = preamble.reshape(1, N)

    tx_freq = np.vstack((preamble, N_symbols))     # (n_sym+1, 64)
    tx_time = np.fft.ifft(tx_freq, axis=1)
    gi = tx_time[:, -CP_LEN:]
    tx_time = np.concatenate((gi, tx_time), axis=1)
    return tx_time, preamble.flatten(), original_len, original_len_symbol, bitstr

# ----------------------------------------------------------------------
# Channel (from Multipath_channel.py), deterministic noise via shared rng.
# ----------------------------------------------------------------------
def channel(tx_signal_flat, snr_db=SNR_DB):
    h = np.zeros(N, dtype=complex)
    h[0], h[3], h[7] = 1.0, 0.5, 0.2
    rx = np.convolve(tx_signal_flat, h)
    P = np.mean(np.abs(rx) ** 2)
    npow = P / (10 ** (snr_db / 10))
    noise = np.sqrt(npow / 2) * (rng.standard_normal(len(rx)) + 1j * rng.standard_normal(len(rx)))
    return rx + noise

# ----------------------------------------------------------------------
# Receiver, with optional quantization injected at each stage.
# wl = dict of (W,F) per stage, or None for full floating point.
# ----------------------------------------------------------------------
def demap(symbols, original_len):
    out = []
    for x in symbols:
        out.append(0 if x.real >= 0 else 1) if False else None
        # QPSK Gray demap (matches Demapper.py)
        if   x.real >= 0 and x.imag >= 0: out += [0, 0]
        elif x.real <  0 and x.imag >= 0: out += [0, 1]
        elif x.real <  0 and x.imag <  0: out += [1, 1]
        else:                              out += [1, 0]
    return np.array(out[:original_len], dtype=int)

def receive(tx_time, preamble, original_len, original_len_symbol, wl=None):
    # Flatten, normalize like the AD2 export (so quantization sees realistic range)
    flat = tx_time.flatten()
    flat = flat / np.max(np.abs(flat)) * 0.8

    # ADC quantization of the incoming I/Q stream
    if wl and "adc" in wl:
        flat = qc(flat, *wl["adc"])

    BLOCK = N + CP_LEN
    nb = len(flat) // BLOCK
    blocks = flat[:nb * BLOCK].reshape(-1, BLOCK)[:, CP_LEN:]

    # FFT (we quantize the FFT output, the realistic place precision bites)
    freq = np.fft.fft(blocks, axis=1)
    if wl and "fft" in wl:
        freq = qc(freq, *wl["fft"])

    # Channel estimate + zero-forcing equalize
    H_est = freq[0] / preamble
    if wl and "heq" in wl:
        # quantize the stored reciprocal coefficient (1/H), the high-dynamic-range signal
        recip = 1.0 / (H_est + 1e-12)
        recip = qc(recip, *wl["heq"])
        data_eq = freq[1:] * recip[np.newaxis, :]
    else:
        data_eq = freq[1:] / (H_est[np.newaxis, :] + 1e-12)

    X_hat = data_eq.flatten()[:original_len_symbol]
    return demap(X_hat, original_len)

# ----------------------------------------------------------------------
# Run: baseline + sweeps
# ----------------------------------------------------------------------
def ber_of(rx_bits, bitstr):
    tx = np.array([int(b) for b in bitstr], dtype=int)
    n = min(len(tx), len(rx_bits))
    return np.mean(tx[:n] != rx_bits[:n])

def main():
    tx_time, preamble, olen, olen_sym, bitstr = build_tx()

    # NOTE: receiver in the source demodulates the *clean* tx stream (no channel),
    # using the preamble for equalization. We mirror that so BER is comparable.
    # (The channel function is provided for later use / SNR sweeps.)

    # ---- floating-point baseline ----
    rx = receive(tx_time, preamble, olen, olen_sym, wl=None)
    base = ber_of(rx, bitstr)

    results = {"baseline_ber": base, "sweeps": {}}

    # ---- single shared-width sweep: same (W,F) at every stage ----
    shared = []
    for W in range(6, 17):
        F = W - 3            # leave ~2 integer bits + sign; reasonable for |x|<~4
        wl = {"adc": (W, F), "fft": (W, F), "heq": (W, F)}
        rx = receive(tx_time, preamble, olen, olen_sym, wl=wl)
        shared.append((W, F, ber_of(rx, bitstr)))
    results["sweeps"]["shared"] = shared

    # ---- per-block: vary ONE block, keep others at high precision ----
    HI = (24, 18)   # effectively float for the "held" blocks
    for block in ["adc", "fft", "heq"]:
        rows = []
        for W in range(6, 17):
            F = W - 3
            wl = {"adc": HI, "fft": HI, "heq": HI}
            wl[block] = (W, F)
            rx = receive(tx_time, preamble, olen, olen_sym, wl=wl)
            rows.append((W, F, ber_of(rx, bitstr)))
        results["sweeps"][block] = rows

    # ---- print a readable table ----
    print(f"Floating-point baseline BER: {base:.6f}\n")
    print("SHARED width (all stages same):")
    print("  W   F     BER")
    for W, F, b in shared:
        print(f"  {W:2d}  {F:2d}   {b:.6f}")
    print()
    for block in ["adc", "fft", "heq"]:
        print(f"PER-BLOCK sweep: only '{block}' quantized, others ~float")
        print("  W   F     BER")
        for W, F, b in results["sweeps"][block]:
            print(f"  {W:2d}  {F:2d}   {b:.6f}")
        print()

    with open("/home/claude/sweep_results.json", "w") as f:
        json.dump(results, f, indent=2)

if __name__ == "__main__":
    main()
