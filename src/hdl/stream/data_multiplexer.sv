`timescale 1ns / 1ps

module DataMultiplexer #(
    parameter NUM_STREAMS
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s select, // #(logic[$clog2(NUM_STREAMS) - 1:0])

    ndata_i.s in[NUM_STREAMS], // #(data_t, NUM_TUPLES)
    ndata_i.m out              // #(data_t, NUM_TUPLES)
);

assign select.ready = out.valid && out.last && out.ready;

always_comb begin
    for (int i = 0; i < NUM_STREAMS; i++) begin
        if (select.valid && i == select.data) begin
            in[i].ready = out.ready;

            out.data  = in[i].data;
            out.keep  = in[i].keep;
            out.last  = in[i].last;
            out.valid = in[i].valid;
        end else begin
            in[i].ready = 1'b0;
        end
    end
end

endmodule
