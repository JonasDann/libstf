from coyote_test import constants
from typing import List
from utils.fpga_compute import Int64Column, Column
from utils.db_operator_test_case import FPGADbOpsTestCase, FPGADbOpsPerformanceTestCaseWithOutputWriter
from utils.operators.filter import Greater_than_equal, And
from utils.memory_manager import FPGAOutputMemoryManager
from utils.operators.filter_configuration import (
    FilterMode,
    FPGAFilterConfiguration,
)

MAX_NUMBER_STREAMS = constants.MAX_NUMBER_STREAMS
TRANSFER_SIZE_BYTES_OVERWRITE = "TRANSFER_SIZE_BYTES_OVERWRITE"

class OutputWriterTest(FPGADbOpsTestCase):
    """
    Tests the behavior of the FPGA-initiated transfers
    """

    alternative_vfpga_top_file = "output_writer_test.sv"
    debug_mode = True
    verbose_logging = True

    def setUp(self):
        super().setUp()
        # All data in this test is streamed through.
        # There is no actual computation happening
        # (due to the way the wiring is done)
        self.columns: List[Column] = []

    def simulate_fpga(self):
        assert len(self.columns) > 0, "Cannot perform output test with 0 columns"

        # We build a filter expression from the columns.
        # The reason is that this give us the correct config for the reset!
        filters = []
        for column in self.columns:
            # Greater than equal to the minimum column element (keep all data)
            filters.append(
                Greater_than_equal(column, min(column.column_data(), default=0))
            )

        expression = And(*filters)

        # Write all the needed configurations
        configuration = FPGAFilterConfiguration.from_filter_expression(
            expression, FilterMode.FULL_MATERIALIZATION
        )
        for config in configuration.to_register_configuration():
            self.write_register(config)

        # Set the input & output
        for stream, column in enumerate(self.columns):
            self.set_stream_input(stream, column)
            self.set_expected_output(stream, column)

        super().simulate_fpga()

    def overwrite_memory_manager(self, allocation_size: int, transfer_size: int):
        """
        Overwrites the existing memory manager to have the new transfer & allocation size.
        Also sets those values for the simulation
        """
        self.memory_manager = FPGAOutputMemoryManager(
            self.get_io_writer(), allocation_size, transfer_size
        )
        self.set_system_verilog_defines(
            {TRANSFER_SIZE_BYTES_OVERWRITE: str(transfer_size)}
        )

    def test_with_one_data_beat_per_transfer(self):
        # Arrange
        allocation_size = 512
        transfer_size = 64
        total_data_bytes = 904
        self.overwrite_memory_manager(allocation_size, transfer_size)
        self.columns.append(
            Int64Column("numbers", list(range(0, total_data_bytes // 8)))
        )
        self.columns.append(
            Int64Column("numbers2", list(range(0, total_data_bytes // 8)))
        )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()

    def test_with_multiple_transfers_per_allocation(self):
        # Arrange
        allocation_size = 512
        transfer_size = 128
        total_data_bytes = 904
        self.overwrite_memory_manager(allocation_size, transfer_size)
        self.columns.append(
            Int64Column("numbers", list(range(0, total_data_bytes // 8)))
        )
        self.columns.append(
            Int64Column("numbers2", list(range(0, total_data_bytes // 8)))
        )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()

    def test_with_one_transfer_per_allocation(self):
        # Arrange
        allocation_size = 64
        transfer_size = 64
        total_data_bytes = 904
        self.overwrite_memory_manager(allocation_size, transfer_size)
        self.columns.append(
            Int64Column("numbers", list(range(0, total_data_bytes // 8)))
        )
        self.columns.append(
            Int64Column("numbers2", list(range(0, total_data_bytes // 8)))
        )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()

    def test_with_default_allocation_size(self):
        # Arrange
        total_data_bytes = 904
        self.columns.append(
            Int64Column("numbers2", list(range(0, total_data_bytes // 8)))
        )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()

    def test_with_half_data_beat_at_the_end(self):
        # Arrange
        allocation_size = 64
        transfer_size = 64
        total_data_bytes = 92
        self.overwrite_memory_manager(allocation_size, transfer_size)
        self.columns.append(
            Int64Column("numbers2", list(range(0, total_data_bytes // 8)))
        )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()

    def test_arbitration_full_streams(self):
        # Arrange
        allocation_size = 256
        transfer_size = 64
        total_data_bytes = 4000
        self.overwrite_memory_manager(allocation_size, transfer_size)
        for column in range(0, MAX_NUMBER_STREAMS):
            self.columns.append(
                Int64Column(f"numbers{column}", list(range(0, total_data_bytes // 8)))
            )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()

    def test_very_large_input(self):
        # Arrange
        allocation_size = 3 * 4096
        transfer_size = 4096
        total_data_bytes = 4096 * 10
        self.overwrite_memory_manager(allocation_size, transfer_size)
        self.columns.append(
            Int64Column("numbers", list(range(0, total_data_bytes // 8)))
        )

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()


class OutputWriterPerformanceTest(FPGADbOpsPerformanceTestCaseWithOutputWriter):
    """
    Tests the performance of the FPGA-initiated transfers
    """
    alternative_vfpga_top_file = "output_writer_test.sv"
    debug_mode = True
    verbose_logging = True

    def setUp(self):
        super().setUp()
        # All data in this test is streamed through.
        # There is no actual computation happening
        # (due to the way the wiring is done)
        self.columns: List[Column] = []

    def simulate_fpga(self):
        assert len(self.columns) > 0, "Cannot perform output test with 0 columns"

        # We build a filter expression from the columns.
        # The reason is that this give us the correct config for the reset!
        filters = []
        for column in self.columns:
            # Greater than equal to the minimum column element (keep all data)
            filters.append(
                Greater_than_equal(column, min(column.column_data(), default=0))
            )

        expression = And(*filters)

        # Write all the needed configurations
        configuration = FPGAFilterConfiguration.from_filter_expression(
            expression, FilterMode.FULL_MATERIALIZATION
        )


        # Write the needed registers
        for config in configuration.to_register_configuration():
            self.write_register(config)

        # Add a short sleep to ensure the registers finish writing before any
        # stream data is sent!
        self.get_io_writer().sleep(100)

        # Set the input & output
        for stream, column in enumerate(self.columns):
            self.set_stream_input(stream, column)
            self.set_expected_output(stream, column)

        super().simulate_fpga()

    def test_streaming_through_performance(self):
        # Arrange
        total_data_bytes = 2000
        for column in range(0, MAX_NUMBER_STREAMS):
            self.columns.append(
                Int64Column(f"numbers{column}", list(range(0, total_data_bytes // 8)))
            )
        self.set_expected_avg_cycles_per_batch_for_all_streams(1.0)

        # Act
        self.simulate_fpga()

        # Assert
        self.assert_simulation_output()
        self.assert_expected_performance()