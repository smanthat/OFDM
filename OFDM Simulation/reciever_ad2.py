import numpy as n
import pandas as pd
import matplotlib.pyplot as plt
from Demapper import demapper
import cupy as np


# --------------------------------------------------
# FILE PATHS
# --------------------------------------------------

CAPTURE_FILE = "OFDM Simulation/Recieved_waveform.csv"
TX_BITS_FILE = "OFDM Simulation/bits.txt"
TX_METADATA_FILE = "OFDM Simulation/transmitted_bits.txt"
TX_I_FILE = "OFDM Simulation/ad2_i_waveform.csv"
TX_Q_FILE = "OFDM Simulation/ad2_q_waveform.csv"


# --------------------------------------------------
# READ TRANSMITTER METADATA
# --------------------------------------------------

with open(TX_METADATA_FILE, "r") as f:
    lines = f.readlines()

metadata_values = lines[-1].strip()
metadata = metadata_values.split(",")

original_length = int(metadata[0])
original_len_symbol = int(metadata[1])
N = int(metadata[2])
BANDWIDTH = int(metadata[3])
CP_LEN = int(metadata[4])
TS = float(metadata[5])

BLOCK_LEN = N + CP_LEN
NUM_OFDM_SYMBOLS = int(np.ceil(original_len_symbol / N))
PYTHON_PACKET_LEN = NUM_OFDM_SYMBOLS * BLOCK_LEN

print("Metadata:")
print(f"original_length     = {original_length}")
print(f"original_len_symbol = {original_len_symbol}")
print(f"N                   = {N}")
print(f"BANDWIDTH           = {BANDWIDTH}")
print(f"CP_LEN              = {CP_LEN}")
print(f"TS                  = {TS}")
print(f"BLOCK_LEN           = {BLOCK_LEN}")
print(f"NUM_OFDM_SYMBOLS    = {NUM_OFDM_SYMBOLS}")
print(f"PYTHON_PACKET_LEN   = {PYTHON_PACKET_LEN}")


# --------------------------------------------------
# READ ORIGINAL TX BITS
# --------------------------------------------------

with open(TX_BITS_FILE, "r") as f:
    tx_bits_string = f.read().strip()

tx_bits = np.array([int(b) for b in tx_bits_string])


# --------------------------------------------------
# READ ORIGINAL AD2 WAVEFORM FILES
# --------------------------------------------------
# These are the exact I/Q samples you imported into WaveForms.

tx_i = np.loadtxt(TX_I_FILE, delimiter=",")
tx_q = np.loadtxt(TX_Q_FILE, delimiter=",")
tx_complex = tx_i + 1j * tx_q

tx_complex = tx_complex - np.mean(tx_complex)
tx_complex = tx_complex / np.max(np.abs(tx_complex))

print("\nTX AD2 waveform:")
print(f"TX waveform samples = {len(tx_complex)}")


# --------------------------------------------------
# READ AD2 SCOPE CAPTURE CSV
# --------------------------------------------------

data = pd.read_csv(
    CAPTURE_FILE,
    comment="#",
    engine="python",
    on_bad_lines="skip"
)

# Convert everything possible to numbers and drop bad rows
data = data.apply(pd.to_numeric, errors="coerce")
data = data.dropna()

print("\nCSV info:")
print(data.head())
print(data.columns)
print(f"CSV shape = {data.shape}")

# Usually:
# column 0 = time
# column 1 = Scope Channel 1 = I
# column 2 = Scope Channel 2 = Q
t = data.iloc[:, 0].to_numpy()
rx_i_raw = data.iloc[:, 1].to_numpy()
rx_q_raw = data.iloc[:, 2].to_numpy()

# Remove DC offset
rx_i_raw = rx_i_raw - np.mean(rx_i_raw)
rx_q_raw = rx_q_raw - np.mean(rx_q_raw)

print("\nRX capture:")
print(f"Captured samples = {len(rx_i_raw)}")
print(f"I range = {np.min(rx_i_raw):.4f} to {np.max(rx_i_raw):.4f}")
print(f"Q range = {np.min(rx_q_raw):.4f} to {np.max(rx_q_raw):.4f}")

if len(t) > 1:
    dt = np.mean(np.diff(t))
    fs_capture = 1 / dt
    print(f"Estimated scope sample rate = {fs_capture:.2f} samples/sec")


