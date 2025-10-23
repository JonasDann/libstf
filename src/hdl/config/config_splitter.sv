`timescale 1ns / 1ps

/**
 * The ConfigSplitter splits a config interface into multiple config interfaces based on address
 * space bounds. I also substracts the corresponding address space bound from the address it passes
 * on.
 */
module ConfigSplitter #(
    parameter integer NUM_CONFIGS,
    parameter integer ADDR_SPACE_BOUNDS[NUM_CONFIGS + 1]
) (
    input logic clk,
    input logic rst_n,

    config_i.s in,
    config_i.m out[NUM_CONFIGS]
);

logic[NUM_CONFIGS - 1:0] out_valid;

for (genvar I = 0; I < NUM_CONFIGS; I++) begin
    assign out[I].addr  = in.addr - ADDR_SPACE_BOUNDS[I];
    assign out[I].data  = in.data;
    assign out[I].valid = out_valid[I];
end

always_comb begin
    for (int i = 0; i < NUM_CONFIGS; i++) begin
        if (in.addr >= ADDR_SPACE_BOUNDS[i] && in.addr < ADDR_SPACE_BOUNDS[i + 1]) begin
            out_valid[i] = in.valid;
        end else begin
            out_valid[i] = 1'b0;
        end
    end
end

endmodule
