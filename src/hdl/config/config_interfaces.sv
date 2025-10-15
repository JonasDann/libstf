`timescale 1ns / 1ps

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
