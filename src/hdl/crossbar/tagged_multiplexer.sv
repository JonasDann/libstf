`timescale 1ns / 1ps

/**
 * At the end of the stream, it waits to see all last signals before any elements of a new stream are accepted
 *
 * TODO:
 * 1. I think this should forward round robin to avoid only advancing one of the inputs and avoid too many stalls
 */

module TaggedMultiplexer #(
    parameter type data_t,
    parameter ID,
    parameter NUM_INPUTS,
    parameter TAG_WIDTH,
    parameter LAST_HANDLING = 1, // 0: Wait until we see an element with a last signal for every input stream and produce a dummy last element; 1: Directly forward the incoming elements as they are
    parameter FILTER_KEEP = 1 // 0: Forward all elements even if the keep signal is 0, 1: Do not forward elements where keep is 0
) (
    input logic clk,
    input logic rst_n,

    tagged_i.s in[NUM_INPUTS], // #(data_t, TAG_WIDTH)
    data_i.m  out              // #(data_t)
);

// Note: WAIT_ALL breaks the stream semantics because it may produce dummy last elements in the output
localparam WAIT_ALL = 0;
localparam FORWARD = 1;

logic[1:0] suffix_sum[NUM_INPUTS + 1];
logic[NUM_INPUTS - 1:0] tag_matches;
data_t in_data[NUM_INPUTS];
logic[NUM_INPUTS - 1:0] in_keep, in_last, in_valid, in_ready;

logic[NUM_INPUTS - 1:0] last_seen, n_last_seen;

data_i #(data_t) skid(), n_skid();

always_ff @(posedge clk) begin
    if (!rst_n) begin
        last_seen <= '0;

        skid.valid <= '0;
    end else begin
        last_seen <= n_last_seen;

        skid.data  <= n_skid.data;
        skid.keep  <= n_skid.keep;
        skid.last  <= n_skid.last;
        skid.valid <= n_skid.valid;
    end
end

assign suffix_sum[NUM_INPUTS] = 0;

for(genvar I = 0; I < NUM_INPUTS; I++) begin
    assign in[I].ready = in_ready[I]; // We need to reassign these values to local arrays because SystemVerilog thinks the iterator in a process is not constant for arrays of interfaces

    assign in_data[I]  = in[I].data;
    assign in_keep[I]  = in[I].keep;
    assign in_last[I]  = in[I].last;
    assign in_valid[I] = in[I].valid;

    assign tag_matches[I] = in[I].tag == ID;
    assign suffix_sum[I]  = in[I].valid && (!FILTER_KEEP || in[I].keep) && ~last_seen[I] && tag_matches[I] ? (suffix_sum[I + 1] == 2 || suffix_sum[I + 1] == 1 ? 2 : 1) : suffix_sum[I + 1];
end

always_comb begin
    for (int i = 0; i < NUM_INPUTS; i++) begin
        in_ready[i] = 1'b1;
    end

    n_last_seen = last_seen;

    n_skid.data  = skid.data;
    n_skid.keep  = 1'b0;
    n_skid.last  = 1'b0;
    n_skid.valid = 1'b0; 

    if (skid.ready) begin
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (in_valid[i]) begin
                if ((!FILTER_KEEP || in_keep[i]) && tag_matches[i]) begin
                    if (last_seen[i]) begin // This is an element of the next stream which we cannot process yet
                        in_ready[i] = 1'b0;
                    end

                    if (suffix_sum[i] == 1) begin // This is the next element to be forwarded
                        n_skid.data  = in_data[i];
                        n_skid.keep  = in_keep[i];
                        n_skid.valid = 1'b1;

                        if (LAST_HANDLING == FORWARD) begin
                            n_skid.last = in_last[i];
                        end else if (in_last[i]) begin
                            n_last_seen[i] = 1'b1;
                        end
                    end else begin // Another element is forwarded in this clock cycle => Stall this element
                        in_ready[i] = 1'b0;
                    end
                end else if (LAST_HANDLING == WAIT_ALL && in_last[i]) begin // Other mux has to forward it, we only mark that we have seen the last signal
                    n_last_seen[i] = 1'b1;
                end
            end
        end

        if (LAST_HANDLING == WAIT_ALL && (&last_seen || (suffix_sum[0] == 1 && &(last_seen | in_last)))) begin // We have seen all last signals or the last element is processed in this clock cycle
            n_last_seen  = '0;
            n_skid.last   = 1'b1;
            n_skid.valid  = 1'b1;
        end
    end else begin // Not ready => Hold signals
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (tag_matches[i]) begin
                in_ready[i] = 1'b0;
            end
        end

        n_skid.keep  = skid.keep;
        n_skid.last  = skid.last;
        n_skid.valid = skid.valid;
    end 
end

DataSkidBuffer #(
    .data_t(data_t)
) inst_skid_buffer (
    .clk(clk),
    .rst_n(rst_n),

    .in(skid),
    .out(out)
);

endmodule
