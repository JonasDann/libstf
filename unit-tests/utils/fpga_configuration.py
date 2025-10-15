from enum import Enum
from coyote_test import constants, fpga_register
from typing import List, Union
from utils.fpga_compute import Column
from utils.common import INTERRUPT_TRANSFER_SIZE_BITS


class ExtendedEnum(Enum):
    @classmethod
    def list(cls):
        return list(map(lambda c: c.value, cls))

    @classmethod
    def max_value(cls):
        return max([elem for elem in cls.list()])


class NamedFPGAConfiguration(ExtendedEnum):
    # Configurations who's ID is explicitly defined in src/hdl/configuration.sv
    CONFIGURATION_READY = 0
    FILTER_MODE = 1
    STREAM_CONFIGURATION = 2
    PROJECTION_MODE = 3
    REQUIRED_CYCLES = 4
    JOIN_MODE = 5


# Our own extension of the FPGAConfiguration class that also accepts named configurations
class DBConfiguration(fpga_register.vFPGARegister):
    def __init__(
        self, id: Union[NamedFPGAConfiguration, int], value: Union[bool, bytearray]
    ):
        assert isinstance(id, int) or isinstance(id, NamedFPGAConfiguration)
        super().__init__(id if isinstance(id, int) else id.value, value)


# Most general configuration class
# Configures which stream is valid and the stream types
# -> Is extended by configurations for specific operators like filter or projection
class FPGAStreamConfiguration:
    def __init__(self):
        self.columns: List[Column] = [None] * constants.MAX_NUMBER_STREAMS

    def set_column_for_stream(self, stream: int, column: Column):
        """
        Sets the column type for the given stream
        """
        assert stream < constants.MAX_NUMBER_STREAMS
        if self.columns[stream] is None:
            self.columns[stream] = column
        else:
            raise ValueError(f"Stream {stream} already got a column")

    def stream_has_column(self, stream: int):
        assert stream < constants.MAX_NUMBER_STREAMS
        return self.columns[stream] is not None

    def get_column_for_stream(self, stream: int) -> Column:
        assert stream < constants.MAX_NUMBER_STREAMS
        return self.columns[stream]

    def get_columns_for_streams(self) -> List[Column]:
        """
        Returns a list of columns in the order of the streams they will be assigned to.
        Caution: Columns will be None if no input is assigned to them
        """
        # We ensure the columns of all of operators are the same
        return self.columns

    def to_register_configuration(self) -> List[DBConfiguration]:
        # The stream configuration happens in exactly one register value (8 bytes)
        config = bytearray()
        assert len(self.columns) <= 7, (
            "The STREAM configuration does not support more than 7 columns "
            + "since only one register value is used for the configuration"
        )

        # First byte: Whether there is data on that stream is enabled
        enabled = 0
        for i, column in enumerate(self.columns):
            if column is not None:
                enabled += 1 << i
        config.append(enabled)

        # Second byte = Column type (INT32, DOUBLE, etc.)
        for column in self.columns:
            if column is not None:
                config.append(column.column_type().value)
            else:
                # Default value
                config.append(0)

        return [DBConfiguration(NamedFPGAConfiguration.STREAM_CONFIGURATION, config)]

    def finalize_register_configuration(
        self, config: List[DBConfiguration]
    ) -> List[DBConfiguration]:
        """
        Ensures the configuration has all the needed values to be correct.
        Should be called by sub-classes once their configuration values have been set.
        """
        # It is VERY important that the last register is the one that sets the whole configuration
        # to be ready. This ensures configuration values are written BEFORE any data is processed.
        return config + [
            DBConfiguration(NamedFPGAConfiguration.CONFIGURATION_READY, bytearray([1]))
        ]


# First register that is not 'named' and can be used.
FIRST_FREE_REGISTER = NamedFPGAConfiguration.max_value() + 1
FIRST_MEM_SIZE_REG = FIRST_FREE_REGISTER + constants.MAX_NUMBER_STREAMS
FIRST_FREE_REGISTER_AFTER_MEM = FIRST_MEM_SIZE_REG + constants.MAX_NUMBER_STREAMS


class FPGAMemoryConfiguration:
    # Static property to manage the id
    ids_for_streams = {}

    def __init__(self, stream_id: int, vaddr: int, size: int):
        """
        Creates a new configuration, which tells the FPGA to use
        the memory region starting from vaddr and over size bytes
        to send the output of stream with id stream_id
        """
        self.stream_id = stream_id
        self.vaddr = vaddr
        self.size = size
        self.id = self.get_next_id_for_stream(stream_id)

    @staticmethod
    def reset() -> None:
        FPGAMemoryConfiguration.ids_for_streams = {}

    @staticmethod
    def oscillate_id(stream_id: int) -> int:
        FPGAMemoryConfiguration.ids_for_streams[stream_id] = (
            0 if FPGAMemoryConfiguration.ids_for_streams[stream_id] == 1 else 1
        )

    @staticmethod
    def get_next_id_for_stream(stream_id: int) -> int:
        """
        In the FPGA design we somehow need to be able to determine
        if a vaddr and size is valid/if they have been updated.
        For this reason, we pass a 1-bit id after the actual data.

        This id is supposed to oscillate between 1 and 0, starting
        with 1, allowing us to determine if there has been an update
        to this data!
        """
        if stream_id not in FPGAMemoryConfiguration.ids_for_streams:
            # Initialize
            FPGAMemoryConfiguration.ids_for_streams[stream_id] = 1

        # Get current id, update it to the next one and return
        current_id = FPGAMemoryConfiguration.ids_for_streams[stream_id]
        FPGAMemoryConfiguration.oscillate_id(stream_id)
        return current_id

    def _to_bytearray_with_id(self, size: int, value: int, id: int):
        """
        Ensures the value fits into size bits.
        Then, the id is prepended. Finally, the whole value
        will be converted to a bytearray with 8 bytes.
        """
        assert value <= pow(2, size) - 1, (
            f"Value {value} was out of range for the target of {size} bits"
        )
        new_value = value + (id << size)
        return bytearray(new_value.to_bytes(8, constants.BYTE_ORDER))

    def to_register_configuration(self) -> List[DBConfiguration]:
        # Determine the id of the register
        vaddr_reg_id = FIRST_FREE_REGISTER + self.stream_id
        size_reg_id = FIRST_MEM_SIZE_REG + self.stream_id

        return [
            DBConfiguration(
                vaddr_reg_id,
                self._to_bytearray_with_id(constants.VADDR_BITS, self.vaddr, self.id),
            ),
            DBConfiguration(
                size_reg_id,
                self._to_bytearray_with_id(
                    INTERRUPT_TRANSFER_SIZE_BITS, self.size, self.id
                ),
            ),
        ]
