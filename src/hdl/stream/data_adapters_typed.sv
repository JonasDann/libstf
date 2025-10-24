`timescale 1ns / 1ps

import libstf::*;

/**
 * Converts a NUM_ELEMENTS ndata stream containing 32bit or 64bit elements to a 64 * NUM_ELEMENTS 
 * AXI stream. Use this in cases where you want to have a fixed number of elements in the stream,
 * but the width of the elements in the AXI stream may differ.
 */
module NDataToAXITyped #(
    parameter NUM_ELEMENTS
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s actual_type, // #(type_t)

    ndata_i.s in, // #(data_t, NUM_ELEMENTS)
    AXI4S.m   out // #(AXI_WIDTH)
);

localparam DATA_WIDTH = 64;
localparam AXI_WIDTH = DATA_WIDTH * NUM_ELEMENTS;

typedef logic[AXI_WIDTH / 8 - 1:0] keep_t;

// -- Signals --------------------------------------------------------------------------------------
logic is_upper, n_is_upper;
logic is_32bit;
logic both_valid;

logic[AXI_WIDTH / 2 - 1:0]  data_32bit;
logic[AXI_WIDTH / 16 - 1:0] keep_32bit;
keep_t keep_64bit;

logic[AXI_WIDTH - 1:0] data, n_data;
keep_t keep, n_keep;
logic  last,  n_last;
logic  valid, n_valid;

// -- Logic ----------------------------------------------------------------------------------------
assign is_32bit = GET_TYPE_WIDTH(actual_type.data) == 32;
assign both_valid = actual_type.valid && in.valid;

assign actual_type.ready = in.valid && in.last && out.tready;

assign in.ready = actual_type.valid && out.tready;

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
        is_upper <= 1'b0;

        valid <= 1'b0;
    end else begin
        is_upper <= n_is_upper;

        data  <= n_data;
        keep  <= n_keep;
        last  <= n_last;
        valid <= n_valid;
    end
end

always_comb begin
    n_is_upper = is_upper;

    n_data  = data;
    n_keep  = keep;
    n_last  = last;
    n_valid = 1'b0;

    if (out.tready) begin
        if (both_valid) begin
            if (!in.last) begin
                n_is_upper = ~is_upper;
            end else begin
                n_is_upper = 1'b0;
            end
        end

        if (is_32bit) begin
            if (is_upper == 1'b0) begin // lower
                n_data[AXI_WIDTH / 2 - 1:0]              = data_32bit;
                n_keep[AXI_WIDTH / 8 - 1:AXI_WIDTH / 16] = '0;
                n_keep[AXI_WIDTH / 16 - 1:0]             = keep_32bit;

                if (in.last) begin
                    n_valid = both_valid;
                end
            end else begin // upper
                n_data[AXI_WIDTH - 1:AXI_WIDTH / 2]      = data_32bit;
                n_keep[AXI_WIDTH / 8 - 1:AXI_WIDTH / 16] = keep_32bit;
                n_valid = both_valid;
            end
        end else begin
            n_data  = in.data;
            n_keep  = keep_64bit;
            n_valid = both_valid;
        end

        n_last = in.last;
    end else begin
        n_valid = valid;
    end
end

assign out.tdata  = data;
assign out.tkeep  = keep;
assign out.tlast  = last;
assign out.tvalid = valid;

endmodule

/**
 * Converts an 64 * NUM_ELEMENTS AXI stream containing 32bit or 64bit elements to a NUM_ELEMENTS 
 * ndata stream. Use this in cases where you want to have a fixed number of elements in the stream,
 * but the width of the elements in the AXI stream may differ.
 */
module AXIToNDataTyped #(
    parameter NUM_ELEMENTS
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s actual_type, // #(type_t)

    AXI4S.s   in,   // #(AXI_WIDTH)
    ndata_i.m out // #(data_t, NUM_ELEMENTS)
);

localparam DATA_WIDTH = 64;
localparam AXI_WIDTH = DATA_WIDTH * NUM_ELEMENTS;

logic is_upper;
logic is_32bit;
logic actual_ready;

data64_t[NUM_ELEMENTS - 1:0] data_32bit;
logic[NUM_ELEMENTS - 1:0]    keep_32bit, keep_64bit;

assign is_32bit = GET_TYPE_WIDTH(actual_type.data) == 32;
assign actual_ready = is_32bit ? out.ready && is_upper == 1'b1 : out.ready;
assign actual_type.ready = in.tvalid && in.tlast && actual_ready;

assign in.tready = actual_type.valid && actual_ready;

for (genvar I = 0; I < NUM_ELEMENTS; I++) begin
    assign data_32bit[I][0+:32] = is_upper == 1'b0 ? in.tdata[32 * I+:32] : in.tdata[32 * I + AXI_WIDTH / 2+:32];

    assign keep_32bit[I] = is_upper == 1'b0 ? in.tkeep[I * 4] : in.tkeep[I * 4 + AXI_WIDTH / 16];
    assign keep_64bit[I] = in.tkeep[I * 8];
end

always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
        is_upper <= 1'b0;
    end else begin
        if (actual_type.valid && in.tvalid && out.ready) begin
            is_upper <= ~is_upper;
        end
    end
end

assign out.data  = is_32bit ? data_32bit : in.tdata;
assign out.keep  = is_32bit ? keep_32bit : keep_64bit;
assign out.last  = is_32bit ? in.tlast && is_upper == 1'b1 : in.tlast;
assign out.valid = actual_type.valid && in.tvalid;

endmodule
