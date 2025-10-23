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

typedef logic[VADDR_BITS - 1:0] vaddress_t; // Cannot be vaddr_t because of conflict with Coyote sim
typedef logic[MAXIMUM_HOST_ALLOCATION_LEN_BIT - 1:0] alloc_size_t;

typedef struct packed {
    vaddress_t   vaddr;
    alloc_size_t size;
} buffer_t;

typedef enum logic[1:0] {
    UINT32_T,
    UINT64_T,
    DOUBLE
} type_t;

// Constant function to return the bit width of type_t types
function automatic int GET_TYPE_WIDTH(type_t data_type);
    case (data_type)
        UINT32_T: begin
            return 32;
        end
        UINT64_T, DOUBLE: begin
            return 64;
        end
        default: begin
            `ifndef SYNTHESIS
            $display("ERROR: UNKNOWN data type %d", data_type);
            `endif
            return 0;
        end
    endcase
endfunction

endpackage
