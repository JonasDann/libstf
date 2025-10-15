`timescale 1ns / 1ps

import libstf::*;

/**
 * Converts a NUM_ELEMENTS ndata stream containing 32bit or 64bit elements to a 64 * NUM_ELEMENTS 
 * AXI stream.
 */
module NDataToAXITyped #(
    parameter NUM_ELEMENTS
) (
    input logic clk,
    input logic rst_n,

    input type_width_t type_width,

    ndata_i.s in, // #(data_t, NUM_ELEMENTS)
    AXI4S.m    out // #(AXI_WIDTH)
);

localparam DATA_WIDTH = 64;
localparam AXI_WIDTH = DATA_WIDTH * NUM_ELEMENTS;

logic idx;

logic[AXI_WIDTH - 1:0]     data_32bit;
logic[AXI_WIDTH / 8 - 1:0] keep_32bit, keep_64bit;

assign in.ready = out.tready;

for (genvar I = 0; I < NUM_ELEMENTS; I++) begin
    assign data_32bit[32 * I+:32] = in.data[I][0+:32];

    for (genvar J = 0; J < 4; J++) begin
        assign keep_32bit[I * 4 + J] = in.keep[I];
    end
    for (genvar J = 0; J < 8; J++) begin
        assign keep_64bit[I * 8 + J] = in.keep[I];
    end
end

always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
        idx <= 1'b0;
    end else begin
        if (in.valid && out.tready) begin
            if (!in.last) begin
                idx <= ~idx;
            end else begin
                idx <= 1'b0;
            end

            data_32bit[AXI_WIDTH - 1:AXI_WIDTH / 2] <= data_32bit[AXI_WIDTH / 2 - 1:0];

            if (idx == 1'b0) begin
                keep_32bit[AXI_WIDTH / 8 - 1:AXI_WIDTH / 16] <= keep_32bit[AXI_WIDTH / 16 - 1:0];
            end else begin
                keep_32bit[AXI_WIDTH / 8 - 1:AXI_WIDTH / 16] <= '0;
            end
        end
    end
end

assign out.tdata  = type_width == BIT32 ? data_32bit : in.data;
assign out.tkeep  = type_width == BIT32 ? keep_32bit : keep_64bit;
assign out.tlast  = in.last;
assign out.tvalid = type_width == BIT32 ? in.valid && (in.last || idx == 1'b1) : in.valid;

endmodule

/**
 * Converts an 64 * NUM_ELEMENTS AXI stream containing 32bit or 64bit elements to a NUM_ELEMENTS 
 * ndata stream.
 */
module AXIToNDataTyped #(
    parameter NUM_ELEMENTS
) (
    input logic clk,
    input logic rst_n,

    input type_width_t type_width,

    AXI4S.s in,   // #(AXI_WIDTH)
    ndata_i.m out // #(data_t, NUM_TUPLES)
);

localparam DATA_WIDTH = 64;
localparam AXI_WIDTH = DATA_WIDTH * NUM_ELEMENTS;

logic idx;

logic[63:0][NUM_ELEMENTS - 1:0] data_32bit;
logic[NUM_ELEMENTS - 1:0]       keep_32bit, keep_64bit;

assign in.tready = type_width == BIT32 ? out.ready && idx == 1'b1 : out.ready;

for (genvar I = 0; I < NUM_ELEMENTS; I++) begin
    assign data_32bit[I][0+:32] = idx == 1'b0 ? in.data[32 * I+:32] : in.data[32 * I + AXI_WIDTH / 2+:32];

    for (genvar J = 0; J < 4; J++) begin
        assign keep_32bit[I] = idx == 1'b0 ? in.tkeep[I * 4] : in.tkeep[I * 4 + AXI_WIDTH / 16];
    end
    for (genvar J = 0; J < 8; J++) begin
        assign keep_64bit[I] = in.tkeep[I * 8];
    end
end

always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
        idx <= 1'b0;
    end else begin
        if (in.tvalid && out.ready) begin
            idx <= ~idx;
        end
    end
end

assign out.data  = type_width == BIT32 ? data_32bit : in.data;
assign out.keep  = type_width == BIT32 ? keep_32bit : keep_64bit;
assign out.last  = type_width == BIT32 ? in.tlast && idx == 1'b1 : in.tlast;
assign out.valid = in.valid;

endmodule
