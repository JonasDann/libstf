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

    `READY_VALID_SIGNALS(select_t, select)
    `READY_VALID_SIGNALS(type_t,   data_type)

    modport m (
        output select_data, select_valid, data_type_data, data_type_valid,
        input select_ready, data_type_ready
    );

    modport s (
        output select_ready, data_type_ready,
        input select_data, select_valid, data_type_data, data_type_valid
    );
endinterface

/**
 * Interface that bundles all memory configuration information.
 */
interface mem_config_i;
    `READY_VALID_SIGNALS(buffer_t, buffer)

    modport m (
        output buffer_data, buffer_valid,
        input buffer_ready
    );

    modport s (
        output buffer_ready,
        input buffer_data, buffer_valid
    );
endinterface
