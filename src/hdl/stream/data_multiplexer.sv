`timescale 1ns / 1ps

module DataMultiplexer #(
    parameter type data_t,
    parameter NUM_ELEMENTS,
    parameter NUM_STREAMS
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s select, // #(logic[$clog2(NUM_STREAMS) - 1:0])

    ndata_i.s in[NUM_STREAMS], // #(data_t, NUM_ELEMENTS)
    ndata_i.m out              // #(data_t, NUM_ELEMENTS)
);

logic[NUM_STREAMS - 1:0] selected;

data_t[NUM_ELEMENTS - 1:0][NUM_STREAMS - 1:0] in_data;
logic[NUM_ELEMENTS - 1:0][NUM_STREAMS - 1:0]  in_keep;
logic[NUM_STREAMS - 1:0] in_last;
logic[NUM_STREAMS - 1:0] in_valid;

assign select.ready = out.valid && out.last && out.ready;

for (genvar I = 0; I < NUM_STREAMS; I++) begin
    assign selected[I] = I == select.data;

    assign in[I].ready = select.valid && selected[I] && out.ready;

    assign in_data[I]  = in[I].data;
    assign in_keep[I]  = in[I].keep;
    assign in_last[I]  = in[I].last;
    assign in_valid[I] = in[I].valid;
end

always_comb begin
    for (int i = 0; i < NUM_STREAMS; i++) begin
        if (select.valid && selected[i]) begin
            out.data  = in_data[i];
            out.keep  = in_keep[i];
            out.last  = in_last[i];
            out.valid = in_valid[i];
        end
    end
end

endmodule
