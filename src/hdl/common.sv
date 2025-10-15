`timescale 1ns / 1ps

package libstf;

typedef logic[7:0]  data8_t;
typedef logic[15:0] data16_t;
typedef logic[31:0] data32_t;
typedef logic[63:0] data64_t;

typedef enum logic {
    BIT32,
    BIT64
} type_width_t;

endpackage
