`timescale 1ns / 1ps

`include "axi_macros.svh"
`include "axi_intf.sv"
`include "libstf_macros.svh"

//
// This module handles the configuration of the design
// It reads/write configuration messages via the axi_ctrl stream
// and provides them to the outside as in/output
//
// The configuration values are essential to the design. However, given that their number is 
// quite large by now, there where problems during synthesis with paths becoming too long.
// Therefore, we moved everything but the manual registers (see below) into own modules.
// We can write to these modules via three simple registers (valid, address, data)
// and they then perform the task of splitting this data into the correct configuration values.
// However: With this split comes another problem. Due to the different configurations being used
// in different paths of the design but all being inferred from this module, the path to write to
// those sub-modules was also becoming too long! This also due to different paths of the design
// being placed into different SLRs. 
// Therefore: We implement additional shift register. Those registers simply pass the data through.
// But due to the use of additional registers, the routing becomes easier and the paths shorter!
// See the usage of this module below.
//
module GlobalConfig #(
    parameter integer NUM_CONFIGS,
    parameter integer ADDR_SPACE_BOUNDS[NUM_CONFIGS + 1]
) (
    // Clock and reset
    input logic clk,
    input logic rst_n,

    // Control stream -> Used for configuration
    AXI4L.s          axi_ctrl,

    // Configurations
    config_i.m       configs[NUM_CONFIGS]
);

