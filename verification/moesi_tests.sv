// moesi_tests.sv
// UVM tests for MOESI cache coherency system.

`ifndef MOESI_TESTS_SV
`define MOESI_TESTS_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import moesi_pkg::*;
`include "moesi_targeted_seqs.sv"

// Placeholder environment handle (to be replaced with actual env class)
class moesi_env extends uvm_env;
    `uvm_component_utils(moesi_env)

    // Simple per-core sequencers (placeholder until full env is built)
    uvm_sequencer #(moesi_request) core_seqr[4];

    function new(string name = "moesi_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // TODO: build agents, scoreboard, coverage, etc.
        core_seqr[0] = uvm_sequencer#(moesi_request)::type_id::create("core_seqr0", this);
        core_seqr[1] = uvm_sequencer#(moesi_request)::type_id::create("core_seqr1", this);
        core_seqr[2] = uvm_sequencer#(moesi_request)::type_id::create("core_seqr2", this);
        core_seqr[3] = uvm_sequencer#(moesi_request)::type_id::create("core_seqr3", this);
    endfunction
endclass

// Base test class
class moesi_base_test extends uvm_test;
    `uvm_component_utils(moesi_base_test)

    moesi_env env;

    function new(string name = "moesi_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = moesi_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        // Derived tests will run sequences here
        #100;
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Test completed. Summary: coverage/counters TBD.", UVM_LOW)
    endfunction
endclass

// -------------------------------------------------------------------------
// test_read_hits: promotes read hits using read_hit_seq
// -------------------------------------------------------------------------
class test_read_hits extends moesi_base_test;
    `uvm_component_utils(test_read_hits)

    function new(string name = "test_read_hits", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        read_hit_seq seqs[4];
        int i;
        phase.raise_objection(this);

        // Run read-hit sequences on all cores in parallel
        for (i = 0; i < 4; i++) begin
            seqs[i] = read_hit_seq::type_id::create($sformatf("read_hit_seq_%0d", i));
        end
        fork
            seqs[0].start(env.core_seqr[0]);
            seqs[1].start(env.core_seqr[1]);
            seqs[2].start(env.core_seqr[2]);
            seqs[3].start(env.core_seqr[3]);
        join

        #500;
        phase.drop_objection(this);
    endtask
endclass

// -------------------------------------------------------------------------
// test_read_misses: promotes read misses using read_miss_seq
// -------------------------------------------------------------------------
class test_read_misses extends moesi_base_test;
    `uvm_component_utils(test_read_misses)

    function new(string name = "test_read_misses", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        read_miss_seq seqs[3];
        exclusive_read_seq excl_seq;
        int i;
        phase.raise_objection(this);

        // One core performs exclusive reads (I->E), others stress misses
        excl_seq = exclusive_read_seq::type_id::create("exclusive_read_seq");
        for (i = 0; i < 3; i++) begin
            seqs[i] = read_miss_seq::type_id::create($sformatf("read_miss_seq_%0d", i+1));
        end
        fork
            excl_seq.start(env.core_seqr[0]);
            seqs[0].start(env.core_seqr[1]);
            seqs[1].start(env.core_seqr[2]);
            seqs[2].start(env.core_seqr[3]);
        join

        #500;
        phase.drop_objection(this);
    endtask
endclass

// -------------------------------------------------------------------------
// test_write_coherency: forces S->M invalidation using write_coherency_seq
// -------------------------------------------------------------------------
class test_write_coherency extends moesi_base_test;
    `uvm_component_utils(test_write_coherency)

    function new(string name = "test_write_coherency", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        shared_read_write_seq seq;
        phase.raise_objection(this);

        // Single directed sequence that forces E->S then S->M upgrade
        seq = shared_read_write_seq::type_id::create("shared_rw_seq");
        seq.start(env.core_seqr[0]);

        #500;
        phase.drop_objection(this);
    endtask
endclass

// -------------------------------------------------------------------------
// test_cache_line_bouncing: alternates reads/writes on shared line
// -------------------------------------------------------------------------
class test_cache_line_bouncing extends moesi_base_test;
    `uvm_component_utils(test_cache_line_bouncing)

    function new(string name = "test_cache_line_bouncing", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        owner_transitions_seq seq;
        phase.raise_objection(this);

        // Directed owner transitions to force M->O->M and ownership changes
        seq = owner_transitions_seq::type_id::create("owner_transitions_seq");
        seq.start(env.core_seqr[0]);

        #500;
        phase.drop_objection(this);
    endtask
endclass

// -------------------------------------------------------------------------
// test_random_coherency: randomized traffic across all cores
// -------------------------------------------------------------------------
class test_random_coherency extends moesi_base_test;
    `uvm_component_utils(test_random_coherency)

    function new(string name = "test_random_coherency", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        moesi_base_seq seqs[4];
        int i;
        phase.raise_objection(this);

        for (i = 0; i < 4; i++) begin
            seqs[i] = moesi_base_seq::type_id::create($sformatf("rand_seq_%0d", i));
            seqs[i].num_trans = 200;
        end
        fork
            seqs[0].start(env.core_seqr[0]);
            seqs[1].start(env.core_seqr[1]);
            seqs[2].start(env.core_seqr[2]);
            seqs[3].start(env.core_seqr[3]);
        join

        #500;
        phase.drop_objection(this);
    endtask
endclass

`endif
