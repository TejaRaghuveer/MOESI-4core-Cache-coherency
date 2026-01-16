// lru_4way.sv
// 4-way tree-based LRU per set.
// Tracks LRU state for each set and returns a victim way.

module lru_4way #(
    parameter int SETS = 128
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [$clog2(SETS)-1:0]     access_set,
    input  logic [1:0]                 access_way,
    input  logic                       access_valid,
    output logic [1:0]                 victim_way
);

    // Tree-based LRU encoding per set:
    // lru_bits[set][2:0] = {b0, b1, b2}
    // b0: which subtree is LRU (0 = left [way0/1], 1 = right [way2/3])
    // b1: which way is LRU in left subtree (0 = way0, 1 = way1)
    // b2: which way is LRU in right subtree (0 = way2, 1 = way3)
    logic [2:0] lru_bits [0:SETS-1];

    integer i;

    // Reset: initialize all LRU bits to zero (way0 will be first victim).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < SETS; i = i + 1) begin
                lru_bits[i] <= 3'b000;
            end
        end else begin
            if (access_valid) begin
                // Assertion: way index must be 0-3 when access is valid.
                assert (access_way inside {[2'd0:2'd3]})
                    else $fatal(1, "lru_4way: access_way out of range: %0d", access_way);

                case (access_way)
                    2'd0: begin
                        // Accessed left subtree, way0 (MRU) => right subtree becomes LRU
                        lru_bits[access_set][2] <= lru_bits[access_set][2]; // unchanged
                        lru_bits[access_set][1] <= 1'b1; // way1 becomes LRU
                        lru_bits[access_set][0] <= 1'b1; // right subtree becomes LRU
                    end
                    2'd1: begin
                        lru_bits[access_set][2] <= lru_bits[access_set][2]; // unchanged
                        lru_bits[access_set][1] <= 1'b0; // way0 becomes LRU
                        lru_bits[access_set][0] <= 1'b1; // right subtree becomes LRU
                    end
                    2'd2: begin
                        lru_bits[access_set][1] <= lru_bits[access_set][1]; // unchanged
                        lru_bits[access_set][2] <= 1'b1; // way3 becomes LRU
                        lru_bits[access_set][0] <= 1'b0; // left subtree becomes LRU
                    end
                    2'd3: begin
                        lru_bits[access_set][1] <= lru_bits[access_set][1]; // unchanged
                        lru_bits[access_set][2] <= 1'b0; // way2 becomes LRU
                        lru_bits[access_set][0] <= 1'b0; // left subtree becomes LRU
                    end
                    default: begin
                        // Should never happen due to assertion, keep state unchanged.
                        lru_bits[access_set] <= lru_bits[access_set];
                    end
                endcase
            end
        end
    end

    // Victim selection for the requested set.
    always_comb begin
        logic b0;
        logic b1;
        logic b2;
        b0 = lru_bits[access_set][0];
        b1 = lru_bits[access_set][1];
        b2 = lru_bits[access_set][2];

        if (b0 == 1'b0) begin
            // Left subtree is LRU
            victim_way = (b1 == 1'b0) ? 2'd0 : 2'd1;
        end else begin
            // Right subtree is LRU
            victim_way = (b2 == 1'b0) ? 2'd2 : 2'd3;
        end
    end

endmodule
