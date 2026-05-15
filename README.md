# OFDM Transmitter/Receiver Simulation

This project implements a basic Orthogonal Frequency Division Multiplexing (OFDM) communication pipeline in Python, with the long-term goal of extending the design into an FPGA-based OFDM radar system.

The project follows a standard OFDM architecture with both transmitter and receiver stages. The current implementation focuses on the digital baseband transmitter chain.

---

## Current Project Status

Current implemented chain:

```text
bits.txt → QPSK Mapper → N-Subcarrier Symbol Mapper → IFFT → Time-Domain OFDM Signal
```

Current completed features:

- Read binary input data from a text file
- Convert bits into QPSK symbols
- Group QPSK symbols into `N` OFDM subcarriers
- Pad incomplete OFDM symbols with `0 + 0j`
- Use IFFT to generate time-domain OFDM samples
- Plot the time-domain OFDM waveform

---

## Project Goal

The goal of this project is to build and understand an OFDM communication system from the ground up.

OFDM is used in many modern wireless communication systems because it splits data across multiple orthogonal subcarriers. This allows high data-rate transmission while reducing the effects of multipath interference.

This project is being built as a learning platform for:

- Digital signal processing
- OFDM modulation
- QPSK symbol mapping
- FFT/IFFT processing
- Complex baseband signals
- I/Q signal representation
- FPGA-ready signal processing design
- Future OFDM radar development

---

## OFDM Architecture

### Transmitter Chain

```text
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
↓
Antenna
```

### Receiver Chain

```text
Antenna
↓
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
```

---

## Current Transmitter Flow

The current Python implementation is focused on this simplified transmitter chain:

```text
Input Bits
↓
QPSK Mapper
↓
N-Symbol Mapper
↓
IFFT
↓
Time-Domain OFDM Signal
```

---

## 1. Input Data

The input data is stored in a text file called:

```text
bits.txt
```

Example 64-bit input payload:

```text
0001100000111100011111101111111111111111011111100011110000011000
```

This bitstream can represent a small 8×8 binary image, where:

```text
1 = white pixel
0 = black pixel
```

Example 8×8 image form:

```text
00011000
00111100
01111110
11111111
11111111
01111110
00111100
00011000
```

---

## 2. QPSK Mapper

The QPSK mapper converts every 2 bits into one complex-valued symbol.

The current Gray-coded QPSK mapping is:

```text
00 →  1 + 1j
01 → -1 + 1j
11 → -1 - 1j
10 →  1 - 1j
```

Example:

```text
Input bits:
00 01 11 10

QPSK symbols:
1+1j, -1+1j, -1-1j, 1-1j
```

This converts raw digital bits into complex frequency-domain symbols.

---

## 3. N-Subcarrier Symbol Mapper

The N-symbol mapper groups QPSK symbols into OFDM symbols.

For example, if:

```python
N = 64
```

then each OFDM symbol contains 64 subcarriers.

If the number of QPSK symbols is not divisible by `N`, the mapper pads the remaining subcarrier positions with:

```text
0 + 0j
```

Example:

```text
32 QPSK symbols + 32 zero-padding symbols = 64 total subcarriers
```

This creates one complete OFDM symbol with 64 subcarriers.

---

## 4. IFFT Block

The IFFT converts the frequency-domain OFDM symbol into a time-domain OFDM waveform.

Current Python implementation:

```python
time_domain_signals = np.fft.ifft(N_symbols, axis=1)
```

Before IFFT:

```text
Frequency-domain QPSK symbols placed on subcarriers
```

After IFFT:

```text
Time-domain OFDM waveform samples
```

The IFFT is the key operation that creates the OFDM signal.

---

## OFDM Parameters

Current parameters:

```python
N = 64
BANDWIDTH = 20_000_000
CARRIER_SPACING = BANDWIDTH / N
T = 1 / CARRIER_SPACING
SAMPLE_RATE = N * CARRIER_SPACING
```

With these values:

```text
Bandwidth:          20 MHz
Subcarriers:        64
Carrier spacing:    312.5 kHz
Sample rate:        20 MHz
Sample period:      50 ns
OFDM symbol time:   3.2 µs
```

Explanation:

```text
Carrier spacing = Bandwidth / Number of subcarriers
Sample rate = Number of subcarriers × Carrier spacing
OFDM symbol time = 1 / Carrier spacing
```

For the current setup:

```text
Carrier spacing = 20 MHz / 64 = 312.5 kHz
Sample rate = 64 × 312.5 kHz = 20 MHz
Sample period = 1 / 20 MHz = 50 ns
OFDM symbol time = 1 / 312.5 kHz = 3.2 µs
```

---

## File Structure

```text
OFDM Simulation/
│
├── bits.txt
├── transmitter_main.py
├── QPSK_Mapper.py
├── Symbol_Mapper.py
└── README.md
```

---

## Main Python Files

### `transmitter_main.py`

This file connects the full transmitter pipeline.

Main flow:

```python
complex_bits, original_len = qpsk_mapper(bit_string)

N_symbols, original_len_symbol = symbol_mapper(complex_bits, N)

time_domain_signals = np.fft.ifft(N_symbols, axis=1)
```

