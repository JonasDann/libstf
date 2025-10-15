`timescale 1ns / 1ps

/**
 * The SerialDecoupler splits up data beats of an ndata stream into individual data streams per 
 * element and assigns them a serial number in the tag field.
 */
module SerialDecoupler #(
    parameter type data_t, 
    parameter NUM_ELEMENTS,
    parameter SERIAL_WIDTH
) (
    input logic clk,
    input logic rst_n,
    
    ndata_i.s in,                // #(data_t, NUM_ELEMENTS)
    tagged_i.m out[NUM_ELEMENTS] // #(data_t, SERIAL_WIDTH)
);

localparam DATA_BITS = $clog2(NUM_ELEMENTS);
localparam SERIAL_BEAT_BITS = SERIAL_WIDTH - DATA_BITS;

typedef logic[SERIAL_BEAT_BITS - 1:0] beat_serial_t;

beat_serial_t serial_count;

tagged_i #(data_t, SERIAL_WIDTH) n_out[NUM_ELEMENTS]();
logic[NUM_ELEMENTS - 1:0] out_valid, out_ready;

assign in.ready = ~|out_valid || &out_ready;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        serial_count <= '0;     
    end else begin
        if (in.valid && in.ready) begin
            serial_count <= serial_count + 1;
        end else begin
            serial_count <= serial_count;
        end
    end
end

for (genvar I = 0; I < NUM_ELEMENTS; I++) begin
    assign out_valid[I] = out[I].valid;
    assign out_ready[I] = out[I].ready;

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            out[I].valid <= 1'b0;     
        end else begin
            out[I].data  <= n_out[I].data;
            out[I].tag   <= n_out[I].tag;
            out[I].keep  <= n_out[I].keep;
            out[I].last  <= n_out[I].last;
            out[I].valid <= n_out[I].valid;
        end
    end

    always_comb begin
        n_out[I].data  = out[I].data;
        n_out[I].tag   = out[I].tag;
        n_out[I].keep  = out[I].keep;
        n_out[I].last  = out[I].last;
        n_out[I].valid = 1'b0;

        if (in.ready) begin
            n_out[I].data  = in.data[I];
            n_out[I].tag   = (serial_count << DATA_BITS) + I;
            n_out[I].keep  = in.keep[I];
            n_out[I].last  = in.last;
            n_out[I].valid = in.valid;
        end else if (!out[I].ready) begin // Not all output streams are ready => We need to stall and keep only the valid signals of the lanes that are not ready
            n_out[I].valid = out[I].valid;
        end
    end
end

endmodule
