// perf_counters.sv
// Performance counters with saturation (no wraparound).
// Tracks cache and coherency events with one-cycle pulse inputs.

module perf_counters (
    input  logic        clk,
    input  logic        rst_n,

    // Event pulses (one cycle each)
    input  logic        total_reads_pulse,
    input  logic        read_hits_pulse,
    input  logic        read_misses_pulse,
    input  logic        total_writes_pulse,
    input  logic        write_hits_pulse,
    input  logic        write_misses_pulse,
    input  logic        coherency_invalidates_pulse,
    input  logic        data_supplied_pulse,
    input  logic        data_from_mem_pulse,

    // Counter read mux
    input  logic [3:0]  sel,
    output logic [63:0] counter_val
);

    // 64-bit counters
    logic [63:0] total_reads;
    logic [63:0] read_hits;
    logic [63:0] read_misses;
    logic [63:0] total_writes;
    logic [63:0] write_hits;
    logic [63:0] write_misses;
    logic [63:0] coherency_invalidates;
    logic [63:0] data_supplied;
    logic [63:0] data_from_mem;

    // Saturating increment helper
    function automatic logic [63:0] sat_inc(
        input logic [63:0] curr,
        input logic        inc
    );
        if (!inc) begin
            return curr;
        end
        if (curr == 64'hFFFF_FFFF_FFFF_FFFF) begin
            return curr;
        end
        return curr + 64'd1;
    endfunction

    // Counter updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_reads           <= 64'd0;
            read_hits             <= 64'd0;
            read_misses           <= 64'd0;
            total_writes          <= 64'd0;
            write_hits            <= 64'd0;
            write_misses          <= 64'd0;
            coherency_invalidates <= 64'd0;
            data_supplied         <= 64'd0;
            data_from_mem         <= 64'd0;
        end else begin
            total_reads           <= sat_inc(total_reads, total_reads_pulse);
            read_hits             <= sat_inc(read_hits, read_hits_pulse);
            read_misses           <= sat_inc(read_misses, read_misses_pulse);
            total_writes          <= sat_inc(total_writes, total_writes_pulse);
            write_hits            <= sat_inc(write_hits, write_hits_pulse);
            write_misses          <= sat_inc(write_misses, write_misses_pulse);
            coherency_invalidates <= sat_inc(coherency_invalidates, coherency_invalidates_pulse);
            data_supplied         <= sat_inc(data_supplied, data_supplied_pulse);
            data_from_mem         <= sat_inc(data_from_mem, data_from_mem_pulse);
        end
    end

    // Read mux
    always_comb begin
        case (sel)
            4'd0: counter_val = total_reads;
            4'd1: counter_val = read_hits;
            4'd2: counter_val = read_misses;
            4'd3: counter_val = total_writes;
            4'd4: counter_val = write_hits;
            4'd5: counter_val = write_misses;
            4'd6: counter_val = coherency_invalidates;
            4'd7: counter_val = data_supplied;
            4'd8: counter_val = data_from_mem;
            default: counter_val = 64'd0;
        endcase
    end

endmodule
