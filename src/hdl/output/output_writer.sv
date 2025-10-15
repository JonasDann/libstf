`timescale 1ns / 1ps

import common::*;
import lynxTypes::*;

`include "axi_macros.svh"
`include "libstf_macros.svh"

// This module handles all output of the operator pipeline.
// It transfers the output to the host via FPGA-initiated transfers.
// Moreover, it decides when the last data beat was send and processing can end.
//
// IMPORTANT:
// This component assumes normalize streams.
// E.g. the keep signal should be all 1f, except for data beats that contain a last signal.
// In other words: Writing data that is not all 1 and not last will result in UNEXPECTED behavior.
//
module OutputWriter (
    // Clock and reset
    input  wire             clk,
    input  wire[0:0]        rst_n,

    // The memory configuration to use
    MEMORY_CONFIG.s         memory_conf,
    
    // Data to write
    AXI4SR.s                data_in[N_STRM_AXI],
    
    // Send queue (used to indicated transfers to Coyote)
    metaIntf.m              sq_wr,
    // Completion queue (Answers from coyote about data that finished sending)
    metaIntf.s              cq_wr,
    // Notify interface -> Triggers interrupts on the CPU side
    // once all transfers are finished
    metaIntf.m              notify,

    // The host stream to write the data to
    AXI4SR.m                data_out[N_STRM_AXI]
);

`RESET_RESYNC // Reset pipelining

// ----------------------------------------------------------------------------
// Initiate the transfers to the CPU side
// ----------------------------------------------------------------------------

// ---- De-mux and arbiter the queue and notify signals -----------------------
metaIntf #(.STYPE(req_t))     sq_wr_strm  [N_STRM_AXI] (.aclk(clk));
meta_intf_rr_arbiter #(
  .N_INTERFACES(N_STRM_AXI),
  .STYPE(req_t)
) sq_wr_arbiter (
  .clk(clk),
  .rst_n(reset_synced),
  .intf_in(sq_wr_strm),
  .intf_out(sq_wr)
);

metaIntf #(.STYPE(irq_not_t)) notify_strm [N_STRM_AXI] (.aclk(clk));
meta_intf_rr_arbiter #(
  .N_INTERFACES(N_STRM_AXI),
  .STYPE(irq_not_t)
) notify_arbiter (
  .clk(clk),
  .rst_n(reset_synced),
  .intf_in(notify_strm),
  .intf_out(notify)
);

metaIntf #(.STYPE(ack_t))     cq_wr_strm  [N_STRM_AXI] (.aclk(clk));
cq_de_mux #(
  .N_STREAMS(N_STRM_AXI)
) cq_wr_de_mux (
  .clk(clk),
  .rst_n(reset_synced),
  .data_in(cq_wr),
  .data_out(cq_wr_strm)
);

// ---- FPGA-initiated transfers ----------------------------------------------
generate
  logic [N_STRM_AXI - 1 : 0] output_writer_done;
  for(genvar stream = 0; stream < N_STRM_AXI; stream++) begin
`ifndef DISABLE_OUTPUT_WRITER
    // De-Couple the stream to ease routing
    AXI4SR #(.AXI4S_DATA_BITS(512)) data_in_de_coupled (.aclk(clk));
    axi_ready_de_coupler de_coupler (
      .clk(clk),
      .rst_n(reset_synced),
      .input_stream(data_in[stream]),
      .output_stream(data_in_de_coupled)
    );

    // Convert the memory configuration to a axi_stream
    AXI4_MEM_ALLOC stream_mem_conf();
    conf_to_axi4_mem #(
      .AXI_STRM(stream)
    ) mem_conf_to_axi (
      .clk(clk),
      .rst_n(reset_synced),
      .memory_conf(memory_conf),
      .mem_strm(stream_mem_conf)
    );

    // Invoke the FPGA-initiated transfers for this stream!
    output_stream_writer #(
      .AXI_STRM_ID(stream),
      .TRANSFER_LENGTH_BYTES(TRANSFER_SIZE_BYTES)
    ) stream_writer (
      .clk(clk),
      .rst_n(reset_synced),
      .sq_wr(sq_wr_strm[stream]),
      .cq_wr(cq_wr_strm[stream]),
      .notify(notify_strm[stream]),
      .input_data(data_in_de_coupled),
      .output_data(data_out[stream]),
      .input_mem(stream_mem_conf),
      .all_processing_done(output_writer_done[stream])
    );
`else
    // The output writer can be disabled for certain test cases.
    // In this case, we simply pipe through all the data!
    `AXISR_ASSIGN(data_in[stream], data_out[stream]);
    
    // Set the output writer as done when the last data beat was send
    always_ff @(posedge clk) begin
      if (reset_synced == 1'b0) begin
        output_writer_done[stream] <= 1'b0;
      end else begin
        if (data_in[stream].tlast &
            data_in[stream].tready &
            data_in[stream].tvalid) begin
          output_writer_done[stream] <= 1'b1;
        end
      end
    end

    // Tie of the interfaces we don't need
    always_comb sq_wr_strm[stream].tie_off_m();
    always_comb notify_strm[stream].tie_off_m();
    always_comb cq_wr_strm[stream].tie_off_s();
`endif
  end
endgenerate

endmodule
