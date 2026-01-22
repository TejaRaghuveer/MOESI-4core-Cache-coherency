// moesi_targeted_seqs.sv
// Targeted UVM sequences to hit specific missing MOESI coverage bins.

`ifndef MOESI_TARGETED_SEQS_SV
`define MOESI_TARGETED_SEQS_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import moesi_pkg::*;

// -------------------------------------------------------------------------
// owner_transitions_seq
// Hits: M->O, O->M, READ_on_O, WRITE_on_O
// Sequence:
//   c0 WRITE A (miss -> M)
//   c1 READ  A (snoop -> c0 M->O)
//   c0 READ  A (READ_on_O)
//   c0 WRITE A (O->M, WRITE_on_O)
// -------------------------------------------------------------------------
class owner_transitions_seq extends uvm_sequence #(moesi_request);
    `uvm_object_utils(owner_transitions_seq)

    bit [63:0] A;

    function new(string name = "owner_transitions_seq");
        super.new(name);
        A = 64'h0000_1000;
    endfunction

    virtual task body();
        moesi_request req;

        // c0 WRITE A
        req = moesi_request::type_id::create("c0_wr_A");
        req.req_type = 2'b10; // WRITE
        if (!req.randomize() with { core_id == 0; addr == A; req_type == 2'b10; }) begin
            `uvm_warning("OWNER_SEQ", "Randomization failed for c0 WRITE A")
        end
        start_item(req); finish_item(req);

        // c1 READ A
        req = moesi_request::type_id::create("c1_rd_A");
        req.req_type = 2'b01; // READ
        if (!req.randomize() with { core_id == 1; addr == A; req_type == 2'b01; }) begin
            `uvm_warning("OWNER_SEQ", "Randomization failed for c1 READ A")
        end
        start_item(req); finish_item(req);

        // c0 READ A
        req = moesi_request::type_id::create("c0_rd_A");
        req.req_type = 2'b01; // READ
        if (!req.randomize() with { core_id == 0; addr == A; req_type == 2'b01; }) begin
            `uvm_warning("OWNER_SEQ", "Randomization failed for c0 READ A")
        end
        start_item(req); finish_item(req);

        // c0 WRITE A
        req = moesi_request::type_id::create("c0_wr_A_2");
        req.req_type = 2'b10; // WRITE
        if (!req.randomize() with { core_id == 0; addr == A; req_type == 2'b10; }) begin
            `uvm_warning("OWNER_SEQ", "Randomization failed for c0 WRITE A (2)")
        end
        start_item(req); finish_item(req);
    endtask
endclass

// -------------------------------------------------------------------------
// shared_read_write_seq
// Hits: E->S_on_snoop_read, S->M_on_local_write, UPGRADE_on_S
// Sequence:
//   c0 READ  A (miss -> E)
//   c1 READ  A (snoop -> c0 E->S, c1 S)
//   c1 WRITE A (S->M, BusUpgr)
// -------------------------------------------------------------------------
class shared_read_write_seq extends uvm_sequence #(moesi_request);
    `uvm_object_utils(shared_read_write_seq)

    bit [63:0] A;

    function new(string name = "shared_read_write_seq");
        super.new(name);
        A = 64'h0000_2000;
    endfunction

    virtual task body();
        moesi_request req;

        // c0 READ A
        req = moesi_request::type_id::create("c0_rd_A");
        req.req_type = 2'b01; // READ
        if (!req.randomize() with { core_id == 0; addr == A; req_type == 2'b01; }) begin
            `uvm_warning("SHARED_SEQ", "Randomization failed for c0 READ A")
        end
        start_item(req); finish_item(req);

        // c1 READ A
        req = moesi_request::type_id::create("c1_rd_A");
        req.req_type = 2'b01; // READ
        if (!req.randomize() with { core_id == 1; addr == A; req_type == 2'b01; }) begin
            `uvm_warning("SHARED_SEQ", "Randomization failed for c1 READ A")
        end
        start_item(req); finish_item(req);

        // c1 WRITE A (upgrade)
        req = moesi_request::type_id::create("c1_wr_A");
        req.req_type = 2'b10; // WRITE
        if (!req.randomize() with { core_id == 1; addr == A; req_type == 2'b10; }) begin
            `uvm_warning("SHARED_SEQ", "Randomization failed for c1 WRITE A")
        end
        start_item(req); finish_item(req);
    endtask
endclass

// -------------------------------------------------------------------------
// exclusive_read_seq
// Hits: I->E on exclusive read (no sharers)
// Sequence:
//   c0 READ A (cold line -> E)
// -------------------------------------------------------------------------
class exclusive_read_seq extends uvm_sequence #(moesi_request);
    `uvm_object_utils(exclusive_read_seq)

    bit [63:0] A;

    function new(string name = "exclusive_read_seq");
        super.new(name);
        A = 64'h0000_3000;
    endfunction

    virtual task body();
        moesi_request req;
        req = moesi_request::type_id::create("c0_rd_A");
        req.req_type = 2'b01; // READ
        if (!req.randomize() with { core_id == 0; addr == A; req_type == 2'b01; }) begin
            `uvm_warning("EXCL_SEQ", "Randomization failed for c0 READ A")
        end
        start_item(req); finish_item(req);
    endtask
endclass

`endif
