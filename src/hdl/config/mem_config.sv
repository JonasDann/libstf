`timescale 1ns / 1ps

`include "config_macros.svh"

module MemConfig (
    input logic clk,
    input logic rst_n,

    config_i.s in,
    mem_config_i out
);

ready_valid_i #(vaddr_t)      vaddr;
ready_valid_i #(alloc_size_t) size;

`CONFIG_WRITE_READY_REGISTER(0, vaddr_t, vaddr)
`CONFIG_WRITE_READY_REGISTER(0, alloc_size_t, size)
`READY_COMBINE(2, {vaddr, size}, out.buffer)

endmodule
