`timescale 1ns / 1ps

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

`ASSERT_ELAB((IN_WIDTH == 512 && OUT_WIDTH == 256) || (IN_WIDTH == 256 && OUT_WIDTH == 512))

logic idx;

generate if (IN_WIDTH == 512 && OUT_WIDTH == 256) begin // Downsize
    always_ff @(posedge clk) begin
        if (rst_n == 1'b0) begin
            idx <= 1'b0;
        end else begin
            if (out.tvalid && out.tready) begin
                idx <= ~idx;
            end
        end
    end

    assign in.tready = out.tready && idx == 1'b1;

    assign out.tdata  = in.tdata[256 * idx+:256];
    assign out.tkeep  = in.tkeep[32 * idx+:32];
    assign out.tlast  = in.tlast && idx == 1'b1;
    assign out.tvalid = in.tvalid;
end else if (IN_WIDTH == 256 && OUT_WIDTH == 512) begin // Upsize
    logic[255:0] reg_data;
    logic[31:0]  reg_keep;

    always_ff @(posedge clk) begin
        if (rst_n == 1'b0) begin
            idx <= 1'b0;
        end else begin
            if (in.tvalid && in.tready) begin
                if (!in.tlast) begin
                    idx <= ~idx;
                end else begin
                    idx <= 1'b0;
                end

                reg_data <= in.tdata;

                if (idx == 1'b0) begin
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
    assign out.tvalid         = in.tvalid && (idx == 1'b1 || in.tlast);
end endgenerate

endmodule