// tb_cache_data_array.sv
// Simple smoke test: write then read a cache line.

module tb_cache_data_array;
    localparam int SETS       = 2;
    localparam int WAYS       = 2;
    localparam int LINE_BYTES = 8;
    localparam int DATA_WIDTH = LINE_BYTES * 8;

    logic clk;
    logic rst_n;
    logic [$clog2(SETS)-1:0] read_set;
    logic [$clog2(WAYS)-1:0] read_way;
    logic [DATA_WIDTH-1:0]   read_data;
    logic [$clog2(SETS)-1:0] write_set;
    logic [$clog2(WAYS)-1:0] write_way;
    logic [DATA_WIDTH-1:0]   write_data;
    logic [LINE_BYTES-1:0]   write_mask;

    // Clock generation
    always #5 clk = ~clk;

    cache_data_array #(
        .SETS(SETS),
        .WAYS(WAYS),
        .LINE_BYTES(LINE_BYTES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .read_set(read_set),
        .read_way(read_way),
        .read_data(read_data),
        .write_set(write_set),
        .write_way(write_way),
        .write_data(write_data),
        .write_mask(write_mask)
    );

    initial begin
        clk = 0;
        rst_n = 0;
        read_set = '0;
        read_way = '0;
        write_set = '0;
        write_way = '0;
        write_data = '0;
        write_mask = '0;

        // Reset
        #12;
        rst_n = 1;

        // Write full line
        write_set  = 1;
        write_way  = 1;
        write_data = 64'hDEADBEEF_CAFE1234;
        write_mask = {LINE_BYTES{1'b1}};

        // Read same line (next cycle)
        read_set = 1;
        read_way = 1;

        #10;
        if (read_data !== write_data) begin
            $display("FAIL: read_data=0x%0h expected=0x%0h", read_data, write_data);
            $fatal(1);
        end else begin
            $display("PASS: read_data=0x%0h", read_data);
        end

        $finish;
    end
endmodule
