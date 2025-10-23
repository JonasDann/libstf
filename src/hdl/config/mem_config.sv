`timescale 1ns / 1ps

import libstf::*;

`include "libstf_macros.svh"
`include "config_macros.svh"

module MemConfig #(
    parameter NUM_STREAMS
) (
    input logic clk,
    input logic rst_n,

    config_i.s   conf,
    mem_config_i out[NUM_STREAMS]
);

localparam NUM_REGISTERS = 2;

for (genvar I = 0; I < NUM_STREAMS; I++) begin
    ready_valid_i #(vaddress_t)   vaddr();
    ready_valid_i #(alloc_size_t) size();

    mem_config_i result();

    `CONFIG_WRITE_READY_REGISTER(I * NUM_REGISTERS + 0, vaddress_t, vaddr)
    `CONFIG_WRITE_READY_REGISTER(I * NUM_REGISTERS + 1, alloc_size_t, size)
    `READY_COMBINE(vaddr, size, result.buffer)

    `READY_VALID_ASSIGN(out[I].buffer, result.buffer)
end

endmodule
