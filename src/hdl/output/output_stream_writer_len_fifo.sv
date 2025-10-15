`timescale 1ns / 1ps

`include "libstf_macros.svh"

// This module implements the FIFO queue to be used by the output stream writer.
// The queue holds the length of bytes that still need to be written to the output.
module output_stream_writer_len_fifo #(
    parameter integer TRANSFER_ADDRESS_LEN_BITS = 1,
    parameter integer DEPTH = 16,
    parameter integer SHIFT_STAGES = 0
)(
    input logic clk,
    input logic rst_n,

    input logic [TRANSFER_ADDRESS_LEN_BITS - 1:0]  i_data,
    input logic  i_valid,
    output logic  i_ready,

    output logic [TRANSFER_ADDRESS_LEN_BITS - 1:0] o_data,
    output logic o_valid,
    input logic o_ready
);

`RESET_RESYNC // Reset pipelining

// ---- Implementation -------------------------------------------------------

// FIFO instance

// Note: We put the output into a AXI stream so we can use the axi_shift_register
//       in the next stage.

AXI4SR #(.AXI4S_DATA_BITS(TRANSFER_ADDRESS_LEN_BITS)) fifo_out (.aclk(clk));
FIFO #(
    .DEPTH(DEPTH),
    .WIDTH(TRANSFER_ADDRESS_LEN_BITS)
) inst_len_fifo (
    .i_clk(clk),
    .i_rst_n(reset_synced),

    .i_data(i_data),
    .i_valid(i_valid),
    .i_ready(i_ready),

    .o_data({fifo_out.tdata}),
    .o_valid(fifo_out.tvalid),
    .o_ready(fifo_out.tready),
    
    .o_filling_level()
);

// De coupling. Otherwise, the synthesis merges everything together and
// the path becomes too long!
AXI4SR fifo_out_de_coupled (.aclk(clk));
axi_ready_de_coupler de_coupler (
  .clk(clk),
  .rst_n(reset_synced),
  .input_stream(fifo_out),
  .output_stream(fifo_out_de_coupled)
);

// SHIFT Stage
AXI4SR #(.AXI4S_DATA_BITS(TRANSFER_ADDRESS_LEN_BITS)) shift_out (.aclk(clk));
axi_shift_register #(
    .N_DATA_BITS(TRANSFER_ADDRESS_LEN_BITS),
    .STAGES(SHIFT_STAGES)
) axi_data_fifo_shift (
    .clk(clk),
    .rst_n(reset_synced),
    .data_in(fifo_out_de_coupled),
    .data_out(shift_out)
);

// Buffer register.
// The output_stream_writer assumes that the data signals are kept stable if
// valid output has been written and o_ready does not become 1 again.
// This is not technically part of the AXI4 contract and also not
// ensured by the shift_register. E.g the data/valid signal can become
// anything as long as the other client is not ready.
// Therefore, we implement a small flip-flop to ensure the needed behavior.
assign shift_out.tready = o_ready;
always_ff @(posedge clk) begin
    if (reset_synced == 1'b0) begin
        o_valid <= 0;
    end else begin
        // Buffer output
        if (o_ready) begin
            if (shift_out.tvalid == 1'b1) begin
                o_data <= shift_out.tdata;
                o_valid <= 1'b1;
            end else begin
                o_valid <= 1'b0;
            end
        end
    end
end



endmodule