# canopen-vhdl
A lightweight CANopen controller in VHDL

## eds2vhdl.py
Generates a VHDL file from a CANopen Electronic Data Sheet (EDS).  `eds2vhdl.py -h` for usage.

### Names and Ports

The entity name is derived from ProductName key of the DeviceInfo section
Signal and constant names are derived from the ParameterName key
All names are scrubbed to be VHDL compatible and follow the NASA style guide

The index number and AccessType key of each object determine how the object is parsed:
*Below 0x2000: (communication objects)
    *const: Declared as "constant", unless the mux is specified as a --port argument, then it is an "in" port signal
    *others: Declared as internal "signal"
*0x2000 and above: (application objects)
    *const: Declared as "constant" (maybe could be "generic"?)
    *ro: Declared as "in" port signal
    *rw: Declared as "out" port signal with output buffer for reading internally
    *wo: Declared as "out" port signal with additional "out" port signal "_strb" of type std_logic that is pulsed high during SDO download

### Data Types

All data types must be explicitly defined in the EDS.  No data type validation to CiA301 is performed.
Data type lengths of 1-32 support "const", "ro", and "rw" access
Data type lengths of 0 (undefined) and greater than 32 support "ro" access via Segmented SDO interface (see below)


### Supported communication objects

| Index | Object name | Limitations |
| ----- | ----------- | ----------- |
| 0x1000  | Device type
| 0x1001  | Error register              | OR'd with ErrorRegister (in) port |
| 0x1005  | COB-ID SYNC                 | consumer only, 11-bit CAN-ID only |
| 0x1012  | COB-ID TIME                 | consumer only, 11-bit CAN-ID only |
| 0x1014  | COB-ID EMCY                 | producer only, 11-bit CAN-ID only, generic EECs only, no MSEFs, reset error EMCY write only when no errors |
| 0x1016  | Consumer heartbeat time     | one consumer only |
| 0x1017  | Producer heartbeat time     | |
| 0x1018  | Identity object             | |
| 0x1021  | Store EDS                   | Uses Segmented SDO interface |
| 0x1022  | Store format                | |
| 0x1029  | Error behavior              | sub-indices 0x00-0x02 only, error class values 0x00-0x02 only |
| 0x1200  | Server SDO paramter         | mandatory entries only, 11-bit CAN-ID only, expedited download only, supports block upload PSTs <= 4 |
| 0x1800  | TPDO1 comm. parameter       | mandatory entries only, 11-bit CAN-ID only |
| 0x1801  | TPDO2 comm. parameter       | mandatory entries only, 11-bit CAN-ID only |
| 0x1802  | TPDO3 comm. parameter       | mandatory entries only, 11-bit CAN-ID only |
| 0x1803  | TPDO4 comm. parameter       | mandatory entries only, 11-bit CAN-ID only |
| 0x1A00  | TPDO1 mapping parameter     | const or read-only |
| 0x1A01  | TPDO2 mapping parameter     | const or read-only |
| 0x1A02  | TPDO3 mapping parameter     | const or read-only |
| 0x1A03  | TPDO4 mapping parameter     | const or read-only |
| 0x1F80  | NMT Startup                 | bit 3 (self-starting) only

### ErrorRegister
Low-to-high bit transitions perform EMCY write with CanOpen.EMCY_EEC_GENERIC; to-all-zeroes transition performs EMCY write with CanOpen.EMCY_EEC_NO_ERROR

### Segmented SDO interface
For transferring DOMAIN data via segmented (normal or block). All signals are synchronous to Clock.

| Port | Direction | Data type | Description |
| ---- | --------- | --------- | ----------- |
| SegmentedSdoMux             | out | std_logic_vector(23 downto 0) | Concatenation of object dictionary index and subindex. Ex: 0x101801 for Identify object, Vendor-ID |
| SegmentedSdoReadEnable      | out | std_logic                     | Start/!stop: Asserted high during entire data transfer, deasserted when finished or aborted |
| SegmentedSdoDataReadEnable  | out | std_logic                     | Ready/!Ack: Asserted high until SegmentedSdoDataValid = '1', deasserted when SegmentedSdoDataValid = '1' |
| SegmentedSdoData            | in  | std_logic_vector(55 downto 0) | Data size (32-bit max), in bytes, from when SegmentedSdoReadEnable = '1' to first subsequent SegmentedSdoDataReadEnable = '1', then segment data with LSB first |
| SegmentedSdoDataValid       | in  | std_logic                     | Asserted when SegmentedSdoData is valid, deasserted when SegmentedSdoReadValid = '0' or SegmentedSdoReadEnable = '0' |

#### Timing diagram:
```
Clock                      _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯···|_|¯|_|¯|_|¯

                             ______________________________________   ______
SegmentedSdoMux            XXXXX                                      ···      XXXXXX
                             ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯   ¯¯¯¯¯¯

SegmentedSdoReadEnable     _____|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯···¯¯¯¯¯¯|_____


SegmentedSdoReadDataEnable _________________|¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|___|¯···¯¯¯¯¯¯|_____

                                 ___________ ________    ________       ________
SegmentedSdoData           XXXXXXXXX   size    X   D0   XXXX   D1   XX···XX   DN   XX
                                 ¯¯¯¯¯¯¯¯¯¯¯ ¯¯¯¯¯¯¯¯    ¯¯¯¯¯¯¯¯       ¯¯¯¯¯¯¯¯

SegmentedSdoDataValid      _____________________|¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|_···__|¯¯¯¯¯¯¯|_
```

## Other Files

`src/CanOpen_pkg.vhd` defines some standard CANopen values and record types for readability as well as helper functions.  Required.

`src/CanOpenIndicators.vhd` contains a module that can convert the CANopen NMT State and CAN status signals into the appropriate CiA 303-3 indicator signals.

`test/CanOpenNode_tb.vhd` is a testbench that performs SDO, NMT, SYNC, and GFC commands on the simple CANopen slave device.

`eds2mem.py` generates a memory file (MEM) from an EDS (or any other) file to be loaded into RAM/ROM, specifically for use with CANopen DOMAIN objects (such as 0x1021: Store EDS) accessed via segmented SDO.  `eds2mem.py -h` for usage.
