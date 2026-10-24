# 4-core MOESI cache coherency in SystemVerilog

A snoop-based 4-core cache system I wrote to learn how MOESI coherency works in hardware. Four cores each get a private L1 data cache, the caches share a coherency bus, and the bus talks to one shared memory. There is also a UVM verification skeleton (sequences, driver, monitor, scoreboard, coverage covergroups) that is still work in progress.

## What is in the RTL

| File | What it does |
|------|--------------|
| `rtl/moesi_top.sv` | Connects 4 cache controllers, the bus and the memory |
| `rtl/cache_controller.sv` | Per-core L1 controller: hit/miss handling, bus requests, waiting on memory |
| `rtl/moesi_fsm.sv` | Next-state logic for the five MOESI states |
| `rtl/snoop_handler.sv` | Responds to snooped bus requests (supply data, downgrade, invalidate) |
| `rtl/coherency_bus.sv` | Round-robin arbiter and snoop broadcast |
| `rtl/cache_tag_array.sv`, `rtl/cache_data_array.sv` | Tag and data storage |
| `rtl/lru_4way.sv` | 4-way LRU replacement |
| `rtl/shared_memory.sv` | Shared memory model with a fixed read latency |
| `rtl/perf_counters.sv` | Hit/miss style counters |

Default parameters (from the code): 4 cores, 128 sets, 4 ways, 64-byte lines (so 32 KB per cache), 64-bit addresses, 8 MB shared memory, 4-cycle memory read latency.

States: Modified, Owned, Exclusive, Shared, Invalid. The reason for Owned: a cache holding a dirty line can serve a snooped read without writing back to memory first. Longer notes are in `MOESI_Protocol_Notes.md`, `MOESI_SystemVerilog_Architecture.md` and `System_Architecture.md`.

## Verification folder

`verification/` has the UVM pieces: request item and base sequence (`moesi_pkg.sv`), three directed sequences (`moesi_targeted_seqs.sv`), driver, monitor, scoreboard, a covergroup module (`moesi_coverage.sv`) and tests (`moesi_tests.sv`: read hits, read misses, write coherency, cache line bouncing, random coherency).

Status: the environment class in `moesi_tests.sv` is still a placeholder (per-core sequencers only, with a TODO for agents, scoreboard and coverage), so these tests are not yet wired to the RTL. I have not got a coverage number out of this repo, so I am not quoting one.

## Building

The RTL (`rtl/*.sv`, with `rtl/tb_moesi_top.sv` as top) and `verification/moesi_pkg.sv` elaborate cleanly with the slang parser plus the Accellera UVM sources. That is the only check I can point to so far.

The `Makefile` is a Verilator flow. It pulls in the `verification/` files, which import UVM, so I do not know yet whether `make compile` builds without extra UVM setup. I fixed the top module name (it pointed at a module that does not exist), but I have not run the flow end to end. `tb_moesi_top.sv` only drives clock and reset for a short time, so even when it builds it is a smoke run, not a regression.

## Known gaps

- UVM environment not finished (see above).
- No directed check of the full M/O/E/S/I transition set yet.
- L1 only: no L2, no prefetching, 4 cores only.
- Ideas for next steps: finish the UVM env and connect it to `moesi_top`, add assertions for the single-owner rule, add a run log and coverage report to the repo.