# --------------------------------------------------
# HELPER: RESAMPLE COMPLEX PACKET
# --------------------------------------------------

def resample_complex_packet(packet, target_len):
    old_x = np.linspace(0, 1, len(packet), endpoint=False)
    new_x = np.linspace(0, 1, target_len, endpoint=False)

    real = np.interp(new_x, old_x, packet.real)
    imag = np.interp(new_x, old_x, packet.imag)

    return real + 1j * imag


# --------------------------------------------------
# HELPER: OFDM RECEIVER
# --------------------------------------------------

def run_ofdm_receiver(rx_packet):
    """
    Input: one OFDM packet with length PYTHON_PACKET_LEN.
    Output: recovered bits and recovered QPSK symbols.
    """

    rx_packet = np.array(rx_packet, dtype=complex)

    # Make length divisible by OFDM block length
    num_blocks = len(rx_packet) // BLOCK_LEN
    rx_packet = rx_packet[:num_blocks * BLOCK_LEN]

    # Reshape into OFDM symbols
    rx_blocks = rx_packet.reshape(-1, BLOCK_LEN)

    # Remove cyclic prefix
    rx_no_cp = rx_blocks[:, CP_LEN:]

    # FFT back to frequency domain
    frequency_domain_signals = np.fft.fft(rx_no_cp, axis=1)

    # Flatten recovered QPSK symbols
    X_hat = frequency_domain_signals.flatten()

    # Remove padded QPSK symbols
    X_hat = X_hat[:original_len_symbol]

    # Demap
    rx_bits = demapper(X_hat, original_length, original_len_symbol)
    rx_bits = np.array(rx_bits, dtype=int)

    return rx_bits, X_hat


# --------------------------------------------------
# HELPER: BER
# --------------------------------------------------

def calculate_ber(rx_bits):
    min_len = min(len(tx_bits), len(rx_bits))
    errors = np.sum(tx_bits[:min_len] != rx_bits[:min_len])
    ber = errors / min_len
    return errors, ber


# --------------------------------------------------
# ESTIMATE CAPTURED PACKET LENGTH
# --------------------------------------------------
# Your Python packet is 1040 samples, but the AD2 capture
# may show one packet as 1050, 1060, etc. because scope
# sampling and Wavegen playback are not perfectly identical.

def estimate_repeated_packet_length(rx_complex, expected_len):
    rx_norm = rx_complex - np.mean(rx_complex)
    rx_norm = rx_norm / (np.std(rx_norm) + 1e-12)

    low = int(expected_len * 0.90)
    high = int(expected_len * 1.15)

    lags = range(low, high)
    scores = []

    for lag in lags:
        if lag >= len(rx_norm):
            scores.append(0)
            continue

        score = abs(np.vdot(rx_norm[:-lag], rx_norm[lag:])) / (len(rx_norm) - lag)
        scores.append(score)

    best_lag = list(lags)[int(np.argmax(scores))]
    return best_lag


# --------------------------------------------------
# TRY MULTIPLE I/Q INTERPRETATIONS
# --------------------------------------------------
# This checks for normal I/Q, inverted Q, swapped I/Q, etc.

iq_modes = {
    "I + jQ": rx_i_raw + 1j * rx_q_raw,
    "I - jQ": rx_i_raw - 1j * rx_q_raw,
    "Q + jI": rx_q_raw + 1j * rx_i_raw,
    "Q - jI": rx_q_raw - 1j * rx_i_raw,
    "-I + jQ": -rx_i_raw + 1j * rx_q_raw,
    "-I - jQ": -rx_i_raw - 1j * rx_q_raw,
}


overall_best = {
    "ber": 1.0,
    "errors": None,
    "start": None,
    "mode": None,
    "capture_packet_len": None,
    "rx_bits": None,
    "X_hat": None,
    "rx_packet": None,
}


