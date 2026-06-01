# FPGA-Based OFDM Radar System

This project is a Python-based OFDM transmitter/receiver simulation being developed as the golden model for a future FPGA-based OFDM radar system. The project focuses on QPSK modulation, OFDM waveform generation, receiver-side bit recovery, channel modeling, and radar-style range-Doppler processing.

The long-term goal is to move this system from a Python DSP model into FPGA-ready SystemVerilog modules that can support real-time radar and wireless sensing applications.

---

## Current Project Status

Current implemented chain:

```text
bits.txt
↓
QPSK Mapper
↓
64-Subcarrier OFDM Symbol Mapper
↓
IFFT
↓
Cyclic Prefix Insertion
↓
Time-Domain Complex Baseband Signal
↓
Receiver Reconstruction
↓
Cyclic Prefix Removal
↓
FFT
↓
QPSK Demapper
↓
Recovered Bits
↓
BER Calculation
```

Current completed features:

- Generate random binary input data
- Save transmitted bits to `bits.txt`
- Convert bits into QPSK symbols
- Use Gray-coded QPSK mapping
- Group QPSK symbols into 64-subcarrier OFDM symbols
- Pad incomplete OFDM symbols with `0 + 0j`
- Track original bit length before padding
- Track original QPSK symbol length before OFDM padding
- Generate time-domain OFDM symbols using IFFT
- Add cyclic prefix to each OFDM symbol
- Save complex transmitted samples to `transmitted_bits.txt`
- Save receiver metadata for reconstruction
- Rebuild complex baseband samples in the receiver
- Remove cyclic prefix
- Apply FFT to recover subcarrier symbols
- Demap QPSK symbols back into bits
- Compare transmitted and received bits
- Calculate Bit Error Rate
- Simulate radar target delay and Doppler effects
- Generate range-Doppler processing output

---

## Project Goal

The goal of this project is to build an OFDM communication and radar signal-processing system from the ground up.

The first milestone is a working digital baseband OFDM transmitter and receiver that can recover transmitted bits with clean BER performance. After the communication chain is verified, the project expands into OFDM radar processing by modeling reflected target returns, Doppler shifts, and range-Doppler maps.

This project is being built as a learning and development platform for:

- Digital signal processing
- OFDM modulation
- QPSK symbol mapping
- Complex baseband I/Q signals
- FFT and IFFT processing
- Cyclic prefix insertion and removal
- Bit recovery and BER testing
- Multipath channel modeling
- Radar target modeling
- Range and Doppler estimation
- FPGA-ready DSP architecture
- SystemVerilog RTL design and verification
- Future hardware testing with DAC/ADC-style signal chains

---

## Resume Alignment

This README is written to match the project description used on my resume.

Resume project focus:

```text
64-subcarrier QPSK OFDM transmitter/receiver
Python DSP golden model
IFFT/FFT processing
Cyclic prefix handling
Multipath channel behavior
Recovered bit accuracy
Radar target modeling
Delayed returns
Doppler shifts
Reflection amplitudes
Range-Doppler processing
FPGA-ready SystemVerilog implementation
Baseband signal-chain support for ADC/DAC hardware testing
```

This GitHub project supports that entry by showing the actual technical pipeline behind the resume description.

---

## OFDM Architecture

### Transmitter Chain

```text
Input Data
↓
QPSK Mapper
↓
Subcarrier Mapper
↓
IFFT
↓
Cyclic Prefix Insertion
↓
Parallel-to-Serial Conversion
↓
DAC / Baseband Output
```

### Receiver Chain

```text
ADC / Baseband Input
↓
Frame Acquisition
↓
Serial-to-Parallel Conversion
↓
Cyclic Prefix Removal
↓
FFT
↓
Equalization
↓
QPSK Demapper
↓
Recovered Bits
↓
BER Checker
```

### Radar Processing Chain

```text
Known OFDM Symbols
↓
Target Channel
↓
Delayed Reflections
↓
Doppler Shift
↓
Receiver FFT
↓
Channel Estimation
↓
Range IFFT
↓
Doppler FFT
↓
Range-Doppler Map
```

---

## Current Transmitter Flow

The current Python transmitter performs the following process:

