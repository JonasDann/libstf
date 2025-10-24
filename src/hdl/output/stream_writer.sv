`timescale 1ns / 1ps

import lynxTypes::*;
import common::*;

`include "axi_macros.svh"
`include "lynx_macros.svh"
`include "libstf_macros.svh"

// This module takes the data from input_data and transfers them to the memory regions
// provided by input_mem via FPGA-initiated transfers. These transfers are triggered via
// the sq_wr interface, and acknowledged from the host via cw_wr.
// Should the available memory region, provided via input_mem, become full or the input
// be read fully, a interrupt is triggered for the host. The host than can act accordingly
// and, e.g., allocate more memory.
//
// This component allows the following configurations:
// STRM                  = The kind of Coyote stream. One of: STRM_CARD, STRM_HOST, STRM_TCP, or STRM_RDMA
// AXI_STRM_ID           = Id of the stream the data will be send on
// IS_LOCAL              = Whether this is a LOCAL_TRANSFER, i.e. between FPGA and host (1) or if RDMA is used (0)
// TRANSFER_LENGTH_BYTES = How many bytes each transfer to the host should have
//
// The output_data port should be connected to the AXI stream of the stream as configured via the
// STRM parameter.
//
// IMPORTANT:
// This component assumes continuous data in the streams.
// E.g. the keep signal should be all f, except for data beats that contain a last signal.
// In other words: Writing data that is not all f and not last will result in UNEXPECTED behavior.
//
module StreamWriter #(
    parameter STRM = STRM_HOST,
    parameter AXI_STRM_ID = 0,
    parameter IS_LOCAL = 1,
    parameter TRANSFER_LENGTH_BYTES = 4096
) (
    input logic             clk,
    input logic             rst_n,

    metaIntf.m sq_wr,
    metaIntf.s cq_wr,
    metaIntf.m notify, // This module triggers an interrupt when all transfers are done

    mem_config_i mem_config,

    AXI4S.s  input_data,
    AXI4SR.m output_data
);

`RESET_RESYNC // Reset pipelining

ready_valid_i #(buffer_t) buffer();
`CONFIG_SIGNALS_TO_INTF(mem_config.buffer, buffer)

// Otherwise, the synthesis merges everything together and
// the path becomes too long!
AXI4S input_data_de_coupled(.aclk(clk));
AXISkidBuffer #(
    .AXI4S_DATA_BITS(512)
) inst_skid_buffer (
    .clk(clk),
    .rst_n(reset_synced),

    .in(input_data),
    .out(input_data_de_coupled)
);

// ---- Assert parameters -------------------------------------------------------

localparam RDMA_WRITE = 7;
localparam OPCODE = IS_LOCAL ? LOCAL_WRITE : RDMA_WRITE;
// How many bits we need to address one transfer of size TRANSFER_LENGTH_BYTES
localparam TRANSFER_ADDRESS_LEN_BITS = $clog2(TRANSFER_LENGTH_BYTES) + 1;
localparam AXI_DATA_BYTES = (AXI_DATA_BITS / 8);

// Assert properties we assume in this module
generate
if (TRANSFER_LENGTH_BYTES % AXI_DATA_BYTES != 0) begin
    $fatal(1, "Illegal values for parameter TRANSFER_LENGTH_BYTES (%0d); Needs to be a a multiple of AXI_DATA_BYTES (%0d).",
        TRANSFER_LENGTH_BYTES,
        AXI_DATA_BYTES
    );
end
if (N_STRM_AXI > 8) begin
    // This limitations is because we support only 3 bits for the stream identifier
    // in the interrupt/notify value.
    $fatal(1, "Module OutputStreamWriter expected at most 8 AXI streams. Found %0d", N_STRM_AXI);
end
endgenerate

