
/* -- Tie-off unused interfaces and signals ----------------------------- */
always_comb sq_rd.tie_off_m();
always_comb cq_rd.tie_off_s();

/* -- Top level components ----------------------- */

// -- Reset signal -----------------------------------------------------------------------
// Whether the reset signal should be triggered
logic trigger_reset;

// Separate reset driver that can drive the reset
// signal when the components finished processing 
logic component_reset;
reset_driver reset_driver (
    .clk(aclk),
    .trigger(trigger_reset),
    .reset_out(component_reset)
);

logic rst_n;
// Note: reset is active low so we will reset when any of the reset signals is driven
assign rst_n = aresetn & component_reset;

// -- Configuration ----------------------------------------------------------------------
// Configuration module
FILTER_CONFIG filter_config ();
PROJECT_CONFIG project_config ();
MEMORY_CONFIG memory_config ();
JOIN_CONFIG join_config ();

logic configuration_ready;
configuration configuration (
    .aclk(aclk),
    .aresetn(rst_n),
    .axi_ctrl(axi_ctrl),
    // Configuration values
    .configuration_ready(configuration_ready),
    .filter_conf(filter_config),
    .project_conf(project_config),
    .memory_conf(memory_config),
    .join_conf(join_config)
);

// Comment this out to debug the configuration values!
// `ifndef SYNTHESIS
// configuration_debug configuration_debug (
//     .clk(aclk),
//     .configuration_ready(configuration_ready),
//     .filter_conf(filter_config),
//     .project_conf(project_config),
//     .memory_conf(memory_config)
// );
// `endif

// -- Input streams --------------------------------------

// There are two problems we try to solve here:
// 1. Due to the multiplexing done in coyote, the path until here
//    is already quite long. Therefore, we add ready de-couplers before the signals
//    enter the operator pipeline.
// 2. We can only start processing the data once the configuration values
//    have successfully been written. Coyote does not make any guarantees
//    that data will only arrive after the configuration values.
//    Therefore, we need to ensure ourselves we do NOT start processing early.
AXI4SR #(.AXI4S_DATA_BITS(512)) input_streams [N_STRM_AXI] (.aclk(clk));
generate
    for (genvar stream = 0; stream < N_STRM_AXI; stream++) begin
        // 1. Decoupling
        AXI4SR #(.AXI4S_DATA_BITS(512)) de_couple_out (.aclk(clk));
        axi_ready_de_coupler de_coupler (
            .clk(aclk),
            .rst_n(rst_n),
            .input_stream(axis_host_recv[stream]),
            .output_stream(de_couple_out)
        );
        // 2. Only assign ready & valid when the configuration is ready
        assign input_streams[stream].tdata = de_couple_out.tdata;
        assign input_streams[stream].tkeep = de_couple_out.tkeep;
        assign input_streams[stream].tlast = de_couple_out.tlast;
        assign input_streams[stream].tvalid = de_couple_out.tvalid & configuration_ready;
        assign de_couple_out.tready = configuration_ready & input_streams[stream].tready;
    end
endgenerate

// -- Output writer --------------------------------------
OutputWriter inst_output_writer (
    .clk(aclk),
    .rst_n(rst_n),
    .sq_wr(sq_wr),
    .cq_wr(cq_wr),
    .notify(notify),
    .projection_enabled(project_config.mode == PROJECTION_ENABLED),
    .filter_mode_is_bitmask(filter_config.mode == BITMASK),
    .memory_conf(memory_config),
    // The streams enabled configuration is the same for all modules
    // -> We can take it from the projection
    .streams_enabled(project_config.stream_enabled),
    .join_probe_phase(join_config.mode == JOIN_PROBE),
    .configuration_ready(configuration_ready),
    .data_in(input_streams),
    .data_out(axis_host_send),
    .all_processing_done(trigger_reset)
);
