# canopen-vhdl
A lightweight CANopen controller in VHDL.

## eds2vhdl.py
Generates a VHDL file from a CANopen Electronic Data Sheet (EDS).  `eds2vhdl.py -h` for usage.  Requires at least Python 3.12.

### Names and Ports

The entity name is derived from ProductName key of the DeviceInfo section
Signal and constant names are derived from the ParameterName key
All names are scrubbed to be VHDL compatible and follow the NASA style guide

The index number and AccessType key of each object determine how the object is parsed:
* Below 0x2000: (communication objects)
    * const: Declared as `constant`, unless the mux is specified as a --port argument, then it is an `in` port signal
    * others: Declared as internal "signal"
* 0x2000 and above: (application objects)
    * const: Declared as "constant"
    * ro: Declared as `in` port signal
    * rw: Declared as `out` port signal with output buffer for reading internally
    * wo: Declared as `out` port signal with additional `out` port signal suffixed with `_strb` (strobe) of type std_logic that is pulsed high during SDO download

### Data Types

All data types must be explicitly defined in the EDS.  No data type validation to CiA301 is performed.
Data type lengths of 1-32 support "const", "ro", and "rw" access
Data type lengths of 0 (undefined) and greater than 32 support "ro" upload via Segmented SDO interface (see below)


### Supported communication objects

| Index | Object name | Limitations |
| ----- | ----------- | ----------- |
| 0x1000 | Device type
| 0x1001 | Error register              | or'd with ErrorRegister `in` port |
| 0x1002 | Manufacturer status register | always `in` port |
| 0x1005 | COB-ID SYNC                 | |
| 0x1006 | Communication cycle period  | |
| 0x1007 | Synchronous window length   | Ineffective, no EMCY |
| 0x1012 | COB-ID TIME                 | consumer only |
| 0x1014 | COB-ID EMCY                 | producer only, mostly generic EECs only, no MSEFs, reset error EMCY write only when no errors |
| 0x1016 | Consumer heartbeat time     | No SDO abort on duplicate Node-IDs |
| 0x1017 | Producer heartbeat time     | |
| 0x1018 | Identity object             | |
| 0x1019 | Synchronous counter overflow value | No EMCY on data length mismatch, no SDO abort if 0x1006 is not zero |
| 0x1021 | Store EDS                   | Uses Segmented SDO interface |
| 0x1022 | Store format                | |
| 0x1029 | Error behavior              | sub-indices 0x00-0x02 only, error class values 0x00-0x02 only |
| 0x1200 | Server SDO paramter         | mandatory entries only, expedited download only, supports block upload PSTs <= 4 |
| 0x1800 | TPDO1 comm. parameter       | |
| 0x1801 | TPDO2 comm. parameter       | |
| 0x1802 | TPDO3 comm. parameter       | |
| 0x1803 | TPDO4 comm. parameter       | |
| 0x1A00 | TPDO1 mapping parameter     | const or read-only |
| 0x1A01 | TPDO2 mapping parameter     | const or read-only |
| 0x1A02 | TPDO3 mapping parameter     | const or read-only |
| 0x1A03 | TPDO4 mapping parameter     | const or read-only |
| 0x1F80 | NMT Startup                 | bit 3 (self-starting) only

### ErrorRegister
Low-to-high bit transitions perform EMCY write with CanOpen.EMCY_EEC_GENERIC; to-all-zeroes transition performs EMCY write with CanOpen.EMCY_EEC_NO_ERROR

### Segmented SDO interface
For transferring DOMAIN data via segmented (normal or block). All signals are synchronous to Clock.

| Port | Direction | Data type | FIFO Equivalent | Description |
| ---- | --------- | --------- | --------------- | ----------- |
| `SegmentedSdoMux`             | `out` | `std_logic_vector(23 downto 0)` | Address | Concatenation of object dictionary index and subindex. Ex: 0x101801 for Identity object, Vendor-ID |
| `SegmentedSdoReadEnable`      | `out` | `std_logic`                     | Enable | Start/!stop: Asserted high during entire data transfer, deasserted when finished or aborted |
| `SegmentedSdoDataReadEnable`  | `out` | `std_logic`                     | Full | Ready/!Ack: Asserted high until one clock cycle after `SegmentedSdoDataValid = '1'` |
| `SegmentedSdoData`            | `in`  | `std_logic_vector(55 downto 0)` | Data | Initially data size (32-bit max), in bytes, from when `SegmentedSdoReadEnable = '1'` to first `SegmentedSdoDataReadEnable = '1'`, then segment data with LSB first |
| `SegmentedSdoDataValid`       | `in`  | `std_logic`                     | WriteEnable | Asserted when SegmentedSdoData is valid, deasserted when `SegmentedSdoReadValid = '0'` or `SegmentedSdoReadEnable = '0'` |

#### Timing diagram:
```
Clock                      _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯···_|¯|_|¯|_

                                __________________________________   ______
SegmentedSdoMux            XXXXX                                  ···      XXX
                                ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯   ¯¯¯¯¯¯

SegmentedSdoReadEnable     _____|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯···¯¯¯¯¯|___


SegmentedSdoReadDataEnable _____________|¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|___|¯···¯¯¯¯¯|___

                                 _______ ________    ________    _   ______
SegmentedSdoData           XXXXXX size  X   D0   XXXX   D1   XXXX ··· DN   XXX
                                 ¯¯¯¯¯¯¯ ¯¯¯¯¯¯¯¯    ¯¯¯¯¯¯¯¯    ¯   ¯¯¯¯¯¯

SegmentedSdoDataValid      _________________|¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|_···¯¯¯¯¯|___
```

## Other Files

`eds2mem.py` generates a memory file (MEM) from an EDS (or any other) file to be loaded into RAM/ROM, specifically for use with CANopen DOMAIN objects (such as 0x1021: Store EDS) accessed via segmented SDO.  `eds2mem.py -h` for usage.

`src/CanOpen_pkg.vhd` defines standard CANopen constants and record types, as well as helper functions.  Required.

`src/CanOpenIndicators.vhd` contains a module that can convert the CANopen NMT State and CAN status signals into the appropriate CiA 303-3 indicator signals.

`src/SegmentedSdo*.vhd` interface adapters between the Segmented SDO interface (above) and various memory configurations (RAM, ROM, etc.).