```text
Generate Bits
↓
Save Bits
↓
Read Bits
↓
Map Bits to QPSK Symbols
↓
Group Symbols into 64-Subcarrier OFDM Blocks
↓
Apply IFFT
↓
Add Cyclic Prefix
↓
Flatten Signal
↓
Save Time-Domain Complex Samples
```

---

## Current Receiver Flow

The current Python receiver performs the following process:

```text
Read Transmitted Samples
↓
Reconstruct Complex Samples
↓
Read Metadata
↓
Reshape into OFDM Blocks
↓
Remove Cyclic Prefix
↓
Apply FFT
↓
Flatten Frequency-Domain Symbols
↓
Trim Padding
↓
Demap QPSK Symbols
↓
Recover Bits
↓
Compare Against Original Bits
↓
Calculate BER
```

---

## 1. Input Data

The input data is stored in:

```text
bits.txt
```

The transmitter currently generates random bits using:

```python
N = 64
NUM_OFDM_SYMBOLS = 64
BITS_PER_QPSK = 2

num_bits = N * NUM_OFDM_SYMBOLS * BITS_PER_QPSK
bits = np.random.randint(0, 2, num_bits)
```

This generates enough bits to fill 64 OFDM symbols with 64 QPSK subcarriers each.

Since QPSK carries 2 bits per symbol:

```text
64 subcarriers × 64 OFDM symbols × 2 bits/symbol = 8192 bits
```

---

## 2. QPSK Mapper

The QPSK mapper converts every 2 bits into one complex-valued symbol.

Current Gray-coded QPSK mapping:

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

The mapper also saves the original bit length:

```python
original_len
```

This allows the receiver to remove any extra padded bit after demapping.

---

## 3. 64-Subcarrier Symbol Mapper

The symbol mapper groups QPSK symbols into OFDM blocks.

Current number of subcarriers:

```python
N = 64
```

Each OFDM symbol contains 64 frequency-domain subcarriers.

If the final OFDM block is incomplete, the mapper pads the remaining positions with:

```text
0 + 0j
```

The mapper saves the original number of QPSK symbols:

```python
original_len_symbol
```

This allows the receiver to remove padded subcarrier symbols after FFT recovery.

---

## 4. IFFT Block

The IFFT converts the frequency-domain QPSK subcarriers into time-domain OFDM samples.

Current Python implementation:

```python
time_domain_signals = np.fft.ifft(N_symbols, axis=1)
```

Before IFFT:

```text
QPSK symbols placed across frequency-domain subcarriers
```

After IFFT:

```text
Time-domain complex OFDM waveform
```

The IFFT is the core operation that creates the OFDM waveform.

---

## 5. Cyclic Prefix Insertion

The cyclic prefix copies the last part of an OFDM symbol and places it at the front.

Current implementation:

```python
gi = time_domain_signals[:, -CP_LEN:]
time_domain_signals = np.concatenate((gi, time_domain_signals), axis=1)
```

Example:

```text
Original OFDM symbol:
x0 x1 x2 x3 x4 x5 x6 x7

Cyclic prefix length = 2

OFDM symbol with cyclic prefix:
x6 x7 x0 x1 x2 x3 x4 x5 x6 x7
```

The cyclic prefix helps protect the OFDM symbol from multipath delay spread.

---

## 6. Transmitted Sample File

After cyclic prefix insertion, the OFDM samples are flattened into one continuous stream:

```python
signal = time_domain_signals.flatten()
```

The transmitted samples are saved to:

```text
transmitted_bits.txt
```

Each sample includes:

```text
sample_index,time_seconds,real,imag
```

Example:

```text
0,0.0,0.03125,-0.09375
1,5e-08,0.1916716392461547,-0.1838746214733744
2,1e-07,-0.022238491809712435,-0.031643020151803036
```

Metadata is saved at the bottom of the file:

```text
original_length,original_len_symbol,N,BANDWIDTH,CP_LEN,TS
```

This metadata lets the receiver reconstruct the OFDM frame correctly.

---

## OFDM Parameters

Current parameters:

