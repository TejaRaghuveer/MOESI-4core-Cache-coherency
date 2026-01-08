# MOESI Cache Coherency System Architecture
## 4-Core Snoop-Based Implementation

**Version:** 1.0  
**Date:** 2024  
**Author:** Design Team

---

## 1. Overview

This document describes the architecture of a 4-core snoop-based cache coherency system implementing the MOESI protocol. The system consists of four processor cores, each with a private L1 data cache, connected via a shared coherency bus to a unified memory controller.

### 1.1 Key Features
- **Protocol:** MOESI (Modified, Owned, Exclusive, Shared, Invalid)
- **Topology:** Snoop-based, shared bus
- **Cores:** 4 independent processor cores
- **Cache Level:** L1 data cache per core
- **Coherency:** Hardware-managed cache coherency

### 1.2 System Goals
- Maintain cache coherency across 4 cores
- Minimize memory traffic through O state optimization
- Support low-latency cache-to-cache transfers
- Scalable bus-based architecture

---

## 2. Cache Hierarchy

### 2.1 L1 Data Cache Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Cache Size** | 32 KB | Total cache capacity per core |
| **Associativity** | 4-way | Set-associative organization |
| **Line Size** | 64 bytes | Cache line size |
| **Sets** | 128 | Number of sets (32KB / (4-way × 64B)) |
| **Tag Width** | 20 bits | Tag bits (32 - 10 index - 6 offset) |
| **Index Width** | 7 bits | Set index bits (log2(128)) |
| **Offset Width** | 6 bits | Byte offset within line (log2(64)) |

### 2.2 Cache Organization

```
Address [31:0] breakdown:
┌──────────┬─────────┬──────────┐
│ Tag[19:0]│Idx[6:0] │Off[5:0] │
└──────────┴─────────┴──────────┘
    20         7         6
```

**Cache Structure:**
- **4 ways** per set
- **128 sets** total
- **64-byte lines** (8 × 64-bit words)
- **MOESI state bits:** 3 bits per tag entry
- **Valid bit:** 1 bit per tag entry
- **Dirty bit:** Implicit (M/O states are dirty)

### 2.3 Replacement Policy
- **Algorithm:** LRU (Least Recently Used)
- **Implementation:** Per-set LRU tracking for 4-way associativity
- **Update:** On every cache access (read or write)

---

## 3. Module List and Responsibilities

### 3.1 Top-Level Module

**moesi_top.sv**
- System top-level module
- Instantiates 4 cores, coherency bus, and shared memory
- Clock and reset distribution
- System-level testbench interface

### 3.2 Per-Core Modules (4 instances)

**cache_controller.sv**
- Main cache controller orchestrating all cache operations
- Interfaces with CPU, tag array, data array, MOESI FSM, and snoop handler
- Handles cache hits/misses, bus transactions, and memory requests
- Coordinates tag/data array accesses and state transitions

**moesi_fsm.sv**
- MOESI state machine implementation
- Manages state transitions (M, O, E, S, I)
- Tracks current state per cache line
- Controls write-back requirements for dirty states (M, O)
- Responds to local operations and snoop requests

**cache_tag_array.sv**
- Tag array storage with MOESI state bits
- 4-way set-associative tag lookup
- Stores: tag bits, MOESI state, valid bit
- Provides hit/miss detection and way matching
- Supports concurrent tag lookup and update

**cache_data_array.sv**
- Data array storage (4-way set-associative)
- 64-byte cache lines (8 × 64-bit words)
- Read/write access with way selection
- Byte-level write enable support

**lru_4way.sv**
- LRU replacement logic for 4-way set-associative cache
- Per-set LRU tracking
- Provides least recently used way for replacement
- Updates on every cache access

**snoop_handler.sv**
- Handles snoop requests from coherency bus
- Performs tag lookup for snooped addresses
- Determines snoop response (hit/miss, state, data)
- Manages state transitions due to snoop operations
- Supplies data for BusRd snoops (M/O/E states)

### 3.3 Shared Modules

