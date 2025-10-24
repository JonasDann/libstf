`timescale 1ns / 1ps

module AXIDemultiplexer #(
    parameter NUM_STREAMS
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s select, // #(logic[$clog2(NUM_STREAMS) - 1:0])

    AXI4S.s in,
    AXI4S.m out[NUM_STREAMS]
);

logic selected_ready;
logic[NUM_STREAMS - 1:0] selected, out_ready;

assign selected_ready = |(selected & out_ready);
assign select.ready = in.tvalid && in.tlast && selected_ready;

assign in.tready = select.valid && selected_ready;

for (genvar I = 0; I < NUM_STREAMS; I++) begin
    assign selected[I] = I == select.data;
    assign out_ready[I] = out[I].tready;

    assign out[I].tdata = in.tdata;
    assign out[I].tkeep = in.tkeep;
    assign out[I].tlast = in.tlast;
    assign out[I].tvalid = in.tvalid && select.valid && selected[I];
end

endmodule
