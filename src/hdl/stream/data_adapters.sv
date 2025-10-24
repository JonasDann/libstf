`timescale 1ns / 1ps

`include "axi_macros.svh"
`include "libstf_macros.svh"

/**
 * Converts a ndata stream to an AXI stream.
 */
module NDataToAXI #(
    parameter type data_t,
    parameter NUM_ELEMENTS,
    parameter DATA_WIDTH = $bits(data_t),
    parameter AXI_WIDTH = DATA_WIDTH * NUM_ELEMENTS
) (
    input logic clk,
    input logic rst_n,

    ndata_i.s in, // #(data_t, NUM_ELEMENTS)

    AXI4S.m out // #(AXI_WIDTH)
);

localparam DATA_SIZE = DATA_WIDTH / 8;

assign in.ready = out.tready;

for (genvar I = 0; I < NUM_ELEMENTS; I++) begin
    for (genvar J = 0; J < DATA_SIZE; J++) begin
        assign out.tkeep[I * DATA_SIZE + J] = in.keep[I];
    end
end

assign out.tdata  = in.data;
assign out.tlast  = in.last;
assign out.tvalid = in.valid;

endmodule

/**
 * Converts an AXI stream to a ndata stream.
 */
module AXIToNData #(
    parameter type data_t,
    parameter NUM_ELEMENTS,
    parameter NUM_AXI_ELEMENTS = NUM_ELEMENTS,
    parameter AXI_WIDTH = $bits(data_t) * NUM_AXI_ELEMENTS
) (
    input logic clk,
    input logic rst_n,

    AXI4S.s in, // #(AXI_WIDTH)

    ndata_i.m out // #(data_t, NUM_ELEMENTS)
);

localparam AXI_ELEMENT_WIDTH = AXI_WIDTH / NUM_AXI_ELEMENTS;
localparam AXI_ELEMENT_SIZE = AXI_ELEMENT_WIDTH / 8;

`ASSERT_ELAB(NUM_ELEMENTS == NUM_AXI_ELEMENTS || NUM_ELEMENTS == NUM_AXI_ELEMENTS / 2)

AXI4S #(AXI_ELEMENT_WIDTH * NUM_ELEMENTS) internal(.aclk(clk));

generate if (NUM_ELEMENTS == NUM_AXI_ELEMENTS) begin
    `AXIS_ASSIGN(in, internal);
end else begin
    AXIWidthConverter #(
        .IN_WIDTH(AXI_WIDTH),
        .OUT_WIDTH(AXI_WIDTH / 2)
    ) inst_width_converter (
        .clk(clk),
        .rst_n(rst_n),

        .in(in),
        .out(internal)
    );
end endgenerate

assign internal.tready = out.ready;

for (genvar I = 0; I < NUM_ELEMENTS; I++) begin
    assign out.data[I] = internal.tdata[I * AXI_ELEMENT_WIDTH+:$bits(data_t)];
    assign out.keep[I] = internal.tkeep[I * AXI_ELEMENT_SIZE];
end

assign out.last  = internal.tlast;
assign out.valid = internal.tvalid;

endmodule

/**
 * Converts an AXI stream to a data stream. If the last data beat of the incoming stream is not 
 * full, this returns data beats that have a low keep.
 */
module AXIToData #(
    parameter type data_t,
    parameter AXI_WIDTH = 512,
    parameter DATA_WIDTH = $bits(data_t),
    parameter NUM_ELEMENTS = AXI_WIDTH / DATA_WIDTH
) (
    input logic clk,
    input logic rst_n,

    AXI4S.s in, // #(AXI_WIDTH)

    data_i.m out // #(data_t)
);

logic[$clog2(NUM_ELEMENTS) - 1:0] counter;

assign in.tready = out.ready && counter == NUM_ELEMENTS - 1;

always_ff @(posedge clk) begin
    if (rst_n == 1'b0) begin
        counter <= '0;
    end else begin
        if (in.tvalid && out.ready) begin
            counter <= counter + 1;
        end
    end
end

assign out.data  = in.tdata[counter * DATA_WIDTH+:DATA_WIDTH];
assign out.keep  = in.tkeep[counter * DATA_WIDTH / 8];
assign out.last  = in.tlast && counter == NUM_ELEMENTS - 1;
assign out.valid = in.tvalid;

endmodule
