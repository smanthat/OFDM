# OFDM Communication and Radar System

A 64-subcarrier OFDM transmitter implemented in SystemVerilog on Artix-7, verified sample-by-sample against a Python fixed-point golden model, with an accompanying Python receiver and OFDM radar range-Doppler processing chain.

The design takes a stored bitstream through QPSK mapping, frame assembly with synchronization and channel-estimation preambles, a 64-point IFFT, cyclic prefix insertion, and buffering, then streams complex baseband samples off-chip over UART for host-side verification.

---

## Hardware results

Target: **Xilinx Artix-7 XC7A100T-1CSG324** on the Digilent Nexys A7-100T, 100 MHz system clock. Vivado 2025.2.

### Timing

| Metric | Value | Failing endpoints | Total endpoints |
|---|---|---|---|
| Worst Negative Slack (setup) | 2.709 ns | 0 | 8,049 |
| Worst Hold Slack | 0.040 ns | 0 | 8,049 |
| Worst Pulse Width Slack | 4.020 ns | 0 | 3,611 |
| Total Negative Slack | 0.000 ns | — | — |

All user-specified timing constraints met. A setup slack of 2.709 ns against a 10.000 ns period implies **F_max ≈ 137 MHz** — roughly 37% headroom, on a −1 speed grade device (the slowest Artix-7 bin).

### Utilization

| Resource | Used | Available | % |
|---|---|---|---|
| Slice LUTs | 1,571 | 63,400 | 2.48 |
| — as logic | 1,199 | 63,400 | 1.89 |
| — as shift register | 372 | 19,000 | 1.96 |
| Slice Registers (FF) | 2,942 | 126,800 | 2.32 |
| Block RAM (RAMB18) | 4 | 270 | 1.48 |
| DSP48E1 | 6 | 240 | 2.50 |
| Bonded IOB | 13 | 210 | 6.19 |
| BUFGCTRL | 1 | 32 | 3.13 |

**By block:**

| Block | LUTs | Registers | BRAM | DSP |
|---|---|---|---|---|
| Xilinx XFFT (64-point) | 1,461 | 2,754 | 0.5 | 6 |
| FIFO Generator | 54 | 88 | 2 | 0 |
| Hand-written RTL | 56 | 100 | 1.5 | 0 |

The FFT core accounts for 93% of LUT usage and all six DSP slices. The sequencing, cyclic prefix, serialization, and UART logic together fit in under 60 LUTs — the design is IP-bound rather than control-bound.

### Routing, DRC, power

6,276 logical nets, 3,553 routable, **100% fully routed with zero routing errors**. Post-route DRC reports zero errors and zero critical warnings. Methodology checks flag three SYNTH-6 warnings (RAM block timing) and twelve TIMING-18 (missing I/O delay on the UART and button pins, which are asynchronous and not timed paths).

Clocking is a single global domain on one BUFGCTRL driving 3,605 loads, with no MMCM or PLL — the 100 MHz board oscillator feeds the datapath directly.

Total on-chip power **0.139 W** (0.042 W dynamic, 0.097 W static), junction temperature 25.6 °C.

### Functional verification

1,440 complex baseband samples (18 blocks × 80 samples) captured over UART and compared against the Python fixed-point golden model. All samples agree within **±2 LSB**.

Bit-exact agreement is not achievable through a fixed-point FFT IP: the golden model quantizes once after a float64 transform, while the hardware requantizes at each of six butterfly stages plus the internal scaling schedule. Per-stage rounding accumulates as a random walk at roughly 1 LSB RMS, so the ±2 LSB threshold separates that noise floor from genuine logic errors.

---

## Transmit chain

```
bits.hex (BRAM)
      │
      ▼
┌─────────────────┐   preamble_timing.txt ──┐
│ frame_sequencer │   preamble_channel.txt ─┤ (BRAM-inferred ROMs)
│  FSM + QPSK map │◄──────────────────────┘
└────────┬────────┘
         │ cplx_t, valid/ready
         ▼
┌─────────────────┐
│  ifft_wrapper   │  Xilinx XFFT over AXI4-Stream
│  64-pt inverse  │  config 8'h54, tlast framing
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    cp_insert    │  64-deep buffer, last 16 samples
│  FSM + circular │  replayed ahead of the block
└────────┬────────┘
         │ 80 samples/block
         ▼
┌─────────────────┐
│    fifo_sync    │  rate decoupling: 100 MHz datapath
│                 │  to 115.2 kbaud UART
└────────┬────────┘
         │ 32-bit words
         ▼
┌─────────────────┐
│ byte_serializer │  32-bit → 4× 8-bit
└────────┬────────┘
         ▼
┌─────────────────┐
│     uart_tx     │  115200 8N1, BAUD_DIV = 868
└────────┬────────┘
         ▼
    host capture → python_verify.py
```

