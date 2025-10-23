`timescale 1ns / 1ps

/**
 * The ReadyValidDuplicator creates NUM_INTERFACES outputs based on one input. The ready signal of 
 * the input is driven when all output ready signals are high.
 */
module ReadyValidDuplicator #(
    parameter integer NUM_INTERFACES
) (
    input logic clk,
    input logic rst_n,

    ready_valid_i.s in,                 // #(data_t)
    ready_valid_i.m out[NUM_INTERFACES] // #(data_t)
);

logic[NUM_INTERFACES - 1:0] out_ready;
logic[NUM_INTERFACES - 1:0] mask, n_mask;

assign in.ready = &out_ready;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        mask <= '1;     
    end else begin
        mask <= n_mask;
    end
end

always_comb begin
    n_mask = mask;

    if (in.ready) begin
        n_mask = '1;
    end else begin
        n_mask = mask & ~out_ready;
    end
end

for (genvar I = 0; I < NUM_INTERFACES; I++) begin
    assign out_ready[I] = out[I].ready;

    assign out[I].data  = in.data;
    assign out[I].valid = in.valid && mask[I];
end

endmodule

/**
 * The ReadyValidCombiner combines the data of two inputs into one output.
 */
module ReadyValidCombiner (
    ready_valid_i.s left,  // #(left_t)
    ready_valid_i.s right, // #(right_t)
    ready_valid_i.m out    // #({left_t, right_t})
);

assign left.ready  = right.valid && out.ready;
assign right.ready = left.valid  && out.ready;

assign out.data  = {left.data, right.data};
assign out.valid = left.valid && right.valid;

endmodule
