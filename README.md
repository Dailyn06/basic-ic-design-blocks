# Digital Design Practice

A collection of 17 digital circuit exercises in Verilog, covering arbitration, FIFOs, clock-domain crossing, data conversion, and finite-state machines. Each exercise includes RTL, a testbench, and a simulation Makefile.

## Requirements

- **Icarus Verilog**: `iverilog` compiles the design and `vvp` runs the simulation.
- **GNU Make**: runs the supplied simulation targets.
- **GTKWave** (optional): displays VCD waveforms.

The Makefiles compile with `-g2012` to support SystemVerilog features used by the sources.

## Quick start

From the repository root:

```sh
cd gray_counter/sim
make          # Compile and run the testbench
make wave     # Open wave.vcd in GTKWave
make clean    # Remove simv and wave.vcd
```

Use the same commands in any exercise's `sim/` directory. `make sim` is equivalent to `make`. Tool commands can be overridden, for example:

```sh
make IV=/path/to/iverilog VVP=/path/to/vvp
```

## Exercises

Paths link to the exercise directories. The top-level names below are **testbench modules**, as selected by each Makefile.

| Directory | Testbench top | Exercise |
| --- | --- | --- |
| [async_fifo](async_fifo/) | `async_fifo_tb` | Asynchronous FIFO with Gray-code pointers, two-stage pointer synchronization, and almost-full/almost-empty thresholds. |
| [Data_Packet_Detector](Data_Packet_Detector/) | `tb_data` | Packet parser for `0xFF00` + payload + `0xFF01`; reports payload length and packet errors. Payloads contain fewer than 256 bytes and must not contain either marker. |
| [frame_head_detector](frame_head_detector/) | `tb_frame_head` | Detects groups of three consecutive valid `8'h23` bytes and emits a `head_vld` pulse. Other valid bytes reset the count; idle cycles hold it. |
| [arbiter_all/arbiter](arbiter_all/arbiter/) | `tb_arbiter` | Weighted arbitration between A and B using configurable `A_ratio` and `B_ratio` weights. |
| [arbiter_all/fix_arbiter](arbiter_all/fix_arbiter/) | `tb_fix_arbiter` | Combinational priority arbitration from a one-hot base, using `X & ~(X - base)` and wraparound. |
| [arbiter_all/round_arbiter1](arbiter_all/round_arbiter1/) | `tb_round_arbiter` | Round-robin arbitration using `fix_base_arbiter` and a rotating one-hot priority base. |
| [arbiter_all/round_arbiter2](arbiter_all/round_arbiter2/) | `tb_round_arbiter` | Round-robin arbitration using prefix-OR masks, a binary channel index, and `sche_en` priority updates. |
| [divide_3](divide_3/) | `tb_div3` | Divide-by-three clock with a 50% duty cycle using rising-edge and falling-edge registers. |
| [Serial2Parallel](Serial2Parallel/) | `tb_Serial2Parallel` | Six-bit serial-to-parallel conversion, LSB first, with valid/ready handshakes. |
| [edge_detect](edge_detect/) | `tb_edge_detect` | Rising-edge, falling-edge, and both-edge pulse detection using delayed samples. |
| [seq_detector](seq_detector/) | `tb_seq_detector` | FSM exercise for detecting `1101`, with combinational match output and continued sequence detection. |
| [Parallel2Serial](Parallel2Serial/) | `tb_Parallel2Serial` | Six-bit parallel-to-serial conversion, LSB first, with backpressure support. |
| [gray_counter](gray_counter/) | `tb_gray_counter` | Configurable-width binary counter with Gray-code output: `gray = binary ^ (binary >> 1)`. |
| [sync_fifo](sync_fifo/) | `tb_sync_fifo` | Single-clock FIFO with extended read/write pointers and registered read data. |
| [clock_mux](clock_mux/) | `tb_clock_mux` | Clock switching using falling-edge enables and synchronized feedback between clock domains. |
| [pulse_sync](pulse_sync/) | `tb_pulse_sync` | Pulse transfer across clock domains using a toggle, synchronization, and edge detection. Source pulses need sufficient spacing for each transition to propagate. |
| [ping_pong](ping_pong/) | `tb_ping_pong` | Two-bank buffer with bank readiness tracking, registered read data, and write backpressure. |

## Repository layout

Each exercise follows this structure, including the four exercises under `arbiter_all/`:

```text
<exercise>/
├── rtl/          # Design source
├── tb/           # Testbench source
└── sim/
    └── Makefile  # Compile, simulate, view waveforms, and clean
```

`arbiter_all/round_arbiter1` also compiles `fix_base_arbiter.v` from the neighboring `fix_arbiter/rtl/` directory. Its Makefile includes that dependency automatically. The two round-robin implementations share module names, so run them separately with their respective Makefiles.

## Round-robin implementations

| Feature | `round_arbiter1` | `round_arbiter2` |
| --- | --- | --- |
| Selection method | Subtraction, inversion, and AND | Prefix-OR masks and request filtering |
| Dependency | `fix_base_arbiter` | Self-contained |
| Output | One-hot `grant` | Binary `pointer_o` |
| Priority update | Advances when requests are active | Advances when `sche_en` is asserted |
| No requests | Zero grant; priority holds | Zero index; priority holds |

For the binary-index implementation, check `queue_i` to distinguish an empty request vector from a grant to channel zero. Timing and area comparisons require synthesis for the intended target and parameters.

## Simulation output

Testbenches write `wave.vcd` with `$dumpfile` and `$dumpvars`. Run simulations from the exercise's `sim/` directory so generated files stay together. The `.gitignore` excludes `simv` and VCD files.

Test coverage varies: some benches print stimulus and observed values, while others report pass/fail counts. Review the log and waveform when evaluating an exercise; successful compilation alone does not establish functional correctness.