```python
N = 64
BANDWIDTH = 20_000_000
CARRIER_SPACING = BANDWIDTH / N
T = 1 / CARRIER_SPACING
SAMPLE_RATE = N * CARRIER_SPACING
T_GI = 0.8e-6
CP_LEN = int(np.ceil(T_GI * BANDWIDTH))
TS = 1 / SAMPLE_RATE
```

With these values:

```text
Bandwidth:              20 MHz
Subcarriers:            64
Carrier spacing:        312.5 kHz
Sample rate:            20 MS/s
Sample period:          50 ns
OFDM symbol time:       3.2 µs
Guard interval time:    0.8 µs
Cyclic prefix length:   16 samples
Total block length:     80 samples
```

Explanation:

```text
Carrier spacing = Bandwidth / Number of subcarriers
Sample rate = Number of subcarriers × Carrier spacing
OFDM symbol time = 1 / Carrier spacing
Sample period = 1 / Sample rate
Cyclic prefix length = Guard interval time × Bandwidth
```

---

## File Structure

```text
OFDM Simulation/
│
├── bits.txt
├── transmitted_bits.txt
├── transmitter_main.py
├── recevier_main.py
├── QPSK_Mapper.py
├── Symbol_Mapper.py
├── Demapper.py
├── Multipath_channel.py
├── radar_target_channel.py
└── README.md
```

---

## Main Python Files

### `transmitter_main.py`

This file connects the transmitter pipeline.

Main flow:

```python
complex_bits, original_len = qpsk_mapper(bit_string)

N_symbols, original_len_symbol = symbol_mapper(complex_bits, N)

time_domain_signals = np.fft.ifft(N_symbols, axis=1)

gi = time_domain_signals[:, -CP_LEN:]
time_domain_signals = np.concatenate((gi, time_domain_signals), axis=1)

signal = time_domain_signals.flatten()
```

The flow is:

```text
Generate bits
↓
Save bits
↓
QPSK mapping
↓
64-subcarrier OFDM grouping
↓
IFFT
↓
Cyclic prefix insertion
↓
Sample stream generation
↓
Transmitted sample export
```

---

### `QPSK_Mapper.py`

This file maps binary input bits into QPSK complex symbols.

Input:

```text
Bit string from bits.txt
```

Output:

```text
Complex QPSK symbol array
Original bit length
```

Example output:

```text
[ 1.+1.j, -1.+1.j, -1.-1.j, 1.-1.j ]
```

---

### `Symbol_Mapper.py`

This file groups QPSK symbols into 64-subcarrier OFDM symbols.

Input:

```text
QPSK symbol array
```

Output:

```text
2D array of OFDM frequency-domain symbols
Original number of QPSK symbols
```

Example shape:

```text
(64, 64)
```

This means:

```text
64 OFDM symbols with 64 subcarriers each
```

---

### `recevier_main.py`

This file performs receiver-side reconstruction and BER recovery.

Main receiver flow:

```python
rx_signal = complex_samples.copy()

BLOCK_LEN = N + CP_LEN
num_blocks = len(rx_signal) // BLOCK_LEN
rx_signal = rx_signal[:num_blocks * BLOCK_LEN]

rx_signal = rx_signal.reshape(-1, BLOCK_LEN)
rx_no_cp = rx_signal[:, CP_LEN:]

frequency_domain_signals = np.fft.fft(rx_no_cp, axis=1)

X_hat = frequency_domain_signals.flatten()
X_hat = X_hat[:original_len_symbol]

rx_bits = demapper(X_hat, original_length, original_len_symbol)
```

The receiver compares the recovered bits against the original transmitted bits to calculate BER.

---

### `Demapper.py`

This file maps received QPSK symbols back into bits.

Current demapper decision rules:

```text
real ≥ 0, imag ≥ 0 → 00
real < 0, imag ≥ 0 → 01
real < 0, imag < 0 → 11
real ≥ 0, imag < 0 → 10
```

After demapping, the recovered bitstream is trimmed back to the original transmitted bit length.

---

### `Multipath_channel.py`

This file simulates a simple multipath channel.

Current impulse response:

```python
h[0] = 1.0
h[3] = 0.5
h[7] = 0.2
```

The transmitted signal is convolved with this channel:

```python
rx_signal = np.convolve(tx_signal, h)
```

AWGN noise can also be added based on a selected SNR value.

