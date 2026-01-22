// moesi_coverage.sv
// Functional coverage for MOESI protocol activity.
// Provides covergroups for state, request type, snoop type, and concurrency.

module moesi_coverage #(
    parameter int LINE_ID_WIDTH = 16
) (
    input logic        clk,
    input logic        rst_n,

    // Current MOESI state for the sampled cache line
    input logic [2:0]  state,
    input logic [LINE_ID_WIDTH-1:0] line_id,

    // Request type (2'b01=READ, 2'b10=WRITE, 2'b11=UPGRADE)
    input logic [1:0]  req_type,
    input logic        req_valid,

    // Snoop type (2'b01=READ, 2'b10=WRITE, 2'b11=INVALIDATE)
    input logic [1:0]  snoop_type,
    input logic        snoop_valid,

    // Concurrent requests in the same cycle (1–4 cores)
    input logic [2:0]  concurrent_reqs
);

    // MOESI encoding (must match RTL)
    localparam logic [2:0] MOESI_M = 3'b000;
    localparam logic [2:0] MOESI_O = 3'b001;
    localparam logic [2:0] MOESI_E = 3'b010;
    localparam logic [2:0] MOESI_S = 3'b011;
    localparam logic [2:0] MOESI_I = 3'b100;

    // -------------------------------------------------------------------------
    // Covergroups
    // -------------------------------------------------------------------------

    // MOESI state values (per line)
    covergroup cg_state @(posedge clk);
        coverpoint state {
            bins M = {MOESI_M};
            bins O = {MOESI_O};
            bins E = {MOESI_E};
            bins S = {MOESI_S};
            bins I = {MOESI_I};
        }
        // Optional: track line IDs that are being sampled
        coverpoint line_id;
    endgroup

    // Request type
    covergroup cg_req @(posedge clk);
        coverpoint req_type iff (req_valid) {
            bins READ    = {2'b01};
            bins WRITE   = {2'b10};
            bins UPGRADE = {2'b11};
        }
    endgroup

    // Cross of (state x request type)
    covergroup cg_state_x_req @(posedge clk);
        state_cp: coverpoint state {
            bins M = {MOESI_M};
            bins O = {MOESI_O};
            bins E = {MOESI_E};
            bins S = {MOESI_S};
            bins I = {MOESI_I};
        }
        req_cp: coverpoint req_type iff (req_valid) {
            bins READ    = {2'b01};
            bins WRITE   = {2'b10};
            bins UPGRADE = {2'b11};
        }
        state_x_req: cross state_cp, req_cp;
    endgroup

    // Snoop type
    covergroup cg_snoop @(posedge clk);
        coverpoint snoop_type iff (snoop_valid) {
            bins READ       = {2'b01};
            bins WRITE      = {2'b10};
            bins INVALIDATE = {2'b11};
        }
    endgroup

    // Cross of (snoop type x state)
    covergroup cg_snoop_x_state @(posedge clk);
        snoop_cp: coverpoint snoop_type iff (snoop_valid) {
            bins READ       = {2'b01};
            bins WRITE      = {2'b10};
            bins INVALIDATE = {2'b11};
        }
        state_cp: coverpoint state {
            bins M = {MOESI_M};
            bins O = {MOESI_O};
            bins E = {MOESI_E};
            bins S = {MOESI_S};
            bins I = {MOESI_I};
        }
        snoop_x_state: cross snoop_cp, state_cp;
    endgroup

    // Concurrent requests count (1–4)
    covergroup cg_concurrency @(posedge clk);
        coverpoint concurrent_reqs {
            bins one   = {1};
            bins two   = {2};
            bins three = {3};
            bins four  = {4};
        }
    endgroup

    // Instantiate covergroups
    cg_state          u_cg_state = new();
    cg_req            u_cg_req = new();
    cg_state_x_req    u_cg_state_x_req = new();
    cg_snoop          u_cg_snoop = new();
    cg_snoop_x_state  u_cg_snoop_x_state = new();
    cg_concurrency    u_cg_concurrency = new();

    // -------------------------------------------------------------------------
    // Hook: sample call for monitors/scoreboards
    // -------------------------------------------------------------------------
    task automatic sample_now();
        // Sampling is clocked; this task can be used for manual triggers if needed.
        // No body required since covergroups sample on posedge clk.
    endtask

endmodule
