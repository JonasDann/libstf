`timescale 1ns / 1ps

`include "libstf_macros.svh"

/**
 * Converts an AXI stream to a different width.
 *
 * Currently only 512bit to 256bit and 512bit to 256bit is supported.
 */
module AXIWidthConverter #(
    parameter IN_WIDTH,
    parameter OUT_WIDTH
) (
    input logic clk,
    input logic rst_n,

    AXI4S.s in, // #(IN_WIDTH)
    AXI4S.m out // #(OUT_WIDTH)
);

`ASSERT_ELAB(IN_WIDTH == 512 && OUT_WIDTH == 256)

logic is_upper;

generate if (IN_WIDTH == 512 && OUT_WIDTH == 256) begin // Downsize
    logic has_upper_data, beat_done;

    assign has_upper_data = |in.tkeep[63:32];
    assign beat_done = is_upper || !has_upper_data;

    always_ff @(posedge clk) begin
        if (rst_n == 1'b0) begin
            is_upper <= 1'b0;
        end else begin
            if (in.tvalid && out.tready) begin
                if (has_upper_data) begin
                    is_upper <= ~is_upper;
                end else begin
                    is_upper <= 1'b0;
                end
            end
        end
    end

    assign in.tready = out.tready && beat_done;

    assign out.tdata  = in.tdata[256 * is_upper+:256];
    assign out.tkeep  = in.tkeep[32 * is_upper+:32];
    assign out.tlast  = in.tlast && beat_done;
    assign out.tvalid = in.tvalid;
end else if (IN_WIDTH == 256 && OUT_WIDTH == 512) begin // Upsize // TODO: This code does not work
    logic[255:0] reg_data;
    logic[31:0]  reg_keep;

    always_ff @(posedge clk) begin
        if (rst_n == 1'b0) begin
            is_upper <= 1'b0;
        end else begin
            if (in.tvalid && in.tready) begin
                if (!in.tlast) begin
                    is_upper <= ~is_upper;
                end else begin
                    is_upper <= 1'b0;
                end

                reg_data <= in.tdata;

                if (is_upper == 1'b0) begin
                    reg_keep <= in.tkeep;
                end else begin
                    reg_keep <= '0;
                end
            end
        end
    end

    assign in.tready = out.tready || !out.tvalid;

    assign out.tdata[511:256] = in.tdata;
    assign out.tdata[255:0]   = reg_data;
    assign out.tkeep[63:32]   = in.tkeep;
    assign out.tkeep[31:0]    = reg_keep;
    assign out.tlast          = in.tlast;
    assign out.tvalid         = in.tvalid && (is_upper || in.tlast);
end endgenerate

endmodule