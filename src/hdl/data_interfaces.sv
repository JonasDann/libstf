interface valid_i #(
    parameter type data_t
);
    data_t data;
    logic  valid;

    modport m (
        output data, valid
    );

    modport s (
        input data, valid
    );

    task tie_off_s(); // Tie off unused slave signals
        valid = 1'b0;
    endtask
endinterface

interface ready_valid_i #(
    parameter type data_t
);
    data_t data;
    logic  valid;
    logic  ready;

    modport m (
        input  ready,
        output data, valid
    );

    modport s (
        input  data, valid,
        output ready
    );

    task tie_off_m(); // Tie off unused master signals
        ready = 1'b0;
    endtask

    task tie_off_s(); // Tie off unused slave signals
        valid = 1'b0;
    endtask
endinterface

interface data_i #(
    parameter type data_t
);
    data_t data;
    logic  keep;
    logic  last;
    logic  valid;
    logic  ready;

    modport m (
        input  ready,
        output data, keep, last, valid
    );

    modport s (
        input  data, keep, last, valid,
        output ready
    );
endinterface

interface ndata_i #(
    parameter type data_t,
    parameter NUM_ELEMENTS
);
    data_t[NUM_ELEMENTS - 1:0] data;
    logic[NUM_ELEMENTS - 1:0]  keep;
    logic                      last;
    logic                      valid;
    logic                      ready;

    modport m (
        input  ready,
        output data, keep, last, valid
    );

    modport s (
        input  data, keep, last, valid,
        output ready
    );
endinterface

interface tagged_i #(
    parameter type data_t,
    parameter TAG_WIDTH
);
    data_t                 data;
    logic[TAG_WIDTH - 1:0] tag;
    logic                  keep;
    logic                  last;
    logic                  valid;
    logic                  ready;

    modport m (
        input  ready,
        output data, tag, keep, last, valid
    );

    modport s (
        input  data, tag, keep, last, valid,
        output ready
    );
endinterface

interface ntagged_i #(
    parameter type data_t,
    parameter TAG_WIDTH,
    parameter NUM_ELEMENTS
);
    data_t[NUM_ELEMENTS - 1:0] data;
    logic[TAG_WIDTH - 1:0]     tag[NUM_ELEMENTS];
    logic[NUM_ELEMENTS - 1:0]  keep;
    logic                      last;
    logic                      valid;
    logic                      ready;

    modport m (
        input  ready,
        output data, tag, keep, last, valid
    );

    modport s (
        input  data, tag, keep, last, valid,
        output ready
    );
endinterface