This block is used to test cyclic prefix behavior and future equalization.

---

### `radar_target_channel.py`

This file simulates a radar target channel.

Each target contains:

```python
targets = [
    {
        "range": 100,
        "velocity": 0,
        "rcs": 1
    }
]
```

The channel models:

- Round-trip propagation delay
- Doppler shift
- Reflection amplitude
- Radar cross section
- Optional AWGN noise

Delay is calculated using:

```python
time_delay = 2 * range_m / c
sample_delay = int(time_delay * sample_rate)
```

Doppler shift is calculated using:

```python
doppler_shift = 2 * velocity_m_s * carrier_freq / c
```

---

## How to Run

Install required packages:

```bash
pip install numpy matplotlib scipy
```

Run the transmitter:

```bash
python3 transmitter_main.py
```

Run the receiver:

```bash
python3 recevier_main.py
```

Expected clean loopback output:

```text
Number of bit errors: 0 out of 8192
Bit Error Rate (BER): 0.000000
```

The exact number of bits may change depending on the number of OFDM symbols.

---

## Clean BER Recovery

For clean BER recovery, the first receiver test should use ideal digital loopback:

```python
rx_signal = complex_samples.copy()
```

This means the received signal is exactly the transmitted signal.

Clean BER recovery path:

```text
Transmitted samples
↓
Reshape into OFDM blocks
↓
Remove cyclic prefix
↓
FFT
↓
Recover QPSK symbols
↓
Demap bits
↓
Compare against original bits
```

The key receiver variable is:

```python
X_hat = frequency_domain_signals.flatten()
```

Then padded QPSK symbols are removed:

```python
X_hat = X_hat[:original_len_symbol]
```

Then the demapper recovers bits:

```python
rx_bits = demapper(X_hat, original_length, original_len_symbol)
```

Expected result for the no-channel test:

```text
BER = 0
```

This test should pass before adding noise, multipath, radar targets, or hardware testing.

---

## Radar Processing

The radar processing path uses known transmitted OFDM symbols to estimate the channel response.

The received signal can be generated through the radar target channel:

```python
rx_signal = radar_target_channel(
    complex_samples,
    1 / TS,
    CARRIER_FREQ,
    targets,
    None
)
```

After cyclic prefix removal and FFT, the channel estimate is calculated using:

```python
H_est = frequency_domain_signals / (X + 1e-12)
```

The range profile is calculated using:

```python
range_profile = np.fft.ifft(H_est, axis=1)
```

The range-Doppler map is calculated using:

```python
range_doppler = np.fft.fftshift(
    np.fft.fft(range_profile, axis=0),
    axes=0
)
```

The final map is converted into dB:

```python
rd_map_db = 20 * np.log10(np.abs(range_doppler) + 1e-12)
```

This processing path is used to analyze target delay and Doppler response.

---

## Communication Mode vs Radar Mode

The receiver should stay separated into two logical modes.

### Communication Mode

Communication mode is used for bit recovery and BER testing.

```text
Received OFDM signal
↓
Remove cyclic prefix
↓
FFT
↓
QPSK demapper
↓
Recovered bits
↓
BER calculation
```

This mode answers:

```text
Did the receiver recover the transmitted bits correctly?
```

### Radar Mode

Radar mode is used for range and Doppler estimation.

```text
Received OFDM signal
↓
Remove cyclic prefix
↓
FFT
↓
Channel estimation
↓
Range profile
↓
Doppler processing
↓
Range-Doppler map
```

This mode answers:

```text
Where is the target and how fast is it moving?
```

Keeping these modes separate makes the project easier to debug and easier to convert into FPGA modules later.

---

## Analog Discovery 2 Baseband Testing Plan

Before hardware testing, the Python simulation should first achieve:

```text
BER = 0
```

in ideal loopback mode.

Planned baseband hardware setup:

```text
Python OFDM Signal
↓
Export I and Q Samples
↓
AD2 Wavegen Channel 1 Outputs I(t)
↓
AD2 Wavegen Channel 2 Outputs Q(t)
↓
AD2 Scope Channel 1 Captures I(t)
↓
AD2 Scope Channel 2 Captures Q(t)
↓
Python Reconstructs Complex Signal
↓
Receiver Calculates BER
```

