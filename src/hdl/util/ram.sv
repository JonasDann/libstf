`timescale 1ns / 1ps

module RAM #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter STYLE = "block", // block or ultra
    parameter HAS_CACHE = 0,
    parameter HAS_BYPASS = 0
) (
    input logic clk,

    input logic[ADDR_WIDTH - 1:0] write_addr,
    input logic[DATA_WIDTH - 1:0] write_data,
    input logic                   write_enable,

    input  logic[ADDR_WIDTH - 1:0] read_addr,
    output logic[DATA_WIDTH - 1:0] read_data
);

(* ram_style = STYLE *) logic[DATA_WIDTH - 1:0] ram[(1 << ADDR_WIDTH) - 1:0];

logic[ADDR_WIDTH - 1:0] cache_addr;
logic[DATA_WIDTH - 1:0] cache_data;
logic                   cache_valid = 1'b0;

always_ff @(posedge clk) begin
    // Write operation
    if (write_enable) begin
        ram[write_addr] <= write_data;
    end

    // Read operation
    if (HAS_CACHE) begin
        cache_addr  <= write_addr;
        cache_data  <= write_data;
        cache_valid <= write_enable;
    end

    if (HAS_BYPASS && write_enable && write_addr == read_addr) begin
        read_data <= write_data;
    end else if (HAS_CACHE && cache_valid && cache_addr == read_addr) begin
        read_data <= cache_data;
    end else begin
        read_data <= ram[read_addr];
    end
end

endmodule

module ReadyRAM #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter STYLE = "block", // block or ultra
    parameter HAS_CACHE = 0,
    parameter HAS_BYPASS = 0
) (
    input logic clk,

    input logic[ADDR_WIDTH - 1:0] write_addr,
    input logic[DATA_WIDTH - 1:0] write_data,
    input logic                   write_enable,

    input  logic[ADDR_WIDTH - 1:0] read_addr,
    output logic[DATA_WIDTH - 1:0] read_data,
    input  logic                   read_ready
);

(* ram_style = STYLE *) logic[DATA_WIDTH - 1:0] ram[(1 << ADDR_WIDTH) - 1:0];

logic[ADDR_WIDTH - 1:0] cache_addr;
logic[DATA_WIDTH - 1:0] cache_data;
logic                   cache_valid = 1'b0;

always_ff @(posedge clk) begin
    // Write operation
    if (write_enable) begin
        ram[write_addr] <= write_data;
    end

    // Read operation
    if (HAS_CACHE) begin
        cache_addr  <= write_addr;
        cache_data  <= write_data;
        cache_valid <= write_enable;
    end

    if (read_ready) begin
        if (HAS_BYPASS && write_enable && write_addr == read_addr) begin
            read_data <= write_data;
        end else if (HAS_CACHE && cache_valid && cache_addr == read_addr) begin
            read_data <= cache_data;
        end else begin
            read_data <= ram[read_addr];
        end
    end else begin
        read_data <= read_data;
    end
end

endmodule
