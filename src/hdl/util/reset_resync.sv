`timescale 1ns / 1ps

/**
 * This module delays the reset signal by one cycle by buffering it in a register.
 *
 * This can be used to break long reset chains which can lead to timing issues and designs that are 
 * difficult to place & optimize.
 */
module ResetResync (
    input  logic clk,
    input  logic reset_in,
    output logic reset_out
);

// Initialize as not reset
logic  reset_buffer = 1'b1;

always_ff @(posedge clk) begin
    reset_buffer <= reset_in;
    reset_out    <= reset_buffer;
end

endmodule
