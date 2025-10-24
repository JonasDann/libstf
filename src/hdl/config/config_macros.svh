`ifndef LIBSTF_CONFIG_MACROS_SVH
`define LIBSTF_CONFIG_MACROS_SVH

`define CONFIG_WRITE_REGISTER(ADDRESS, DATA_TYPE, SIGNAL) \
ConfigWriteRegister #(                                    \
    .ADDR(ADDRESS),                                       \
    .TYPE(DATA_TYPE)                                      \
) inst_config_write_reg_`__LINE__ (                       \
    .clk(clk),                                            \
    .conf(conf),                                          \
    .data(SIGNAL)                                         \
);

`define CONFIG_WRITE_READY_REGISTER(ADDRESS, DATA_TYPE, SIGNAL) \
ConfigWriteReadyRegister #(                                     \
    .ADDR(ADDRESS),                                             \
    .TYPE(DATA_TYPE)                                            \
) inst_config_write_ready_reg_`__LINE__ (                       \
    .clk(clk),                                                  \
    .rst_n(rst_n),                                              \
    .conf(conf),                                                \
    .data(SIGNAL)                                               \
);

`define CONFIG_INTF_TO_SIGNALS(INTF, SIGNALS) \
    assign ``SIGNALS``_data  = INTF.data;     \
    assign ``SIGNALS``_valid = INTF.valid;    \
    assign INTF.ready    = ``SIGNALS``_ready;

`define CONFIG_SIGNALS_TO_INTF(SIGNALS, INTF) \
    assign INTF.data     = ``SIGNALS``_data;  \
    assign INTF.valid    = ``SIGNALS``_valid; \
    assign ``SIGNALS``_ready = INTF.ready;

`endif
