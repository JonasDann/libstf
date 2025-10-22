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

always_comb begin
    for (int i = 0; i < NUM_CONFIGS; i++) begin
        out[i].addr = in.addr - ADDR_SPACE_BOUNDS[i];
        out[i].data = in.data;

        if (in.addr >= ADDR_SPACE_BOUNDS[i] && in.addr < ADDR_SPACE_BOUNDS[i + 1]) begin
            out.valid = in.valid;
        end else begin
            out.valid = 1'b0;
        end
    end
end

endmodule