**coherency_bus.sv**
- Bus arbiter for core requests
- Routes transactions between cores and memory
- Broadcasts snoop requests to all cores
- Collects and routes snoop responses
- Manages bus arbitration (round-robin or priority-based)
- Handles data routing from responding cache or memory

**shared_memory.sv**
- Main memory controller
- Unified memory interface for all cores
- Handles read/write requests from coherency bus
- Memory access latency modeling
- Data width: 64 bits (cache line width)

---

## 4. Bus and Signal Definitions

### 4.1 Coherency Bus Signals

#### Bus Transaction Types
```systemverilog
localparam BUS_RD    = 2'b00;  // Bus Read (shared read)
localparam BUS_RDX   = 2'b01;  // Bus Read Exclusive (exclusive write)
localparam BUS_UPGR  = 2'b10;  // Bus Upgrade (S→M transition)
```

#### Core-to-Bus Interface (per core)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `core_req` | 1 | Core→Bus | Request bus access |
| `core_type` | 2 | Core→Bus | Transaction type (BusRd/BusRdX/BusUpgr) |
| `core_addr` | 32 | Core→Bus | Memory address |
| `core_wdata` | 64 | Core→Bus | Write data (for BusRdX) |
| `core_grant` | 1 | Bus→Core | Bus grant signal |
| `core_data_valid` | 1 | Bus→Core | Response data valid |
| `core_rdata` | 64 | Bus→Core | Response data |
| `core_snoop_resp` | 1 | Bus→Core | Another cache responded (no memory access) |

#### Snoop Broadcast Interface (to all cores)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `snoop_valid` | 1 | Bus→Core | Snoop request valid |
| `snoop_addr` | 32 | Bus→Core | Snooped address |
| `snoop_type` | 2 | Bus→Core | Snoop type (BusRd/BusRdX/BusUpgr) |
| `snoop_core_id` | 2 | Bus→Core | Requesting core ID |

#### Snoop Response Interface (from cores)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `snoop_resp_valid` | 1 | Core→Bus | Snoop response valid |
| `snoop_resp_data` | 64 | Core→Bus | Snoop response data |
| `snoop_resp_hit` | 1 | Core→Bus | Snoop hit (line present) |

#### Memory Interface
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `mem_req` | 1 | Bus→Mem | Memory request |
| `mem_wr` | 1 | Bus→Mem | Memory write enable |
| `mem_addr` | 32 | Bus→Mem | Memory address |
| `mem_wdata` | 64 | Bus→Mem | Memory write data |
| `mem_ready` | 1 | Mem→Bus | Memory ready |
| `mem_rdata` | 64 | Mem→Bus | Memory read data |

### 4.2 CPU Interface (per core)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `cpu_req` | 1 | CPU→Cache | CPU request valid |
| `cpu_wr` | 1 | CPU→Cache | Write enable (1=write, 0=read) |
| `cpu_addr` | 32 | CPU→Cache | Memory address |
| `cpu_wdata` | 64 | CPU→Cache | Write data |
| `cpu_ready` | 1 | Cache→CPU | Request complete |
| `cpu_rdata` | 64 | Cache→CPU | Read data |

### 4.3 Tag Array Interface (per core)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `tag_req` | 1 | Ctrl→Tag | Tag lookup request |
| `tag_wr` | 1 | Ctrl→Tag | Tag write enable |
| `tag_addr` | 32 | Ctrl→Tag | Address for lookup/write |
| `tag_state_out` | 3 | Ctrl→Tag | MOESI state to write |
| `tag_hit` | 1 | Tag→Ctrl | Tag match (hit) |
| `tag_state_in` | 3 | Tag→Ctrl | Current MOESI state |
| `tag_match_way` | 4 | Tag→Ctrl | One-hot way match |