`ifndef SYNTHESIS
always_ff @(posedge clk) begin
    if (reset_synced == 1'b0) begin
        ;
    end else if (buffer.ready & buffer.valid) begin
        if (buffer.data.size > MAXIMUM_HOST_ALLOCATION_SIZE_BYTES) begin
            $fatal(1,
                "Module OutputStreamWriter got memory allocation of %0d bytes, which is larger than the at most supported %0d bytes.", 
                buffer.data.size,
                MAXIMUM_HOST_ALLOCATION_SIZE_BYTES
            );
        end
        if (buffer.data.size <= 0) begin      
            $fatal(1,
                "Module OutputStreamWriter got memory allocation of %0d bytes, allocations should be at least %0d in size", 
                buffer.data.size,
                TRANSFER_LENGTH_BYTES
            );
        end
        if (buffer.data.size % TRANSFER_LENGTH_BYTES != 0) begin
            $fatal(1,
                "Module OutputStreamWriter got memory allocation of %0d bytes, which is not a multiple of the transfer size of %0d bytes.", 
                buffer.data.size,
                TRANSFER_LENGTH_BYTES
            );
        end
    end
end
`endif

// ----------------------------------------------------------------------------
// Input logic
// ----------------------------------------------------------------------------
AXI4S data_fifo_in(.aclk(clk));
logic[TRANSFER_ADDRESS_LEN_BITS - 1:0] curr_len, curr_len_succ;
logic curr_len_valid;
logic curr_len_ready;

// The input is ready if there is space in both FIFOs
assign input_data_de_coupled.tready = data_fifo_in.tready & curr_len_ready;
assign data_fifo_in.tdata   = input_data_de_coupled.tdata;
assign data_fifo_in.tkeep   = input_data_de_coupled.tkeep;
assign data_fifo_in.tvalid  = input_data_de_coupled.tvalid;
assign data_fifo_in.tlast   = input_data_de_coupled.tlast;

// Whether the transfer will get full this cycle
logic is_split;
assign is_split = curr_len == TRANSFER_LENGTH_BYTES - AXI_DATA_BYTES || input_data_de_coupled.tlast;
// Counts the number of bytes we will need to transfer.
// Whenever we reached a full transfer, the length is split.
assign curr_len_succ = curr_len + $countones(input_data_de_coupled.tkeep);
assign curr_len_valid = is_split && input_data_de_coupled.tvalid && input_data_de_coupled.tready;

always_ff @(posedge clk) begin
    if (reset_synced == 1'b0) begin
        curr_len <= 0;
    end else begin
        if (input_data_de_coupled.tvalid && input_data_de_coupled.tready) begin
            if (is_split) begin
                curr_len <= 0;
            end else begin
                curr_len <= curr_len_succ;
            end
        end
    end
end

// ----------------------------------------------------------------------------
// Input and length buffering
// ----------------------------------------------------------------------------

// During synthesis, the FIFOs and the remainder of the implementation are placed
// on different Super Logic Regions (SLRs).
// This means there is a path crossing that needs to be done, which adds a high latency
// to any path that uses the FIFO outputs.
// To improve the WNS, we introduce shifting stages. Those stages introduce additional
// registers along the path, which should mean that the SLR crossing is "buffered" by registers.
localparam integer SHIFT_STAGES = 2;

localparam integer TARGET_DATA_DEPTH = 2 * (TRANSFER_LENGTH_BYTES / AXI_DATA_BYTES);
// This ensures we don't go below the minimum size supported by the FIFO
localparam integer DATA_FIFO_DEPTH = TARGET_DATA_DEPTH >= 4 ? TARGET_DATA_DEPTH : 4;

AXI4S axis_data_fifo(.aclk(clk));
FIFOAXI #(
    .DEPTH(DATA_FIFO_DEPTH)
) inst_data_fifo (
    .clk(clk),
    .rst_n(reset_synced),

    .i_data(data_fifo_in),
    .o_data(axis_data_fifo),
    
    .filling_level()
);

logic[TRANSFER_ADDRESS_LEN_BITS - 1:0] next_len;
logic next_len_valid, next_len_ready;
FIFO #(
    .WIDTH(TRANSFER_ADDRESS_LEN_BITS),
    .DEPTH(16)
) inst_len_fifo (
    .i_clk(clk),
    .i_rst_n(reset_synced),

    .i_data(curr_len_succ),
    .i_valid(curr_len_valid),
    .i_ready(curr_len_ready),

    .o_data(next_len),
    .o_valid(next_len_valid),
    .o_ready(next_len_ready),

    .o_filling_level()
);

