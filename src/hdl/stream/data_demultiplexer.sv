`timescale 1ns / 1ps

module DataDemultiplexer #(
    parameter NUM_STREAMS
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s select, // #(logic[$clog2(NUM_STREAMS) - 1:0])

    ndata_i.s in,              // #(data_t, NUM_ELEMENTS)
    ndata_i.m out[NUM_STREAMS] // #(data_t, NUM_ELEMENTS)
);

logic selected_ready;
logic[NUM_STREAMS - 1:0] selected, out_ready;

assign selected_ready = |(selected & out_ready);
assign select.ready = in.valid && in.last && selected_ready;

assign in.ready = select.valid && selected_ready;

for (genvar I = 0; I < NUM_STREAMS; I++) begin
    assign selected[I] = I == select.data;
    assign out_ready[I] = out[I].ready;

    assign out[I].data = in.data;
    assign out[I].keep = in.keep;
    assign out[I].last = in.last;
    assign out[I].valid = in.valid && select.valid && selected[I];
end

endmodule