### 4.4 Data Array Interface (per core)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `data_req` | 1 | Ctrl→Data | Data access request |
| `data_wr` | 1 | Ctrl→Data | Write enable |
| `data_addr` | 32 | Ctrl→Data | Address for access |
| `data_wdata` | 64 | Ctrl→Data | Write data |
| `data_rdata` | 64 | Data→Ctrl | Read data |
| `data_ready` | 1 | Data→Ctrl | Access complete |

### 4.5 MOESI State Encoding

```systemverilog
localparam STATE_M = 3'b000;  // Modified (exclusive, dirty)
localparam STATE_O = 3'b001;  // Owned (shared, dirty)
localparam STATE_E = 3'b010;  // Exclusive (exclusive, clean)
localparam STATE_S = 3'b011;  // Shared (shared, clean)
localparam STATE_I = 3'b100;  // Invalid
```

### 4.6 LRU Interface (per core)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `lru_addr` | 32 | Ctrl→LRU | Address (index portion) |
| `lru_update` | 1 | Ctrl→LRU | Update LRU for accessed way |
| `lru_way` | 2 | LRU→Ctrl | Least recently used way (0-3) |

---

## 5. Example Transaction Flows

### 5.1 Read Miss Flow

**Scenario:** Core 0 read miss, line not in any cache

**Initial State:**
- Core 0: Line X in I state
- All other cores: Line X in I state

**Transaction Flow:**

```
Cycle 0: CPU Request
├─ CPU issues read request (addr=0x1000)
├─ Cache controller detects tag miss
└─ MOESI FSM: state = I

Cycle 1: Bus Request
├─ Cache controller issues BusRd on coherency bus
├─ Bus arbiter grants Core 0
└─ Bus broadcasts BusRd to all cores (snoop)

Cycle 2: Snoop Processing
├─ All cores perform tag lookup for address 0x1000
├─ All cores respond: snoop_resp_hit = 0 (miss)
└─ Bus determines: no cache has line

Cycle 3: Memory Access
├─ Bus routes request to memory controller
├─ Memory controller processes read request
└─ Cache controller waits for data

Cycle 4-5: Memory Response
├─ Memory returns data (mem_ready = 1)
├─ Bus routes data to Core 0 (core_data_valid = 1)
└─ Cache controller receives data

Cycle 6: Cache Update
├─ Cache controller writes tag: state = E
├─ Cache controller writes data array
├─ MOESI FSM transitions: I → E
└─ LRU updated for accessed way

Cycle 7: CPU Response
├─ Cache controller asserts cpu_ready
├─ CPU receives data (cpu_rdata)
└─ Transaction complete
```

**State Transitions:**
- Core 0: I → E
- Other cores: I (no change)

**Bus Transactions:**
- BusRd issued by Core 0
- No snoop responses (all miss)
- Memory read performed
- Data returned to Core 0

---

### 5.2 Write Miss Flow

**Scenario:** Core 0 write miss, Core 1 has line in O state

**Initial State:**
- Core 0: Line X in I state
- Core 1: Line X in O state (with data)
- Core 2/3: Line X in I state

**Transaction Flow:**

```
Cycle 0: CPU Request
├─ CPU issues write request (addr=0x2000, data=0xDEADBEEF)
├─ Cache controller detects tag miss
└─ MOESI FSM: state = I

Cycle 1: Bus Request
├─ Cache controller issues BusRdX on coherency bus
├─ Bus arbiter grants Core 0
└─ Bus broadcasts BusRdX to all cores (snoop)

Cycle 2: Snoop Processing
├─ Core 1 snoop handler detects BusRdX
├─ Core 1 performs tag lookup: HIT, state = O
├─ Core 2/3 tag lookup: MISS
└─ Core 1 prepares snoop response

Cycle 3: Snoop Response
├─ Core 1 reads data from data array
├─ Core 1 asserts snoop_resp_valid = 1
├─ Core 1 supplies data (snoop_resp_data)
├─ Core 1 MOESI FSM prepares: O → I transition
└─ Core 2/3 respond: snoop_resp_hit = 0

Cycle 4: Data Routing
├─ Bus collects snoop responses
├─ Bus routes Core 1 data to Core 0 (core_rdata)
├─ Bus asserts core_snoop_resp[0] = 1 (cache responded)
└─ Memory request cancelled (cache-to-cache transfer)

Cycle 5: Cache Update
├─ Core 0 writes tag: state = M
├─ Core 0 writes data array (with CPU write data)
├─ Core 0 MOESI FSM: I → M
├─ Core 1 MOESI FSM: O → I
└─ Core 1 tag updated: state = I

Cycle 6: CPU Response
├─ Cache controller asserts cpu_ready
└─ Transaction complete
```

