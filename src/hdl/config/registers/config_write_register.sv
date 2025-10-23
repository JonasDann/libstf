`timescale 1ns / 1ps

module ConfigWriteRegister #(
    parameter integer ADDR,
    parameter type    TYPE
) (
    input logic clk,

    config_i.s  conf,
    output TYPE data
);

always_ff @(posedge clk) begin
    if (conf.valid && conf.addr == ADDR) begin
        data <= conf.data;
    end
end

endmodule
