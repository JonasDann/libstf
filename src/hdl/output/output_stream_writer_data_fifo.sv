`timescale 1ns / 1ps

`include "libstf_macros.svh"

// This module implements a FIFO queue only to be used in the
// output_stream_writer components.
// It handles a edge case that stems from the filter part of the design
// as can be read below.
// Otherwise, it behaves like the fifo_axi module.
module output_stream_writer_data_fifo #(
    parameter integer DEPTH = 1024,
    parameter integer SHIFT_STAGES = 0
)(
    input logic clk,
    input logic rst_n,

    AXI4SR.s input_data,
    AXI4SR.m output_data,

    output logic[$clog2(DEPTH):0] filling_level
);

`RESET_RESYNC // Reset pipelining

// ---- Implementation -------------------------------------------------------
// There is one special case we need to solve here:
// Due to the implementation in the fixed_width_collector (see case 2.2), it can be that there is one additional data beat is provided
// that has all keep signals 0 and last set to 1. However: This complicates the whole implementation of reading the fifo output since
// the implementation is currently based on number of bytes to read. Since this data beat has 0 bytes to read (keep='0), it will never
// be read and the host interrupt is done with last = 0.
// Therefore: We buffer all input here, if its not last. This way, we can merge those two data beats!

assign input_data.tready = fifo_input.tready;

AXI4SR fifo_input (.aclk(clk));
logic [511:0] input_data_buf;
logic [63:0] input_keep_buf;
logic input_last_buf;
logic input_buf_valid;

always_ff @(posedge clk) begin
    if (reset_synced == 1'b0) begin
        input_data_buf <= '0;
        input_keep_buf <= '0;
        input_last_buf <= 0;
        input_buf_valid <= 0;
    end else begin
        if (input_data.tvalid & input_data.tready) begin
            if (input_data.tlast == 1'b1 & input_data.tkeep == '0) begin
                // Flush with last set to 1. Either:
                // - A previous data beat is flushed as well
                // - Zero data is flushed since this component was resetted before
                // (There can only be one last signal in between resets)
                fifo_input.tdata <= input_data_buf;
                fifo_input.tkeep <= input_keep_buf;
                fifo_input.tlast  <= 1;
                fifo_input.tvalid <= 1;
                input_buf_valid <= 0;
            end else begin
                // Buffer the data to put out in the next cycle!
                input_data_buf <= input_data.tdata;
                input_keep_buf <= input_data.tkeep;
                input_last_buf <= input_data.tlast;

                if (input_buf_valid == 1'b1) begin
                    // Buffer is flushed and remains valid
                    fifo_input.tdata <= input_data_buf;
                    fifo_input.tkeep <= input_keep_buf;
                    fifo_input.tlast <= input_last_buf;
                    fifo_input.tvalid <= 1;
                end else begin
                    // Buffer becomes valid, ... 
                    input_buf_valid <= 1;
                    //... but we don't provide output in this cycle!
                    fifo_input.tvalid <= 0;
                end
            end
        end else begin
            if (fifo_input.tready) begin
                if (input_buf_valid == 1'b1 & input_last_buf == 1'b1) begin
                    // Flush the remainder!
                    fifo_input.tdata <= input_data_buf;
                    fifo_input.tkeep <= input_keep_buf;
                    fifo_input.tlast  <= input_last_buf;
                    fifo_input.tvalid <= 1;
                    input_buf_valid  <= 0;
                end else begin
                    fifo_input.tvalid <= 0;
                end
            end
        end
    end
end

// FIFO instance
AXI4SR shift_in (.aclk(clk));
axi_fifo #(
    .DEPTH(DEPTH)
) fifo_inst (
    .clk(clk),
    .rst_n(reset_synced),
    .input_data(fifo_input),
    .output_data(shift_in),
    .filling_level(filling_level)
);

// De coupling. Otherwise, the synthesis merges everything together and
// the path becomes too long!
AXI4SR shift_in_de_coupled (.aclk(clk));
axi_ready_de_coupler de_coupler (
  .clk(clk),
  .rst_n(reset_synced),
  .input_stream(shift_in),
  .output_stream(shift_in_de_coupled)
);

// SHIFT Stage
axi_shift_register #(
    .N_DATA_BITS(512),
    .STAGES(SHIFT_STAGES)
) shift_inst (
    .clk(clk),
    .rst_n(reset_synced),
    .data_in(shift_in_de_coupled),
    .data_out(output_data)
);

endmodule