// cache_data_array.sv
// 4-way set-associative L1 D-cache data array with byte-granular writes.
// Single read + single write per cycle, synthesis-friendly.

module cache_data_array #(
    parameter int SETS       = 128,
    parameter int WAYS       = 4,
    parameter int LINE_BYTES = 64,
    parameter int DATA_WIDTH = LINE_BYTES * 8
) (
    input  logic                         clk,
    input  logic                         rst_n,

    // Read port
    input  logic [$clog2(SETS)-1:0]       read_set,
    input  logic [$clog2(WAYS)-1:0]       read_way,
    output logic [DATA_WIDTH-1:0]         read_data,

    // Write port (byte-granular)
    input  logic [$clog2(SETS)-1:0]       write_set,
    input  logic [$clog2(WAYS)-1:0]       write_way,
    input  logic [DATA_WIDTH-1:0]         write_data,
    input  logic [LINE_BYTES-1:0]         write_mask
);

    // Data array: [set][way] -> cache line data
    logic [DATA_WIDTH-1:0] mem [0:SETS-1][0:WAYS-1];

    // Helper: detect if any byte is enabled for write
    wire write_en = |write_mask;

    // Merge write_data with existing line using byte mask
    function automatic logic [DATA_WIDTH-1:0] apply_write_mask(
        input logic [DATA_WIDTH-1:0] curr_data,
        input logic [DATA_WIDTH-1:0] new_data,
        input logic [LINE_BYTES-1:0] mask
    );
        logic [DATA_WIDTH-1:0] merged;
        int i;
        begin
            merged = curr_data;
            for (i = 0; i < LINE_BYTES; i = i + 1) begin
                if (mask[i]) begin
                    merged[i*8 +: 8] = new_data[i*8 +: 8];
                end
            end
            return merged;
        end
    endfunction

    // Sequential read/write
    // - Supports single read + single write per cycle.
    // - For same-cycle read-after-write to same set/way, returns merged data.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data <= '0;
        end else begin
            if (write_en) begin
                mem[write_set][write_way] <= apply_write_mask(
                    mem[write_set][write_way], write_data, write_mask
                );
            end

            if (write_en && (read_set == write_set) && (read_way == write_way)) begin
                read_data <= apply_write_mask(
                    mem[write_set][write_way], write_data, write_mask
                );
            end else begin
                read_data <= mem[read_set][read_way];
            end
        end
    end

endmodule