The flow is:

```text
Read bits
↓
QPSK mapping
↓
N-subcarrier grouping
↓
IFFT
↓
Time-domain OFDM samples
```

---

### `QPSK_Mapper.py`

This file maps raw bits into QPSK complex symbols.

Input:

```text
Bit string from bits.txt
```

Output:

```text
Array of complex QPSK symbols
```

Example output:

```text
[ 1.+1.j, -1.+1.j, -1.-1.j, 1.-1.j ]
```

The QPSK mapper also tracks the original input length so padding can be removed later during receiver reconstruction.

---

### `Symbol_Mapper.py`

This file groups QPSK symbols into OFDM symbols with `N` subcarriers.

Input:

```text
QPSK symbol array
```

Output:

```text
2D array of OFDM frequency-domain symbols
```

Example shape:

```text
(1, 64)
```

This means:

```text
1 OFDM symbol with 64 subcarriers
```

---

## How to Run

Install the required packages:

```bash
pip install numpy matplotlib
```

Run the transmitter:

```bash
python3 transmitter_main.py
```

Expected terminal output includes:

```text
Number of bits
Number of QPSK symbols
N-symbol array shape
Time-domain OFDM samples after IFFT
```

---

## Plotting the OFDM Signal

The time-domain OFDM signal can be plotted using Matplotlib.

Example:

```python
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
```

Useful plots for this project include:

- Real part of the OFDM signal
- Imaginary part of the OFDM signal
- Magnitude of the OFDM signal
- QPSK constellation
- Input 8×8 bit image
- Frequency-domain subcarrier symbols

---

## Current Progress

### Completed

- [x] Input bitstream from `bits.txt`
- [x] QPSK mapper
- [x] N-subcarrier symbol mapper
- [x] Zero padding for incomplete OFDM symbols
- [x] IFFT for time-domain OFDM signal generation
- [x] Basic OFDM waveform plotting

### In Progress

- [ ] Cyclic prefix insertion
- [ ] QPSK constellation plotting
- [ ] Receiver FFT
- [ ] QPSK demapper
- [ ] Bit recovery check
- [ ] Channel/noise model

### Future Work

- [ ] Scrambler
- [ ] Convolutional encoder
- [ ] Puncturing
- [ ] Interleaver
- [ ] Cyclic prefix removal
- [ ] Per-carrier equalizer
- [ ] De-interleaver
- [ ] De-puncturing
- [ ] Viterbi decoder
- [ ] De-scrambler
- [ ] OFDM radar delay simulation
- [ ] Range estimation
- [ ] Doppler estimation
- [ ] FPGA/SystemVerilog implementation

---

## Planned Cyclic Prefix Block

The next transmitter block is cyclic prefix insertion.

The cyclic prefix copies the last part of an OFDM symbol and places it at the front.

Example:

```text
Original OFDM symbol:
x0 x1 x2 x3 x4 x5 x6 x7

Cyclic prefix length = 2

OFDM symbol with cyclic prefix:
x6 x7 x0 x1 x2 x3 x4 x5 x6 x7
```

The cyclic prefix helps reduce inter-symbol interference caused by multipath propagation.

---

## Planned Receiver Chain

The receiver will reverse the transmitter process.

Planned receiver flow:

```text
Received time-domain signal
↓
Remove cyclic prefix
↓
FFT
↓
Equalization
↓
QPSK demapping
↓
Recover bits
↓
Compare recovered bits to transmitted bits
```

The FFT converts the received time-domain OFDM signal back into frequency-domain subcarrier symbols.

---

## Future OFDM Radar Extension

After the OFDM communication transmitter and receiver are working, this project can be extended into an OFDM radar simulation.

The radar version would:

1. Transmit known OFDM symbols
2. Simulate a delayed reflected signal
3. Add noise and channel effects
4. Use FFT-based processing to estimate delay
5. Convert delay into range

Basic radar range equation:

```text
Range = c × delay / 2
```

where:

```text
c = speed of light
```

The division by 2 is used because the signal travels to the target and then returns back to the receiver.

---

## Why This Project Matters

This project builds practical experience in:

- OFDM communication systems
- Digital signal processing
- Frequency-domain processing
- Complex-valued signals
- I/Q baseband representation
- QPSK modulation
- FFT/IFFT processing
- Python-based communication simulation
- FPGA-ready DSP architecture

The long-term goal is to convert the Python model into a hardware implementation using SystemVerilog and Vivado.

---

## Long-Term FPGA Goal

The eventual FPGA implementation may include:

```text
Input bits
↓
QPSK mapper
↓
Subcarrier mapper
↓
Fixed-point IFFT
↓
Cyclic prefix insertion
↓
Output sample stream
```

Important FPGA concepts involved:

- Fixed-point arithmetic
- Complex multiplication
- Complex addition
- FFT/IFFT butterflies
- Pipelining
- Memory buffering
- Timing closure
- Hardware testbenches
- Vivado waveform verification

---

## Author

Sourish Manthati

Electrical Engineering student interested in FPGA design, digital signal processing, radar systems, semiconductor design, and defense technology.