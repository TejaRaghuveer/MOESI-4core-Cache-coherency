// moesi_scoreboard.sv
// UVM scoreboard for MOESI protocol invariants and data correctness.

`ifndef MOESI_SCOREBOARD_SV
`define MOESI_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import moesi_pkg::*;

class moesi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(moesi_scoreboard)

    // Analysis export
    uvm_analysis_imp #(moesi_request, moesi_scoreboard) sb_imp;

    // MOESI encoding
    localparam bit [2:0] MOESI_M = 3'b000;
    localparam bit [2:0] MOESI_O = 3'b001;
    localparam bit [2:0] MOESI_E = 3'b010;
    localparam bit [2:0] MOESI_S = 3'b011;
    localparam bit [2:0] MOESI_I = 3'b100;

    // Expected state per (addr, core_id)
    // state_map[addr][core] = MOESI state
    typedef bit [63:0] addr_t;
    typedef int unsigned core_t;
    bit [2:0] state_map [addr_t][core_t];

    // Last written data per address
    bit [511:0] last_written [addr_t];

    function new(string name = "moesi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        sb_imp = new("sb_imp", this);
    endfunction

    // Analysis write method
    function void write(moesi_request tr);
        int unsigned c;
        int unsigned m_count;
        bit has_m;
        bit has_other_valid;

        // Initialize missing entries to I for all cores (0..3)
        for (c = 0; c < 4; c++) begin
            if (!state_map.exists(tr.addr) || !state_map[tr.addr].exists(c)) begin
                state_map[tr.addr][c] = MOESI_I;
            end
        end

        // Update expected state based on transaction type
        case (tr.req_type)
            2'b01: begin // READ
                // Determine if any other core has a valid line
                has_other_valid = 1'b0;
                for (c = 0; c < 4; c++) begin
                    if (c != tr.core_id && state_map[tr.addr][c] != MOESI_I) begin
                        has_other_valid = 1'b1;
                    end
                end
                // If shared exists -> S, otherwise E
                state_map[tr.addr][tr.core_id] = has_other_valid ? MOESI_S : MOESI_E;

                // Data check if known
                if (last_written.exists(tr.addr)) begin
                    if (tr.rdata !== last_written[tr.addr]) begin
                        `uvm_error("MOESI_SB",
                            $sformatf("READ data mismatch addr=0x%0h core=%0d rdata=0x%0h expected=0x%0h",
                                      tr.addr, tr.core_id, tr.rdata, last_written[tr.addr]))
                    end
                end
            end

            2'b10: begin // WRITE
                // Writer moves to M, others to I
                for (c = 0; c < 4; c++) begin
                    state_map[tr.addr][c] = (c == tr.core_id) ? MOESI_M : MOESI_I;
                end
                // Update last written data
                last_written[tr.addr] = tr.wdata;
            end

            2'b11: begin // UPGRADE
                // Treat as write intent: requester to M, others to I
                for (c = 0; c < 4; c++) begin
                    state_map[tr.addr][c] = (c == tr.core_id) ? MOESI_M : MOESI_I;
                end
            end

            default: begin
                `uvm_warning("MOESI_SB", $sformatf("Unknown req_type: %0b", tr.req_type))
            end
        endcase

        // Invariant: At most one M per address
        m_count = 0;
        for (c = 0; c < 4; c++) begin
            if (state_map[tr.addr][c] == MOESI_M) begin
                m_count++;
            end
        end
        if (m_count > 1) begin
            `uvm_error("MOESI_SB",
                $sformatf("Multiple M states for addr=0x%0h count=%0d", tr.addr, m_count))
        end

        // Invariant: If any cache is M, all others must be I
        has_m = (m_count == 1);
        if (has_m) begin
            for (c = 0; c < 4; c++) begin
                if (state_map[tr.addr][c] != MOESI_M && state_map[tr.addr][c] != MOESI_I) begin
                    `uvm_error("MOESI_SB",
                        $sformatf("Invalid state when M present addr=0x%0h core=%0d state=%0b",
                                  tr.addr, c, state_map[tr.addr][c]))
                end
            end
        end
    endfunction

endclass

`endif
