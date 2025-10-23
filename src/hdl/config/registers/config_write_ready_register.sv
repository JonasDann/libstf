`timescale 1ns / 1ps

/**
 * WARNING: For now, this register does not apply back pressure to the GlobalConfig. So values may 
 * be lost.
 */
module ConfigWriteReadyRegister #(
    parameter integer ADDR,
    parameter type    TYPE
) (
    input logic clk,
    input logic rst_n,

    config_i.s      conf,
    ready_valid_i.m data // #(TYPE)
);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        data.valid <= 1'b0;
    end else begin
        if (conf.valid && conf.addr == ADDR) begin
            data.data  <= TYPE'(conf.data);
            data.valid <= 1'b1;
        end else if (data.ready) begin
            data.valid <= 1'b0;
        end
    end
end

endmodule