Reconstructing the received signal:

```python
rx_complex = rx_i + 1j * rx_q
```

For the first AD2 test, the bandwidth should be lowered from 20 MHz to a more reliable test range:

```text
500 kHz to 1 MHz
```

This makes the waveform easier to generate, capture, and debug.

---

## Future FPGA Implementation Plan

After the Python OFDM transmitter and receiver are working correctly, the next major goal is to move the design onto an FPGA.

The Python simulation acts as the golden reference model. This means the Python version defines the expected behavior before each block is rewritten in SystemVerilog.

The FPGA development path is:

```text
Python Floating-Point Model
↓
Python Fixed-Point Model
↓
SystemVerilog RTL Modules
↓
SystemVerilog Testbenches
↓
Vivado Simulation
↓
Synthesis
↓
FPGA Hardware Testing
↓
DAC/ADC or AD2 Baseband Testing
```

---

## Planned FPGA Transmitter Chain

The first FPGA goal is to implement the OFDM transmitter.

Planned FPGA transmitter:

```text
Input Bits
↓
QPSK Mapper
↓
Subcarrier Mapper
↓
Fixed-Point IFFT
↓
Cyclic Prefix Insertion
↓
Parallel-to-Serial Output
↓
DAC / External Output Interface
```

The transmitter will take digital bits and produce fixed-point I/Q OFDM samples.

---

## Planned FPGA Receiver Chain

After the transmitter is working, the next goal is to implement the receiver.

Planned FPGA receiver:

```text
ADC / Input Samples
↓
Frame Synchronization
↓
Serial-to-Parallel Buffer
↓
Cyclic Prefix Removal
↓
Fixed-Point FFT
↓
Equalizer
↓
QPSK Demapper
↓
Recovered Bits
↓
BER Checker
```

The first receiver version will assume ideal timing and no channel distortion. Later versions will add synchronization, equalization, and noise tolerance.

---

## FPGA Modules to Build

Planned SystemVerilog modules:

```text
qpsk_mapper.sv
symbol_mapper.sv
ifft_core.sv
cyclic_prefix_insert.sv
parallel_to_serial.sv
serial_to_parallel.sv
cyclic_prefix_remove.sv
fft_core.sv
qpsk_demapper.sv
ber_checker.sv
```

Each module should be tested separately before connecting the full pipeline.

---

## FPGA Testbench Strategy

Each FPGA block will have its own testbench.

Testbench plan:

```text
Generate expected values in Python
↓
Save Python test vectors
↓
Load test vectors into SystemVerilog testbench
↓
Run Vivado simulation
↓
Compare RTL output against Python output
```

This keeps the Python model as the reference design for the FPGA implementation.

Example testbenches:

```text
qpsk_mapper_tb.sv
cyclic_prefix_insert_tb.sv
qpsk_demapper_tb.sv
ber_checker_tb.sv
ofdm_tx_tb.sv
ofdm_rx_tb.sv
```

---

## Fixed-Point Conversion Plan

The current Python simulation uses floating-point complex values.

The FPGA implementation will use fixed-point signed integers.

Current Python QPSK symbols:

```text
1 + 1j
-1 + 1j
-1 - 1j
1 - 1j
```

Possible 16-bit fixed-point representation:

```text
1  →  16'sd1024
-1 → -16'sd1024
```

Hardware QPSK mapping:

```text
00 → I =  1024, Q =  1024
01 → I = -1024, Q =  1024
11 → I = -1024, Q = -1024
10 → I =  1024, Q = -1024
```

This preserves the QPSK constellation in a hardware-friendly format.

---

## FPGA Radar Extension Plan

Once the communication transmitter and receiver are working on FPGA, the design can be extended toward OFDM radar processing.

Planned FPGA radar flow:

```text
Known OFDM Symbol Transmission
↓
Received Reflected Signal
↓
FFT
↓
Channel Estimation
↓
Range IFFT
↓
Doppler FFT
↓
Range-Doppler Output
```

The radar version will use known transmitted OFDM symbols to estimate the channel response.

The range profile is generated using:

```text
range_profile = IFFT(H_est)
```

The Doppler profile is generated by applying an FFT across multiple OFDM symbols.

---

## Current Progress