for mode_name, rx_complex in iq_modes.items():

    rx_complex = rx_complex - np.mean(rx_complex)

    # Normalize
    rx_complex = rx_complex / (np.max(np.abs(rx_complex)) + 1e-12)

    capture_packet_len = estimate_repeated_packet_length(
        rx_complex,
        PYTHON_PACKET_LEN
    )

    print(f"\nTesting mode: {mode_name}")
    print(f"Estimated captured packet length: {capture_packet_len}")

    max_start = len(rx_complex) - capture_packet_len

    if max_start <= 0:
        print("Not enough samples for this packet length.")
        continue

    best_for_mode = {
        "ber": 1.0,
        "errors": None,
        "start": None,
        "rx_bits": None,
        "X_hat": None,
        "rx_packet": None,
    }

    # Search every possible start position
    for start in range(max_start + 1):
        captured_packet = rx_complex[start:start + capture_packet_len]

        # Resample captured AD2 packet back to Python packet length
        rx_packet = resample_complex_packet(
            captured_packet,
            PYTHON_PACKET_LEN
        )

        # Remove DC and normalize
        rx_packet = rx_packet - np.mean(rx_packet)
        rx_packet = rx_packet / (np.max(np.abs(rx_packet)) + 1e-12)

        # Optional complex scale/phase correction against original waveform
        # This helps if the AD2 capture is scaled or phase-rotated.
        scale = np.vdot(rx_packet, tx_complex) / (np.vdot(rx_packet, rx_packet) + 1e-12)
        rx_packet = rx_packet * scale

        rx_bits, X_hat = run_ofdm_receiver(rx_packet)
        errors, ber = calculate_ber(rx_bits)

        if ber < best_for_mode["ber"]:
            best_for_mode["ber"] = ber
            best_for_mode["errors"] = errors
            best_for_mode["start"] = start
            best_for_mode["rx_bits"] = rx_bits
            best_for_mode["X_hat"] = X_hat
            best_for_mode["rx_packet"] = rx_packet

    print(
        f"Best for {mode_name}: "
        f"start={best_for_mode['start']}, "
        f"errors={best_for_mode['errors']}, "
        f"BER={best_for_mode['ber']:.6f}"
    )

    if best_for_mode["ber"] < overall_best["ber"]:
        overall_best["ber"] = best_for_mode["ber"]
        overall_best["errors"] = best_for_mode["errors"]
        overall_best["start"] = best_for_mode["start"]
        overall_best["mode"] = mode_name
        overall_best["capture_packet_len"] = capture_packet_len
        overall_best["rx_bits"] = best_for_mode["rx_bits"]
        overall_best["X_hat"] = best_for_mode["X_hat"]
        overall_best["rx_packet"] = best_for_mode["rx_packet"]


# --------------------------------------------------
# PRINT FINAL RESULTS
# --------------------------------------------------

print("\n==============================")
print("FINAL BEST AD2 RESULT")
print("==============================")
print(f"Best I/Q mode: {overall_best['mode']}")
print(f"Best start index: {overall_best['start']}")
print(f"Estimated captured packet length: {overall_best['capture_packet_len']}")
print(f"Bit errors: {overall_best['errors']} out of {len(tx_bits)}")
print(f"BER: {overall_best['ber']:.6f}")

if overall_best["ber"] == 0:
    print("AD2 LOOPBACK PASSED")
else:
    print("AD2 LOOPBACK DID NOT FULLY PASS YET")


# --------------------------------------------------
# SAVE RECOVERED BITS
# --------------------------------------------------

if overall_best["rx_bits"] is not None:
    np.savetxt(
        "OFDM Simulation/ad2_recovered_bits.txt",
        overall_best["rx_bits"],
        fmt="%d"
    )
    print("\nSaved recovered bits to:")
    print("OFDM Simulation/ad2_recovered_bits.txt")


# --------------------------------------------------
# PLOTS
# --------------------------------------------------

if overall_best["rx_packet"] is not None:
    rx_packet = overall_best["rx_packet"]

    plt.figure()
    plt.plot(tx_complex.real[:300], label="TX I")
    plt.plot(rx_packet.real[:300], label="Best RX I")
    plt.legend()
    plt.grid(True)
    plt.title("Best Aligned TX I vs RX I")
    plt.show()

    plt.figure()
    plt.plot(tx_complex.imag[:300], label="TX Q")
    plt.plot(rx_packet.imag[:300], label="Best RX Q")
    plt.legend()
    plt.grid(True)
    plt.title("Best Aligned TX Q vs RX Q")
    plt.show()

    X_hat = overall_best["X_hat"]

    plt.figure()
    plt.scatter(X_hat.real, X_hat.imag, s=8)
    plt.title("Recovered QPSK Constellation After FFT")
    plt.xlabel("I")
    plt.ylabel("Q")
    plt.grid(True)
    plt.axis("equal")
    plt.show()