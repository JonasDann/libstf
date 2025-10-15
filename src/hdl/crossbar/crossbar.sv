`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ETH Zürich
// Engineer: Philipp Engljähringer
// 
// Create Date: 01/2025 01:15:37 PM
// Module Name: 
// Project Name: PFC-HashJoin
// Target Devices: xcvu47p-fsvh2892-2L-e
// Tool Versions: 2024.2
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Crossbar #(
    parameter type tuple_t,
    parameter NUM_INPUTS,
    parameter NUM_OUTPUTS,
    parameter LAST_HANDLING = 1, // Handling of the last signal by the Multiplexer
    parameter FILTER_KEEP = 1,   // If the Multiplexer filters by keep signal
    parameter NUM_SKID_BUFFERS = 8,
    parameter TAG_WIDTH        = $clog2(NUM_OUTPUTS)
) (
    input logic clk,
    input logic rst_n,

    tagged_i.s in[NUM_INPUTS],  // #(tuple_t, TAG_WIDTH)
    data_i.m  out[NUM_OUTPUTS] // #(tuple_t)
);

tagged_i #(tuple_t, TAG_WIDTH) skid_pipe[NUM_INPUTS][NUM_SKID_BUFFERS + 1]();
tagged_i #(tuple_t, TAG_WIDTH) mux_in[NUM_OUTPUTS][NUM_INPUTS]();

logic[NUM_INPUTS-1:0][NUM_OUTPUTS-1:0] mux_ready_transposed;

generate
    for(genvar I = 0; I < NUM_INPUTS; I++) begin
        assign in[I].ready = skid_pipe[I][0].ready;
        
        assign skid_pipe[I][0].data  = in[I].data;
        assign skid_pipe[I][0].tag   = in[I].tag;
        assign skid_pipe[I][0].keep  = in[I].keep;
        assign skid_pipe[I][0].last  = in[I].last;
        assign skid_pipe[I][0].valid = in[I].valid;
    end
endgenerate

// SkidBuffer pipeline
for (genvar I = 0; I < NUM_INPUTS; I++) begin
    for (genvar J = 0; J < NUM_SKID_BUFFERS; J++) begin
        TaggedSkidBuffer #(
            .tuple_t(tuple_t),
            .TAG_WIDTH(TAG_WIDTH)
        ) inst_skid_buffer (
            .clk(clk),
            .rst_n(rst_n),

            .in(skid_pipe[I][J]),
            .out(skid_pipe[I][J + 1])
        );
    end
end

// Multiplexers
for(genvar I = 0; I < NUM_INPUTS; I++) begin
    assign skid_pipe[I][NUM_SKID_BUFFERS].ready = &mux_ready_transposed[I];

    for(genvar O = 0; O < NUM_OUTPUTS; O++) begin
        assign mux_ready_transposed[I][O] = mux_in[O][I].ready;

        assign mux_in[O][I].data  = skid_pipe[I][NUM_SKID_BUFFERS].data;
        assign mux_in[O][I].tag   = skid_pipe[I][NUM_SKID_BUFFERS].tag;
        assign mux_in[O][I].keep  = skid_pipe[I][NUM_SKID_BUFFERS].keep;
        assign mux_in[O][I].last  = skid_pipe[I][NUM_SKID_BUFFERS].last;
        assign mux_in[O][I].valid = skid_pipe[I][NUM_SKID_BUFFERS].valid;
    end
end

for(genvar O = 0; O < NUM_OUTPUTS; O++) begin
    TaggedMultiplexer #(
        .tuple_t(tuple_t),
        .ID(O),
        .NUM_INPUTS(NUM_INPUTS),
        .TAG_WIDTH(TAG_WIDTH),
        .LAST_HANDLING(LAST_HANDLING),
        .FILTER_KEEP(FILTER_KEEP)
    ) inst_mux (
        .clk(clk),
        .rst_n(rst_n),

        .in(mux_in[O]),
        .out(out[O])
    );
end

endmodule