### Completed

- [x] Random bit generation
- [x] Input bitstream saved to `bits.txt`
- [x] QPSK mapper
- [x] 64-subcarrier symbol mapper
- [x] Zero padding for incomplete OFDM symbols
- [x] IFFT for OFDM waveform generation
- [x] Cyclic prefix insertion
- [x] Transmitted sample file generation
- [x] Metadata export for receiver reconstruction
- [x] Receiver sample parsing
- [x] Cyclic prefix removal
- [x] Receiver FFT
- [x] QPSK demapper
- [x] Bit recovery check
- [x] BER calculation
- [x] Simple multipath channel model
- [x] Radar target channel model
- [x] Range-Doppler map generation

### In Progress

- [ ] Clean separation between communication mode and radar mode
- [ ] Cleaner receiver file structure
- [ ] AWGN BER testing
- [ ] Multipath equalization
- [ ] Receiver constellation plotting after FFT
- [ ] Analog Discovery 2 waveform export
- [ ] I/Q baseband hardware loopback testing
- [ ] Python fixed-point conversion model
- [ ] SystemVerilog QPSK mapper

### Future Work

- [ ] Scrambler
- [ ] Convolutional encoder
- [ ] Puncturing
- [ ] Interleaver
- [ ] Pilot subcarriers
- [ ] Synchronization preamble
- [ ] Per-carrier equalizer
- [ ] Frequency offset correction
- [ ] Phase offset correction
- [ ] De-interleaver
- [ ] De-puncturing
- [ ] Viterbi decoder
- [ ] De-scrambler
- [ ] Convert Python floating-point model to fixed-point model
- [ ] Generate Python test vectors for FPGA verification
- [ ] Build SystemVerilog QPSK mapper
- [ ] Build QPSK mapper testbench
- [ ] Build fixed-point subcarrier mapper
- [ ] Add Vivado FFT/IFFT IP core
- [ ] Add cyclic prefix insertion module
- [ ] Add cyclic prefix removal module
- [ ] Build BER checker module
- [ ] Compare FPGA simulation output against Python output
- [ ] Create full FPGA OFDM transmitter chain
- [ ] Create full FPGA OFDM receiver chain
- [ ] Add FPGA radar processing path
- [ ] Complete Analog Discovery 2 baseband testing
- [ ] Add DAC/ADC hardware signal-chain support

---

## Why This Project Matters

This project builds practical experience in:

- OFDM communication systems
- Digital signal processing
- Complex-valued signals
- I/Q baseband representation
- QPSK modulation
- FFT/IFFT processing
- Cyclic prefix design
- BER testing
- Channel simulation
- Radar signal processing
- Range-Doppler processing
- Python-based communication simulation
- FPGA-ready DSP architecture
- SystemVerilog RTL development
- Hardware testbench design
- Waveform-based debugging
- DAC/ADC signal-chain planning

The long-term goal is to convert the Python model into a real-time FPGA implementation for OFDM communication and radar signal processing.

---

## Long-Term FPGA Goal

The final goal is to convert the Python OFDM model into a real FPGA implementation.

Planned FPGA system:

```text
Input Bits
↓
QPSK Mapper
↓
Subcarrier Mapper
↓
Fixed-Point IFFT
↓
Cyclic Prefix Insertion
↓
Sample Output Stream
↓
Receiver Input Stream
↓
Cyclic Prefix Removal
↓
Fixed-Point FFT
↓
QPSK Demapper
↓
Recovered Bits
↓
BER Checker
↓
Radar Processing Extension
```

Important FPGA concepts involved:

- Fixed-point arithmetic
- Signed binary representation
- Complex number representation using I and Q channels
- Complex multiplication
- Complex addition
- FFT/IFFT butterflies
- Twiddle factors
- Pipelining
- Memory buffering
- Valid/ready handshaking
- Timing closure
- Hardware testbenches
- Python-generated test vectors
- Vivado waveform verification
- DAC/ADC interfacing
- I/Q sample streaming

The final system should support both OFDM communication recovery and OFDM radar processing.

---

## Author

Sourish Manthati

Electrical Engineering student focused on RF systems, FPGA design, digital signal processing, radar systems, semiconductor design, and defense technology.
