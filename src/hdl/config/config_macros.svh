`ifndef LIBSTF_CONFIG_MACROS_SVH
`define LIBSTF_CONFIG_MACROS_SVH

`define CONFIG_WRITE_REGISTER(ADDR, TYPE, SIGNAL) \
ConfigWriteRegister inst_config_write_register #( \
    .ADDR(ADDR),                                  \
    .TYPE(TYPE),                                  \
) (                                               \
    .clk(clk),                                    \
    .conf(conf),                                  \
    .data(SIGNAL)                                 \
);

`endif
