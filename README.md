# OFDM Communication and Radar System

A 64-subcarrier OFDM transmitter implemented in SystemVerilog on Artix-7, verified sample-by-sample against a Python fixed-point golden model, with an accompanying Python receiver and OFDM radar range-Doppler processing chain.

The design takes a stored bitstream through QPSK mapping, frame assembly with synchronization and channel-estimation preambles, a 64-point IFFT, cyclic prefix insertion, and buffering, then streams complex baseband samples off-chip over UART for host-side verification.

---

## Hardware results

Target: **Artix-7 XC7A100T** (Nexys A7-100T), 100 MHz system clock.

| Metric | Value | Utilization |
|---|---|---|
| Slice LUTs | 1,570 | 2.48% |
| Slice Registers | 2,942 | 2.32% |
| Block RAM tiles | 4 | 2.96% |
| DSP slices | 6 | 2.50% |
| Bonded IOB | 12 | 5.71% |

**Timing:** all user-specified timing constraints met at 100 MHz. No setup, hold, or pulse-width violations post-route.

**Verification:** 1,440 complex baseband samples (18 blocks × 80 samples) captured over UART and compared against the Python fixed-point reference. All samples fall within ±2 LSB of golden, with residual error attributable to rounding in the Xilinx FFT core.

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
    uart_tx.sv                      115200 8N1 transmitter
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

`python_verify.py` reassembles the captured byte stream into signed 16-bit I/Q pairs, compares all 1,440 samples against the golden file, and reports per-sample error alongside maximum real and imaginary deviation. The ±2 LSB threshold separates rounding noise in the FFT core from genuine logic errors — a necessary distinction, since exact bit-match is not achievable through a fixed-point IP block with internal scaling.

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
