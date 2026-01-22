// moesi_driver.sv
// UVM driver for a single core interface.

`ifndef MOESI_DRIVER_SV
`define MOESI_DRIVER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import moesi_pkg::*;

// Simple core interface definition for the driver
interface moesi_core_if (
    input  logic clk
);
    logic        core_req_valid;
    logic [1:0]  core_req_type;
    logic [63:0] core_addr;
    logic [511:0] core_wdata;
    logic        core_resp_valid;
    logic [511:0] core_rdata;
endinterface

class moesi_driver extends uvm_driver #(moesi_request);
    `uvm_component_utils(moesi_driver)

    virtual moesi_core_if vif;

    function new(string name = "moesi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual moesi_core_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NO_VIF", "moesi_driver: virtual interface not set")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        moesi_request req;
        int unsigned  cycles;
        // Drive defaults
        vif.core_req_valid <= 1'b0;
        vif.core_req_type  <= 2'b00;
        vif.core_addr      <= '0;
        vif.core_wdata     <= '0;

        forever begin
            seq_item_port.get_next_item(req);

            // Drive request on next rising edge
            @(posedge vif.clk);
            vif.core_req_valid <= 1'b1;
            vif.core_req_type  <= req.req_type;
            vif.core_addr      <= req.addr;
            vif.core_wdata     <= req.wdata;

            // Wait for response
            cycles = 0;
            while (vif.core_resp_valid !== 1'b1) begin
                @(posedge vif.clk);
                cycles++;
            end

            // Capture response and latency
            req.rdata   = vif.core_rdata;
            req.latency = cycles;

            // Deassert request
            vif.core_req_valid <= 1'b0;

            seq_item_port.item_done();
        end
    endtask
endclass

`endif
