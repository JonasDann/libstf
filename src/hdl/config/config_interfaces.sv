`timescale 1ns / 1ps

import libstf::*;

interface config_i;
    logic [AXI_ADDR_BITS - 1:0]  addr;
    logic [AXIL_DATA_BITS - 1:0] data;
    logic                        valid;

    // Tie off unused master signals
    task tie_off_m();
        valid = 0;
    endtask

    modport m (
        import tie_off_m,
        output addr, data, valid
    );

    modport s (
        input addr, data, valid
    );
endinterface

/**
 * Interface that bundles all stream configuration information.
 */
interface stream_config_i #(
    parameter NUM_SELECT
);
    typedef logic[$clog2(NUM_SELECT) - 1:0] select_t;

    ready_valid_i #(select_t) in_select();
    ready_valid_i #(select_t) out_select();
    ready_valid_i #(type_t)   data_type();
endinterface

/**
 * Interface that bundles all memory configuration information.
 */
interface mem_config_i;
    ready_valid_i #(buffer_t) buffer();
endinterface
