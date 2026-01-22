// moesi_monitor.sv
// UVM monitor for one core interface + shared bus signals.

`ifndef MOESI_MONITOR_SV
`define MOESI_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import moesi_pkg::*;

// Simple bus interface definition (core interface is expected from moesi_driver.sv)
interface moesi_bus_if (
    input logic clk
);
    logic        bus_valid;
    logic [63:0] bus_addr;
    logic [1:0]  bus_type;
    logic [1:0]  granted_core_id;
endinterface

class moesi_monitor extends uvm_monitor;
    `uvm_component_utils(moesi_monitor)

    virtual moesi_core_if vif;
    virtual moesi_bus_if  bus_vif;

    uvm_analysis_port #(moesi_request) ap;

    // Core identifier for this monitor instance
    int unsigned core_id;

    // Simple pending tracker
    bit          pending;
    bit [63:0]   pending_addr;
    bit [1:0]    pending_type;
    bit [511:0]  pending_wdata;
    int unsigned start_cycle;
    int unsigned cycle_count;

    function new(string name = "moesi_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual moesi_core_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "moesi_monitor: core interface not set")
        end
        if (!uvm_config_db#(virtual moesi_bus_if)::get(this, "", "bus_vif", bus_vif)) begin
            `uvm_warning("NO_BUS_VIF", "moesi_monitor: bus interface not set, bus info ignored")
        end
        if (!uvm_config_db#(int unsigned)::get(this, "", "core_id", core_id)) begin
            core_id = 0;
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        moesi_request tr;
        pending = 1'b0;
        cycle_count = 0;

        forever begin
            @(posedge vif.clk);
            cycle_count++;

            // Capture request when valid and no pending
            if (vif.core_req_valid && !pending) begin
                pending       = 1'b1;
                pending_addr  = vif.core_addr;
                pending_type  = vif.core_req_type;
                pending_wdata = vif.core_wdata;
                start_cycle   = cycle_count;
            end

            // Complete on response
            if (pending && vif.core_resp_valid) begin
                tr = moesi_request::type_id::create("tr", this);
                tr.core_id = core_id;
                tr.addr    = pending_addr;
                tr.req_type = pending_type;
                tr.wdata   = pending_wdata;
                tr.rdata   = vif.core_rdata;
                tr.latency = cycle_count - start_cycle;

                ap.write(tr);
                pending = 1'b0;
            end
        end
    endtask
endclass

`endif
