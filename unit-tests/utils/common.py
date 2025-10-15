import math
from coyote_test import constants

#
# Filter
#

FILTER_OPS_PER_STREAM = 3
# The number of rhs needed for each operator
FILTER_RHS_PER_OP = 2
# The maximum number of ADDITIONAL RHS we support per layer
FILTER_ADDITIONAL_RHS_PER_LAYER = 6

#
# FPGA-initiated transfers
#
MEMORY_BYTES_PER_FPGA_TRANSFER = 65536

# The interrupt value has 32 bits.
# We need 3 bits for the stream indicator and 1 bit for the last signal.
# This leaves 28 bits for the maximum output size per allocation.
INTERRUPT_STREAM_ID_BITS = 3
INTERRUPT_TRANSFER_SIZE_BITS = 28
INTERRUPT_LAST_BITS = 1
MAXIMUM_HOST_MEMORY_ALLOCATION_SIZE_BYTES = pow(2, INTERRUPT_TRANSFER_SIZE_BITS) - 1

# Due to the interrupt stream indicator, the maximum number of
# supported streams with FPGA transfers is limited
MAX_SUPPORTED_N_STREAMS = pow(2, INTERRUPT_STREAM_ID_BITS)

#
# Projections
#

# The number of streams supported in the PROJECTION
# This value needs to match the configuration in src/hdl/common.sv
# All other values below are automatically inferred.
PROJECTION_MAX_N_STREAMS = 4
PROJECTION_N_CONST_POSITION_REGISTER = 1
# The number of constants supported (1 per stream)
# Constant and literal are used synonymous
PROJECTION_NUMBER_OF_CONSTANTS = PROJECTION_MAX_N_STREAMS
# In the projection tree, for every stream there exists another leaf with a literal.
# The first layer from the bottom only combines each stream with a (optional) literal.
# -> There is the default operation IDENTITY which leads to no op.
# -> The tree has twice as meany leaves as it can consume streams since half of the leaves are literals.
PROJECTION_N_LEAVES = PROJECTION_MAX_N_STREAMS * 2
# The number of nodes in the binary projection tree (known formula for tree size from leaf size)
PROJECTION_NODES_FULL_TREE = PROJECTION_N_LEAVES * 2 - 1
# The number of operators that the projection tree needs to support
# -> Number of nodes in the tree without the additional layer for literals
PROJECTION_NUMBER_OF_OPERATORS = PROJECTION_MAX_N_STREAMS * 2 - 1
# The height of the full binary projection tree
PROJECTION_HEIGHT_FULL_TREE = math.floor(math.log2(PROJECTION_NODES_FULL_TREE))

#
# Joins
#
JOIN_BUILD_AND_PROBE_INPUT_STREAM_ID = PROJECTION_MAX_N_STREAMS

#
# Assertions 
#
assert constants.MAX_NUMBER_STREAMS % 2 == 0, "The number of streams needs to be divisible by two for the design to work!"
assert FILTER_OPS_PER_STREAM >= 2, "The number of filter operations per stream need to be at least 2 for the design to work!"
assert PROJECTION_MAX_N_STREAMS <= constants.MAX_NUMBER_STREAMS, "Projection cannot support more streams than there are"
assert PROJECTION_MAX_N_STREAMS <= 64, \
    "Projection can at most run on 64 streams because this is the size in bits of the projection " + \
    "constants position register. To support larger sizes, additional register need to be introduced."
assert MEMORY_BYTES_PER_FPGA_TRANSFER % 64 == 0, "The bytes per FPGA initiated transfer need to be a multiple of the AXI data beat size!"
assert constants.MAX_NUMBER_STREAMS <= MAX_SUPPORTED_N_STREAMS, (
    "Due to limitations in the FPGA-initiated transfers, we can currently support " + 
    f"at most {MAX_SUPPORTED_N_STREAMS} streams. Configuration had " + 
    f"{constants.MAX_NUMBER_STREAMS} streams"
)
assert INTERRUPT_STREAM_ID_BITS + INTERRUPT_TRANSFER_SIZE_BITS + INTERRUPT_LAST_BITS <= 32, (
    "The sum of all the bits in the interrupt value cannot be larger "
    + "than the available data size of 32 bit."
)