// ============================================================================
// Synchronous FIFO
// 
// Reads and writes share one clock. Read data is registered on an accepted read.
// Extended pointers use an extra MSB to distinguish full from empty.
// 
// License: MIT
// ============================================================================

module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input                   clk,
    input                   rst_n,
    input                   wr_en,
    input  [WIDTH-1:0]      wr_data,
    output                  full,
    input                   rd_en,
    output [WIDTH-1:0]      rd_data,
    output                  empty
);

    localparam ADDR_W = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_W:0]  wr_ptr;         // One extra bit distinguishes full from empty
    reg [ADDR_W:0]  rd_ptr;
    reg [WIDTH-1:0] rd_data_reg;

    // ---- full and empty ----
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
                   (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);

    // ---- Write ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 0;
        else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // ---- Read (registered output) ----
    assign rd_data = rd_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr      <= 0;
            rd_data_reg <= 0;
        end else begin
            if (rd_en && !empty) begin
                rd_data_reg <= mem[rd_ptr[ADDR_W-1:0]];
                rd_ptr      <= rd_ptr + 1'b1;
            end
        end
    end

endmodule
