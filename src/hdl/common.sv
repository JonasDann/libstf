`timescale 1ns / 1ps

package libstf;

import lynxTypes::*;

// The maximum size per host allocation that is supported by the design. (2**28 - 1 = 256 MiB - 1 byte)
// This limitation comes from the 32 bits we have available for interrupt values.
// See output_writer for more info.
localparam integer MAXIMUM_HOST_ALLOCATION_LEN_BIT = 28;

typedef logic[7:0]  data8_t;
typedef logic[15:0] data16_t;
typedef logic[31:0] data32_t;
typedef logic[63:0] data64_t;

typedef enum logic {
    UINT32_T,
    UINT64_T,
    DOUBLE
} type_t;

typedef logic[VADDR_BITS - 1:0] vaddr_t;
typedef logic[MAXIMUM_HOST_ALLOCATION_LEN_BIT - 1:0] alloc_size_t;

typedef struct packed {
    vaddr_t      vaddr;
    alloc_size_t size;
} buffer_t;

endpackage
