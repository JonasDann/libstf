`ifndef LIBSTF_LIBSTF_MACROS_SVH
`define LIBSTF_LIBSTF_MACROS_SVH

// This macro assumes that the clock and reset signals are clk and rst_n, respectively.
`define RESET_RESYNC            \
logic reset_synced;             \
ResetResync inst_reset_resync ( \
    .clk(clk),                  \
    .reset_in(rst_n),           \
    .reset_out(reset_synced)    \
);

`define ASSERT_ELAB(COND) if (!(COND)) $error("Assertion failed.");

`define DATA_ASSIGN(s, m).        \
	assign m.data      = s.data;  \
	assign m.keep      = s.keep;  \
	assign m.last      = s.last;  \
	assign m.valid     = s.valid; \
	assign s.ready     = m.ready;

`endif
