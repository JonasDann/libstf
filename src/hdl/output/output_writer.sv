`timescale 1ns / 1ps

import common::*;
import lynxTypes::*;

`include "axi_macros.svh"
`include "libstf_macros.svh"

// This module handles writes to N_STRM_AXI AXI4S streams.
// It transfers the output to the host via FPGA-initiated transfers.
//
// IMPORTANT:
// This component assumes normalized streams.
// E.g. the keep signal should be all 1f, except for data beats that contain a last signal.
// In other words: Writing data that is not all 1 and not last will result in UNEXPECTED behavior.
//
module OutputWriter (
    input logic clk,
    input logic rst_n,

    metaIntf.m sq_wr,
    metaIntf.s cq_wr,
    metaIntf.m notify,

    mem_config_i mem_config[N_STRM_AXI],

    AXI4S.s  data_in[N_STRM_AXI],
    AXI4SR.m data_out[N_STRM_AXI]
);

`RESET_RESYNC // Reset pipelining

// -- De-mux and arbiter the queue and notify signals ----------------------------------------------
metaIntf #(.STYPE(req_t))     sq_wr_strm  [N_STRM_AXI](.aclk(clk));
metaIntf #(.STYPE(ack_t))     cq_wr_strm  [N_STRM_AXI](.aclk(clk));
metaIntf #(.STYPE(irq_not_t)) notify_strm [N_STRM_AXI](.aclk(clk));

MetaIntfArbiter #(
  .N_INTERFACES(N_STRM_AXI),
  .STYPE(req_t)
) inst_sq_wr_arbiter (
  .clk(clk),
  .rst_n(reset_synced),
  .intf_in(sq_wr_strm),
  .intf_out(sq_wr)
);

CQDemultiplexer #(
  .N_STREAMS(N_STRM_AXI)
) inst_cq_wr_de_mux (
  .clk(clk),
  .rst_n(reset_synced),
  .data_in(cq_wr),
  .data_out(cq_wr_strm)
);

MetaIntfArbiter #(
  .N_INTERFACES(N_STRM_AXI),
  .STYPE(irq_not_t)
) inst_notify_arbiter (
  .clk(clk),
  .rst_n(reset_synced),
  .intf_in(notify_strm),
  .intf_out(notify)
);

// -- FPGA-initiated transfers ---------------------------------------------------------------------
for(genvar I = 0; I < N_STRM_AXI; I++) begin
    AXI4S #(.AXI4S_DATA_BITS(512)) data_in_skid (.aclk(clk));

    // Skid buffer to ease routing
    AXISkidBuffer #(
        .AXI4S_DATA_BITS(512)
    ) inst_skid_buffer (
        .clk(clk),
        .rst_n(reset_synced),
        .in(data_in[I]),
        .out(data_in_skid)
    );

    // Invoke the FPGA-initiated transfers for this stream!
    StreamWriter #(
        .AXI_STRM_ID(I),
        .TRANSFER_LENGTH_BYTES(TRANSFER_SIZE_BYTES)
    ) inst_stream_writer (
        .clk(clk),
        .rst_n(reset_synced),

        .sq_wr(sq_wr_strm[I]),
        .cq_wr(cq_wr_strm[I]),
        .notify(notify_strm[I]),

        .mem_config(mem_config[I]),

        .input_data(data_in_skid),
        .output_data(data_out[I])
    );
end

endmodule
