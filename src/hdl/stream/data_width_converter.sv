`timescale 1ns / 1ps

`include "libstf_macros.svh"

/**
 * Converts an ndata_i stream to a different width.
 *
 * Currently only 8 to 16 elements is supported.
 */
module NDataWidthConverter #(
    parameter type data_t,
    parameter IN_WIDTH,
    parameter OUT_WIDTH
) (
    input logic clk,
    input logic rst_n,

    ndata_i.s in, // #(data_t, IN_WIDTH)
    ndata_i.m out // #(data_t, OUT_WIDTH)
);

`ASSERT_ELAB(IN_WIDTH == 8 && OUT_WIDTH == 16)

logic idx;

generate if (IN_WIDTH == 8 && OUT_WIDTH == 16) begin // Upsize
    data_t[IN_WIDTH - 1:0] reg_data;
    logic[IN_WIDTH - 1:0]  reg_keep;

    always_ff @(posedge clk) begin
        if (rst_n == 1'b0) begin
            idx <= 1'b0;
        end else begin
            if (in.valid && in.ready) begin
                if (!in.last) begin
                    idx <= ~idx;
                end else begin
                    idx <= 1'b0;
                end

                reg_data <= in.data;

                if (idx == 1'b0) begin
                    reg_keep <= in.keep;
                end else begin
                    reg_keep <= '0;
                end
            end
        end
    end

    assign in.ready = out.ready || !out.valid;

    assign out.data[15:8] = in.data;
    assign out.data[7:0]  = reg_data;
    assign out.keep[15:8] = in.keep;
    assign out.keep[7:0]  = reg_keep;
    assign out.last       = in.last;
    assign out.valid      = in.valid && (idx == 1'b1 || in.last);
end endgenerate

endmodule