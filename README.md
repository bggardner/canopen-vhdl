# canopen-vhdl
A lightweight CANopen controller in VHDL

`src/CanOpen_pkg.vhd` defines some standard CANopen values and record types for readability.

`src/CanOpenNode.vhd` contains a very simple CANopen slave device to be used as a template for creating more complex devices by adding additional objects and functions.  Heartbeat, expedited SDO, and four synchronous TPDOs are supported.

`src/CanOpenIndicators.vhd` contains a module that can convert the CANopen NMT State and CAN status signals into the appropriate CiA 303-3 indicator signals.

`test/CanOpenNode_tb.vhd` is a testbench that performs SDO, NMT, SYNC, and GFC commands on the simple CANopen slave device.
