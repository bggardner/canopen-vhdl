# canopen-vhdl
A lightweight CANopen controller in VHDL

`src/CanOpen_pkg.vhd` defines some standard CANopen values and records for readability.

`src/CanOpenNode.vhd` contains a very simple CANopen slave device to be used as a starting point for creating more complex devices by adding additional objects and functions.

`src/CanOpenIndicators.vhd` contains a module that can convert the CANopen NMT State and CAN status signals into the appropriate CiA 303-3 indicator signals.

`test/CanOpenNode_tb.vhd` is a simple testbench that performs an SDO request on the simple CANopen slave device.
