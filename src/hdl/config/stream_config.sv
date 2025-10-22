`timescale 1ns / 1ps

`include "config_macros.svh"

module StreamConfig #(
    parameter SELECT_WIDTH
) (
    input logic clk,
    input logic rst_n,

    config_i.s in,
    stream_config_i out // #(SELECT_WIDTH)
);

ready_valid_i #(select_t) select;

`CONFIG_WRITE_READY_REGISTER(0, logic[SELECT_WIDTH - 1:0], select)
`READY_DUPLICATE(2, select, {out.in_select, out.out_select})
`CONFIG_WRITE_READY_REGISTER(1, type_t, out.type)

endmodule