// -------------------------------------------------------------------------------------------------
// Output logic
// -------------------------------------------------------------------------------------------------
typedef enum logic[2:0] {
    WAIT_VADDR = 0,
    REQUEST = 1,
    TRANSFER = 2,
    WAIT_COMPLETION = 3,
    WAIT_NOTIFY = 4,
    ALL_DONE = 5
} output_state_t;
output_state_t output_state;

// The vaddr we currently write to
vaddress_t vaddr;
// Note: The following two types are chosen to be vaddress_t on purpose
// to prevent potential overflow problems below.
// The number of bytes allocated at vaddr
vaddress_t allocation_size;
// How many bytes we have already written to vaddr
vaddress_t bytes_written_to_allocation;
// Possible performance optimization: Become ready earlier such that
// WAITING for the address takes at most 1 cycle.
// However: Pay attention that you don't immediately read two addresses.
assign buffer.ready = output_state == WAIT_VADDR;

// Tracking of the amount of data we have written in the current transfer
logic[TRANSFER_ADDRESS_LEN_BITS - 1 : 0] bytes_written_to_transfer, bytes_written_to_transfer_succ;
logic[$clog2(AXI_DATA_BYTES) : 0] bytes_to_write_to_transfer;
vaddress_t num_requests, num_completed_transfers;
logic current_transfer_completed;

