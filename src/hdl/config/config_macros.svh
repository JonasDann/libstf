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

`endif
