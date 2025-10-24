`timescale 1ns / 1ps

`include "libstf_macros.svh"
`include "config_macros.svh"

module StreamConfig #(
    parameter NUM_SELECT,
    parameter NUM_STREAMS
) (
    input logic clk,
    input logic rst_n,

    config_i.s      conf,
    stream_config_i out[NUM_STREAMS] // #(SELECT_WIDTH)
);

localparam SELECT_WIDTH = $clog2(NUM_SELECT);
localparam NUM_REGISTERS = 2;

typedef logic[SELECT_WIDTH - 1:0] select_t;

for (genvar I = 0; I < NUM_STREAMS; I++) begin
    ready_valid_i #(select_t) select();
    ready_valid_i #(type_t)   data_type();
    stream_config_i #(SELECT_WIDTH) result();

    `CONFIG_WRITE_READY_REGISTER(I * NUM_REGISTERS + 0, select_t, select)
    `CONFIG_WRITE_READY_REGISTER(I * NUM_REGISTERS + 1, type_t, data_type)

    `CONFIG_INTF_TO_SIGNALS(select,    out[I].select)
    `CONFIG_INTF_TO_SIGNALS(data_type, out[I].data_type)
end

endmodule