assign current_transfer_completed = bytes_written_to_transfer_succ == next_len;
assign bytes_to_write_to_transfer = $countones(axis_data_fifo.tkeep);
assign bytes_written_to_transfer_succ = bytes_written_to_transfer + bytes_to_write_to_transfer;
// We get the next length when either
// - The last data beat of the current transfer is done (so the length is available in the next cycle)
// - The length is currently not valid. This can be because:
//    - It was never valid so far (first transfer)
//    - It did not become immediately valid after the 1 cycle we became ready after the last transfer
assign next_len_ready =
    (output_state == TRANSFER && axis_data_fifo.tvalid && output_data.tready && current_transfer_completed) |
    (next_len_valid == 1'b0);

// Completions we get
assign cq_wr.ready = 1;
logic is_completion;
// Note: We used to also validate the OP code here. However, the op code is not set correctly by coyote for
// the cq_wr. Therefore, we only validate the strm & dest. This should however never cause any problems!
assign is_completion = cq_wr.valid && cq_wr.data.strm == STRM && cq_wr.data.dest == AXI_STRM_ID;

// -- Send queue requests --------------------------------------------------------------------------
// Sends a request over transfers with at most TRANSFER_LENGTH_BYTES
always_comb begin
    sq_wr.data.opcode = OPCODE;
    sq_wr.data.strm   = STRM;
    sq_wr.data.mode   = ~IS_LOCAL;
    sq_wr.data.rdma   = ~IS_LOCAL;
    sq_wr.data.remote = ~IS_LOCAL;

    // Note: We always send to coyote thread id 0.
    sq_wr.data.pid  = 0;
    sq_wr.data.dest = AXI_STRM_ID;

    sq_wr.data.vaddr = vaddr;
    sq_wr.data.len   = next_len;
                                                                                              
    // We always mark the transfer as last so we get
    // one acknowledgement per transfer!
    sq_wr.data.last = 1;
    
    // Note: There is a special case where we need to transfer 0 bytes of data.
    // In this case, we don't need to do any request, but only invoke the interrupt.
    sq_wr.valid = output_state == REQUEST & next_len_valid & next_len > 0;
end

// -- Interrupts -----------------------------------------------------------------------------------
logic all_transfers_completed;
assign all_transfers_completed = num_completed_transfers == num_requests;

logic last_transfer;
always_comb begin
    notify.data.pid   = 6'd0;
    // The output value has 32 bits and consists of:
    // 1. The stream id that finished the transfer
    notify.data.value[2:0] = AXI_STRM_ID;
    // 2. How much data as written to the vaddr (at most 2^28 bytes are supported)
    notify.data.value[30:3] = bytes_written_to_allocation;
    // 3. Whether this was the last transfer, i.e. all output data was written
    notify.data.value[31] = last_transfer;
    notify.valid = (output_state == WAIT_COMPLETION && all_transfers_completed) ||
                   (output_state == WAIT_NOTIFY);
end

// -- State machine --------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (reset_synced == 1'b0) begin
        output_state <= WAIT_VADDR;
    end else begin
        case(output_state)
            WAIT_VADDR: begin
                if (buffer.valid) begin
                    // Reset the current state
                    bytes_written_to_allocation <= 0;
                    num_requests                <= 0;
                    num_completed_transfers     <= 0;
                    last_transfer               <= 0;

                    // Get the memory address & size
                    vaddr           <= buffer.data.vaddr;
                    allocation_size <= buffer.data.size;
                    output_state    <= REQUEST;

                    `ifndef SYNTHESIS
                    $display(
                        "FPGAOutputWriter [%0d]: Writing at most %0d bytes to vaddr %0d",
                        AXI_STRM_ID,
                        buffer.data.size,
                        buffer.data.vaddr
                    );
                    `endif
                end end
            REQUEST: begin
                // Requests the next transfer over next_len
                // Possible optimization: Transfer first data beat in REQUEST state already
                if (next_len_valid && sq_wr.ready) begin
                    // There can be a situation where we need to send 0 bytes.
                    // E.g. if the input did not produce any output.
                    // In this case we don't need to send any request and can only trigger the interrupt
                    if (next_len > 0) begin
                        // This is a valid request with data
                        vaddr                       <= vaddr + next_len;
                        output_state                <= TRANSFER;
                        num_requests                <= num_requests + 1;
                        bytes_written_to_allocation <= bytes_written_to_allocation + next_len;
                        bytes_written_to_transfer   <= 0;
                    end else begin
                        // No data, no request, or transfer. Only interrupt.
                        output_state <= WAIT_NOTIFY;
                        // We cannot take the axis_data_fifo.tlast signal here because
                        // the fifo output will never become ready without a request
                        // to coyote. However, the next_len can only be zero if
                        // this was the last, empty transfer.
                        last_transfer <= 1'b1;
                    end                    
                end end 
            TRANSFER: begin
                if (axis_data_fifo.tvalid && output_data.tready) begin
                    // If this was the last data beat of the transfer
                    if (current_transfer_completed) begin
                        if (axis_data_fifo.tlast | allocation_size < bytes_written_to_allocation + TRANSFER_LENGTH_BYTES) begin
                            // If
                            //  1. We have reached the end of the data, OR
                            //  2. The size of the current memory allocation does not fit an additional transfer
                            // We need to
                            //  1. Wait for completion
                            //  2. Trigger a interrupt (which will give us new memory, if more is needed)
                            output_state  <= WAIT_COMPLETION;
                            last_transfer <= axis_data_fifo.tlast;
                        end else begin
                            // Perform next transfer!
                            output_state <= REQUEST;
                        end
                    end else begin
                        bytes_written_to_transfer <= bytes_written_to_transfer_succ;
                    end
                end end
            WAIT_COMPLETION: begin
                if (all_transfers_completed) begin
                    if (notify.ready) begin
                        output_state <= WAIT_VADDR;
                    end else begin
                        output_state <= WAIT_NOTIFY;
                    end
                end end
            WAIT_NOTIFY: begin
                if (notify.ready) begin
                    output_state <= WAIT_VADDR;
                end end
            default:;
        endcase

        if (is_completion) begin
            num_completed_transfers <= num_completed_transfers + 1;
        end
    end
end

// -- Assign output data ---------------------------------------------------------------------------
assign output_data.tdata     = axis_data_fifo.tdata;
assign output_data.tid       = '0;
assign output_data.tkeep     = axis_data_fifo.tkeep;
assign output_data.tlast     = current_transfer_completed;
assign output_data.tvalid    = output_state == TRANSFER && axis_data_fifo.tvalid;
assign axis_data_fifo.tready = output_state == TRANSFER && output_data.tready;

endmodule