`RESET_RESYNC // Reset pipelining

// -- Internal registers -------------------------------------------------------------------
// Note: We read the address shifted to the right by ADDR_LSB (3)
// The reason is that the address is supposed to address bytes,
// not registers!
// Every register has AXIL_DATA_BITS (64) bits/8 bytes
// -> We shift the address by 3 bit to the right
//    To address the whole register!
localparam integer ADDR_LSB = $clog2(AXIL_DATA_BITS/8);
localparam integer ADDR_MSB = $clog2(ADDR_SPACE_BOUNDS[NUM_CONFIGS]);
localparam integer AXI2_ADDR_BITS = ADDR_LSB + ADDR_MSB; // TODO: Enable again

logic [AXI_ADDR_BITS-1:0] axi_awaddr;
logic axi_awready;
logic [AXI_ADDR_BITS-1:0] axi_araddr;
logic axi_arready;
logic [1:0] axi_bresp;
logic axi_bvalid;
logic axi_wready;
logic [AXIL_DATA_BITS-1:0] axi_rdata;
logic [1:0] axi_rresp;
logic axi_rvalid;

logic any_wstrb_valid;
logic slv_reg_rden;
logic slv_reg_wren;
logic aw_en;

// Sub configurations
config_i pre_splitter_config();
config_i internal_configs[NUM_CONFIGS]();

for (genvar I = 0; I < NUM_CONFIGS; I++) begin
    ShiftRegister #(.WIDTH(AXI_ADDR_BITS + AXIL_DATA_BITS + 1), .LEVELS(1)) inst_shift_reg (
        .i_clk(clk),
        .i_rst_n(reset_synced),

        .i_data({internal_configs[I].addr, internal_configs[I].data, internal_configs[I].valid}),
        .o_data({         configs[I].addr,          configs[I].data,          configs[I].valid})
    );
end

// -- READ/WRITE handling -----------------------------------------------------------------------

// Write process
localparam N_WRT_STRB = (AXIL_DATA_BITS/8);

// Whether there is any valid data
// Note: It can be that the write address & data are valid but there is no valid data to write.
//       In these cases we cannot set the register to valid as this case is different from writing
//       all zero to the registers.
// -> We track whether there is any valid data to determine if the register below become valid.
assign any_wstrb_valid = |axi_ctrl.wstrb;

assign slv_reg_wren = axi_wready && axi_ctrl.wvalid && axi_awready && axi_ctrl.awvalid;

always_ff @(posedge clk) begin
    if (reset_synced == 1'b0) begin
        pre_splitter_config.valid <= 1'b0;
    end else begin
        if (slv_reg_wren) begin
            pre_splitter_config.addr <= axi_awaddr[ADDR_LSB+:ADDR_MSB];
            for (int j = 0; j < N_WRT_STRB; j++) begin
                if (axi_ctrl.wstrb[j]) begin
                    pre_splitter_config.data[(j * 8)+:8] <= axi_ctrl.wdata[(j * 8)+:8];
                end else begin
                    pre_splitter_config.data[(j * 8)+:8] <= '0;
            end
        end
        pre_splitter_config.valid <= any_wstrb_valid;
    end else begin
        pre_splitter_config.valid <= '0;
    end
    end
end

ConfigSplitter #(
    .NUM_CONFIGS(NUM_CONFIGS),
    .ADDR_SPACE_BOUNDS(ADDR_SPACE_BOUNDS)
) inst_config_splitter (
    .clk(clk),
    .rst_n(rst_n),

    .in(pre_splitter_config),
    .out(internal_configs)
);

// Read process
assign slv_reg_rden = axi_arready & axi_ctrl.arvalid & ~axi_rvalid;

/*always_ff @(posedge clk) begin
  if(reset_synced == 1'b0) begin
    axi_rdata <= 0;
  end else begin
    if(slv_reg_rden) begin
      // All read registers are handled manually below.
      //
      // The reason is that:
      // 1. The number of read registers is very limited.
      // 2. If we where to handle them through slv_reg we would get multi-driver issues.
      //
      // Note: Only manual registers can be read registers atm.
      if (axi_araddr[ADDR_LSB+:ADDR_MSB] == REQUIRED_CYCLES_REG) begin
        axi_rdata <= required_cycles;
    `ifndef SYNTHESIS
      end else begin
        $display("DID NOT FIND A MATCH FOR READING FROM reg %d", axi_araddr[ADDR_LSB+:ADDR_MSB]);
    `endif
      end
    end
  end
end*/

// --------------------------------------------------------------------------------------
// AXI CTRL - Don't edit!
// --------------------------------------------------------------------------------------

// I/O
assign axi_ctrl.awready = axi_awready;
assign axi_ctrl.arready = axi_arready;
assign axi_ctrl.bresp = axi_bresp;
assign axi_ctrl.bvalid = axi_bvalid;
assign axi_ctrl.wready = axi_wready;
assign axi_ctrl.rdata = axi_rdata;
assign axi_ctrl.rresp = axi_rresp;
assign axi_ctrl.rvalid = axi_rvalid;

// awready and awaddr
always_ff @(posedge clk) begin
  if (reset_synced == 1'b0)
    begin
      axi_awready <= 1'b0;
      axi_awaddr <= 0;
      aw_en <= 1'b1;
    end
  else
    begin
      if (~axi_awready && axi_ctrl.awvalid && axi_ctrl.wvalid && aw_en)
        begin
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
          axi_awaddr <= axi_ctrl.awaddr;
        end
      else if (axi_ctrl.bready && axi_bvalid)
        begin
          aw_en <= 1'b1;
          axi_awready <= 1'b0;
        end
      else
        begin
          axi_awready <= 1'b0;
        end
    end
end

// arready and araddr
always_ff @(posedge clk) begin
  if (reset_synced == 1'b0)
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 0;
    end
  else
    begin
      if (~axi_arready && axi_ctrl.arvalid)
        begin
          axi_arready <= 1'b1;
          axi_araddr  <= axi_ctrl.araddr;
        end
      else
        begin
          axi_arready <= 1'b0;
        end
    end
end

// bvalid and bresp
always_ff @(posedge clk) begin
  if (reset_synced == 1'b0)
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end
  else
    begin
      if (axi_awready && axi_ctrl.awvalid && ~axi_bvalid && axi_wready && axi_ctrl.wvalid)
        begin
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0;
        end
      else
        begin
          if (axi_ctrl.bready && axi_bvalid)
            begin
              axi_bvalid <= 1'b0;
            end
        end
    end
end

// wready
always_ff @(posedge clk) begin
  if (reset_synced == 1'b0)
    begin
      axi_wready <= 1'b0;
    end
  else
    begin
      if (~axi_wready && axi_ctrl.wvalid && axi_ctrl.awvalid && aw_en )
        begin
          axi_wready <= 1'b1;
        end
      else
        begin
          axi_wready <= 1'b0;
        end
    end
end

// rvalid and rresp (1Del?)
always_ff @(posedge clk) begin
  if (reset_synced == 1'b0)
    begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end
  else
    begin
      if (axi_arready && axi_ctrl.arvalid && ~axi_rvalid)
        begin
          axi_rvalid <= 1'b1;
          axi_rresp  <= 2'b0;
        end
      else if (axi_rvalid && axi_ctrl.rready)
        begin
          axi_rvalid <= 1'b0;
        end
    end
end

endmodule