**State Transitions:**
- Core 0: I → M
- Core 1: O → I
- Core 2/3: I (no change)

**Bus Transactions:**
- BusRdX issued by Core 0
- Core 1 snoop response: hit, supplies data
- Cache-to-cache transfer (no memory access)
- Core 1 invalidated

**Note:** If Core 2 or Core 3 had line in S state, they would also receive BusRdX snoop and transition S → I in Cycle 3-4.

---

### 5.3 Write Hit (S → M) Flow

**Scenario:** Core 0 write hit, line in S state (shared with other cores)

**Initial State:**
- Core 0: Line X in S state
- Core 1: Line X in S state
- Core 2: Line X in O state (owner)

**Transaction Flow:**

```
Cycle 0: CPU Request
├─ CPU issues write request (addr=0x3000)
├─ Cache controller detects tag hit, state = S
└─ MOESI FSM: state = S

Cycle 1: Bus Upgrade
├─ Cache controller issues BusUpgr on coherency bus
├─ Bus arbiter grants Core 0
└─ Bus broadcasts BusUpgr to all cores (snoop)

Cycle 2: Snoop Invalidation
├─ Core 1 snoop handler: detects BusUpgr, state = S
├─ Core 1 MOESI FSM: S → I
├─ Core 2 snoop handler: detects BusUpgr, state = O
├─ Core 2 MOESI FSM: O → I
└─ All shared copies invalidated

Cycle 3: State Update
├─ Core 0 MOESI FSM: S → M
├─ Core 0 tag updated: state = M
└─ Cache controller ready for write

Cycle 4: Write Completion
├─ Cache controller writes CPU data to cache
├─ Cache controller asserts cpu_ready
└─ Transaction complete
```

**State Transitions:**
- Core 0: S → M
- Core 1: S → I
- Core 2: O → I

**Bus Transactions:**
- BusUpgr issued by Core 0
- All shared copies invalidated
- No data transfer needed (Core 0 already has data)

---

## 6. Design Parameters Summary

| Parameter | Value | Notes |
|-----------|-------|-------|
| Number of Cores | 4 | Fixed architecture |
| Cache Size (per core) | 32 KB | L1 data cache |
| Associativity | 4-way | Set-associative |
| Line Size | 64 bytes | Cache line |
| Address Width | 32 bits | 4GB address space |
| Data Width | 64 bits | Cache line width |
| MOESI States | 5 | M, O, E, S, I |
| Bus Types | 3 | BusRd, BusRdX, BusUpgr |

---

## 7. Implementation Notes

### 7.1 Timing Requirements
- **Tag lookup latency:** 1 cycle
- **Data array access:** 1 cycle
- **Snoop response:** 2-3 cycles (tag lookup + data read)
- **Memory access:** 10-20 cycles (configurable)
- **Bus arbitration:** 1 cycle

### 7.2 Critical Paths
- Tag lookup → Hit/miss detection → Bus request
- Snoop detection → Tag lookup → Snoop response
- Bus grant → Data routing → Cache update

### 7.3 Write-Back Conditions
- **M → I:** Always write-back (dirty)
- **O → I:** Always write-back (dirty)
- **E → I:** No write-back (clean)
- **S → I:** No write-back (clean)

### 7.4 Bus Arbitration
- **Algorithm:** Round-robin or priority-based
- **Fairness:** Prevent starvation
- **Latency:** 1 cycle arbitration delay

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024 | Design Team | Initial architecture specification |

---

**End of Document**