Every stage uses a `valid`/`ready` handshake, so backpressure from the UART propagates cleanly back through the FIFO to the IFFT without dropping samples. This is why the FIFO exists — the datapath produces samples several orders of magnitude faster than the UART can drain them.

---

## Frame structure

18 blocks of 64 subcarriers each:

| Block | Contents | Purpose |
|---|---|---|
| 0 | Timing preamble | Frame synchronization |
| 1 | Channel preamble | Channel estimation |
| 2–17 | QPSK data | 16 blocks × 128 bits = 2048 bits |

The **timing preamble** occupies even-indexed subcarriers only, with odd subcarriers nulled. In the time domain this produces two identical halves within one OFDM symbol — the structure a Schmidl-Cox correlator exploits, since a sliding autocorrelation between the halves peaks at the frame boundary regardless of carrier frequency offset.

The **channel preamble** fills all 64 subcarriers with known QPSK symbols so the receiver can estimate per-subcarrier channel response before demodulating data.

Both preambles are generated from fixed seeds (`SC_SEED`, `CH_SEED`) so the RTL ROM contents and the Python model always agree.

---

## Fixed-point format

All complex samples use **Q2.13** in 16-bit signed representation, defined in `fixed_pkg.sv`:

```systemverilog
package fixed_pkg;
  typedef logic signed [15:0] fixed_t;   // Q2.13 plus sign
  typedef struct packed {
    fixed_t re;
    fixed_t im;
  } cplx_t;
endpackage
```

QPSK constellation points map to ±8192, i.e. ±1.0 in Q2.13:

| Bits | I | Q |
|---|---|---|
| 00 | +8192 | +8192 |
| 01 | −8192 | +8192 |
| 11 | −8192 | −8192 |
| 10 | +8192 | −8192 |

Integer bits above the binary point absorb IFFT gain. The packed struct means a full complex sample moves as one 32-bit AXI-Stream beat.

`fixed_point_reference.py` implements the same quantization on the Python side — scale by 2^F, round, saturate to the W-bit range — and exports hex vectors that both the RTL testbenches and the hardware verification script consume.

---

## Waveform parameters

| Parameter | Value |
|---|---|
| Subcarriers | 64 |
| Bandwidth | 20 MHz |
| Subcarrier spacing | 312.5 kHz |
| Sample rate | 20 MS/s |
| Useful symbol time | 3.2 µs |
| Cyclic prefix | 16 samples (0.8 µs) |
| Block length | 80 samples |
| Modulation | Gray-coded QPSK |

The 25% cyclic prefix follows 802.11a convention and tolerates delay spread up to 0.8 µs — roughly 240 m of excess path length.

---

## Radar processing

The Python model reuses the same OFDM waveform for target sensing. Because the transmitted symbols are known, the channel transfer function follows from an element-wise division:

```
H_est[k, n] = Y[k, n] / X[k, n]
```

**Range** comes from an IFFT across subcarriers — a target at delay τ imposes a linear phase ramp across frequency, which transforms into a peak at the corresponding delay bin.

**Doppler** comes from an FFT across OFDM symbols — a moving target's phase rotates from symbol to symbol at the Doppler frequency.

```python
range_profile = np.fft.ifft(H_est, axis=1)
range_doppler = np.fft.fftshift(np.fft.fft(range_profile, axis=0), axes=0)
rd_map_db     = 20*np.log10(np.abs(range_doppler) + 1e-12)
```

`radar_target_channel.py` models round-trip delay `τ = 2R/c`, Doppler shift `f_d = 2v·f_c/c`, RCS-scaled reflection amplitude, and optional AWGN.

---

## Repository layout

