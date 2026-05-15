# OFDM
# OFDM Transmitter/Receiver Simulation

This project implements a basic Orthogonal Frequency Division Multiplexing (OFDM) communication pipeline in Python, with the long-term goal of extending the design into an FPGA-based OFDM/radar system.

The project follows a standard OFDM architecture:

## Transmitter Chain

```text
Data → Scrambler → Convolutional Encoder → Puncture → Interleaver → Mapper
→ Group into Subcarriers → IFFT → Add Cyclic Prefix → DAC/Radio
Receiver Chain
Radio/ADC → Acquisition → Remove Cyclic Prefix → FFT → Per-Carrier Equalizer
→ Demapper → De-Interleaver → De-Puncture → Viterbi Decoder → De-Scrambler

At the current stage, this project focuses on the digital baseband transmitter chain:

bits.txt → QPSK Mapper → N-Subcarrier Symbol Mapper → IFFT → Time-Domain OFDM Signal
Project Goal

The goal of this project is to build and understand an OFDM communication system from the ground up.

OFDM is widely used in modern wireless systems such as Wi-Fi, LTE, 5G, and radar/communication systems because it splits data across many orthogonal subcarriers.

This project is being developed as a learning platform for:

Digital signal processing
OFDM modulation
QPSK symbol mapping
FFT/IFFT processing
Fixed-point and FPGA-ready design
Future OFDM radar development
Current Features

The current Python implementation includes:

Reading a bitstream from a text file
Mapping bits into QPSK symbols
Grouping QPSK symbols into N OFDM subcarriers
Padding symbols when needed
Performing IFFT to create time-domain OFDM samples
Plotting the time-domain OFDM waveform
Current Transmitter Flow
1. Input Data

The input data is stored in a text file:

bits.txt

Example 64-bit image payload:

0001100000111100011111101111111111111111011111100011110000011000

This represents a small 8×8 binary image.

2. QPSK Mapper

The QPSK mapper converts every 2 bits into one complex symbol.

Gray-coded QPSK mapping:

00 →  1 + 1j
01 → -1 + 1j
11 → -1 - 1j
10 →  1 - 1j

Example:

Bits:
00 01 11 10

QPSK Symbols:
1+1j, -1+1j, -1-1j, 1-1j
3. N-Symbol Mapper

The N-symbol mapper groups QPSK symbols into OFDM symbols.

For example, if:

N = 64

then each OFDM symbol contains 64 subcarriers.

If the number of QPSK symbols is not divisible by N, the mapper pads the remaining positions with:

0 + 0j

Example:

32 QPSK symbols + 32 zero-padding symbols = 64 total subcarriers
4. IFFT Block

The IFFT converts the frequency-domain subcarrier symbols into a time-domain OFDM signal.

time_domain_signals = np.fft.ifft(N_symbols, axis=1)

Before IFFT:

Frequency-domain QPSK symbols on subcarriers

After IFFT:

Time-domain OFDM waveform samples
OFDM Parameters

Current OFDM parameters:

N = 64
BANDWIDTH = 20_000_000
CARRIER_SPACING = BANDWIDTH / N
T = 1 / CARRIER_SPACING
SAMPLE_RATE = N * CARRIER_SPACING

With these values:

Bandwidth:          20 MHz
Subcarriers:        64
Carrier spacing:    312.5 kHz
Sample rate:        20 MHz
Sample period:      50 ns
OFDM symbol time:   3.2 µs
File Structure
OFDM Simulation/
│
├── bits.txt
├── transmitter_main.py
├── QPSK_Mapper.py
├── Symbol_Mapper.py
└── README.md
Main Python Files
transmitter_main.py

This file connects the full transmitter pipeline:

Read bits → QPSK mapping → N-symbol mapping → IFFT

Main flow:

complex_bits, original_len = qpsk_mapper(bit_string)

N_symbols, original_len_symbol = symbol_mapper(complex_bits, N)

time_domain_signals = np.fft.ifft(N_symbols, axis=1)
QPSK_Mapper.py

This file maps raw bits into QPSK complex symbols.

Input:

bit string

Output:

array of complex QPSK symbols

Example output:

[ 1.+1.j, -1.+1.j, -1.-1.j, 1.-1.j ]
Symbol_Mapper.py

This file groups QPSK symbols into OFDM symbols with N subcarriers.

Input:

QPSK symbol array

Output:

2D array of OFDM frequency-domain symbols

Example shape:

(1, 64)

This means:

1 OFDM symbol with 64 subcarriers
How to Run

Install the required Python packages:

pip install numpy matplotlib

Run the transmitter:

python3 transmitter_main.py

Expected output includes:

Number of bits
Number of QPSK symbols
N-symbol array shape
Time-domain OFDM samples after IFFT
Plotting the OFDM Signal

The time-domain OFDM signal can be plotted using Matplotlib:

import matplotlib.pyplot as plt
import numpy as np

signal = time_domain_signals.flatten()

TS = 1 / SAMPLE_RATE
t = np.arange(len(signal)) * TS

plt.figure()
plt.plot(t, signal.real)
plt.xlabel("Time (seconds)")
plt.ylabel("Amplitude")
plt.title("OFDM Time-Domain Signal After IFFT - Real Part")
plt.grid(True)
plt.show()

Other useful plots:

Real part of the OFDM signal
Imaginary part of the OFDM signal
Magnitude of the OFDM signal
QPSK constellation
Input 8×8 bit image
Complete OFDM Architecture
Transmitter Blocks
Data
↓
Scrambler
↓
Convolutional Encoder
↓
Puncture
↓
Interleaver
↓
Mapper
↓
Group into Subcarriers
↓
IFFT
↓
Add Cyclic Prefix
↓
Parallel-to-Serial Conversion
↓
DAC / Radio
Receiver Blocks
Radio / ADC
↓
Acquisition
↓
Remove Cyclic Prefix
↓
FFT
↓
Per-Carrier Equalizer
↓
Demapper
↓
De-Interleaver
↓
De-Puncture
↓
Viterbi Decoder
↓
De-Scrambler
↓
Recovered Data
Current Progress

Completed:

 Input bitstream from bits.txt
 QPSK mapper
 N-subcarrier symbol mapper
 Zero padding for incomplete OFDM symbols
 IFFT for time-domain OFDM generation
 Basic OFDM waveform plotting

In progress:

 Cyclic prefix insertion
 QPSK constellation plotting
 Receiver FFT
 Demapper
 Bit recovery check
 Channel/noise model

Future work:

 Scrambler
 Convolutional encoder
 Puncturing
 Interleaver
 Viterbi decoder
 Per-carrier equalizer
 OFDM radar delay simulation
 Range estimation
 FPGA/SystemVerilog implementation
Future OFDM Radar Extension

After the communication transmitter and receiver are working, this project can be extended into an OFDM radar simulation.

The radar version would:

Transmit known OFDM symbols
Simulate a delayed reflected signal
Add noise and channel effects
Use FFT-based processing to estimate delay
Convert delay into range

Basic range equation:

Range = c × delay / 2

where:

c = speed of light

The division by 2 is because the signal travels to the target and back.

Why This Project Matters

This project builds practical experience in:

OFDM communication systems
DSP and frequency-domain processing
Complex-valued signals
I/Q baseband representation
Python-based communication simulation
FPGA-ready signal processing architecture

The long-term goal is to convert the Python model into a hardware implementation using SystemVerilog and Vivado.

Author

Sourish Manthati

Electrical Engineering student interested in FPGA design, DSP, radar systems, semiconductor design, and defense technology.