```
OFDM_FPGA/                          Vivado project — synthesis, implementation, bitstream
  OFDM_FPGA.srcs/sources_1/new/
    fixed_pkg.sv                    Q2.13 types, packed complex struct
    qpsk_mapper.sv                  combinational Gray-coded bit → symbol
    preamble_rom.sv                 parameterized BRAM-inferred ROM
    bits_rom.sv                     data bitstream ROM
    frame_sequencer.sv              FSM: preamble + data block sequencing
    ifft_wrapper.sv                 Xilinx XFFT AXI4-Stream wrapper
    cp_insert.sv                    FSM + circular buffer, CP insertion
    fifo_sync.sv                    rate decoupling FIFO
    byte_serializer.sv              32-bit → byte stream
    uart_tx.sv                      115200 8N1 transmitter (uart_tx_fixed in top)
    button_sync.sv                  metastability-hardened button input
    top.sv                          integration, power-on reset

  OFDM_FPGA.srcs/sim_1/new/         11 self-checking testbenches,
                                    one per module plus tb_top

OFDM Simulation/                    Python golden model
  transmitter_main.py               floating-point transmit chain
  Receiver_communication.py         receive chain and BER
  QPSK_Mapper.py  Symbol_Mapper.py  Demapper.py
  preamble_gen.py                   seeded timing/channel preambles
  fixed_point_reference.py          Q-format quantization + hex export
  python_verify.py                  hardware capture vs. golden comparison
  Multipath_channel.py              3-tap channel + AWGN
  compute_range_doppler.py          range-Doppler map

OFDM Simulation Radar/              radar-mode transmit/receive variant
  radar_target_channel.py           delay, Doppler, RCS target model
  receiver_radar.py
```

---

## Verification methodology

Each RTL module is checked against Python-generated vectors before integration, rather than debugging the full chain from an end-to-end mismatch.

```
Python floating-point model
        ↓  fixed_point_reference.py
Python fixed-point model (Q2.13)
        ↓  hex export
Verification_Files/*.txt, *.hex
        ↓
   ┌────┴────┐
   ▼         ▼
RTL testbench   BRAM init
(per module)    (ROM contents)
   ▼              ▼
Vivado sim    hardware run → UART capture
   │              │
   └──── compare ─┴──► python_verify.py
```

`python_verify.py` reassembles the captured byte stream into signed 16-bit I/Q pairs, compares all 1,440 samples against the golden file, and reports per-sample error alongside maximum real and imaginary deviation.

Comparing per-stage rather than end-to-end localizes a failure to a single module instead of leaving a whole-chain mismatch to interpret.

---

## Running it

**Python model:**
```bash
pip install numpy matplotlib scipy
cd "OFDM Simulation"
python3 transmitter_main.py
python3 Receiver_communication.py
```

**Hardware:**
1. Open `OFDM_FPGA/OFDM_FPGA.xpr` in Vivado
2. Update the `INIT_FILE` paths in `frame_sequencer.sv` to your local `Verification_Files/` directory
3. Program the Nexys A7-100T
4. Press the start button; capture the UART stream at 115200 8N1 to `rx_bytes.bin`
5. `python3 python_verify.py`

---

## Roadmap

**Receiver RTL** — the transmit chain is complete on hardware; the receive path currently exists only in Python.
- [ ] Schmidl-Cox timing synchronization in RTL
- [ ] Cyclic prefix removal
- [ ] Forward FFT wrapper
- [ ] Per-subcarrier zero-forcing equalizer
- [ ] QPSK demapper and BER checker

**System**
- [ ] Carrier frequency offset estimation and correction
- [ ] Pilot subcarriers for continuous channel tracking
- [ ] Convolutional encoding, interleaving, Viterbi decode
- [ ] Analog Discovery 2 analog baseband loopback
- [ ] Radar processing path in RTL

---

## Background

Built to work through the full path from a floating-point DSP model to verified hardware: fixed-point analysis, streaming interface design with backpressure, vendor IP integration over AXI4-Stream, per-module verification against golden vectors, timing closure, and hardware-level debugging against a reference.

The joint communication and sensing structure — one waveform serving both data transport and target detection — is the direction automotive radar and integrated 6G sensing are moving, since it avoids duplicating spectrum and RF hardware across two systems.
