#!/usr/bin/python3
"""Generates a VHDL entity from CiA306-1 compliant EDS file

Run eds2vhdl.py -h for usage
"""
import argparse
from configparser import ConfigParser
import math
import re
from sys import argv

parser = argparse.ArgumentParser()
parser.add_argument("eds", type=str, help="EDS file")
parser.add_argument("--sync", nargs="?", const=True, default=False, type=bool, help="Adds output signal for single-clock pulse when SYNC is received")
parser.add_argument("--gfc", nargs="?", const=True, default=False, type=bool, help="Adds output signal for single-clock pulse when GFC is received")
parser.add_argument("--timestamp", nargs="?", const=True, default=False, type=bool, help="Adds output signal for TIME object")
parser.add_argument("--port", nargs="+", action="extend", type=lambda x: int(x, 0), default=[], help="Object dictionary multiplexers to expose as in ports (0x101804, e.g.)")
args = parser.parse_args()

def format_constant(name, **kwargs):
    name = name.upper()
    name = name.replace(" ", "_")
    name = re.sub(r"\b-\b", "_", name) # Replace hyphenated words with underscore
    name = re.sub("[^\w]", "", name) # Remove illegal characters
    name = re.sub("_{1,}", "_", name) # Remove multiple underscores
    if re.match("[\d_]", name) is not None:
        raise ValueException("Invalid object name '" + name + "'. Must start with a letter.")
    if "prefix" in kwargs:
        prefix = kwargs["prefix"]
    else:
        prefix = "\\"
    if "suffix" in kwargs:
        suffix = kwargs["suffix"]
    else:
        suffix = "\\"
    return prefix + name + suffix


def make_object_from_data_type(odi):
    odi = int(odi, 0)
    o = {}
    if odi == 0x0001: # BOOLEAN
        o["bit_length"] = 1
        o["data_type"] = "std_logic"
    elif odi in [
        0x0002, # INTEGER8
        0x0003, # INTEGER16
        0x0004, # INTEGER32
        ]:
        o["bit_length"] = 2 ** (odi + 1)
        o["data_type"] = "signed({:d} downto 0)".format(o.get("bit_length") - 1)
    elif odi in [
        0x0005, # UNSIGNED8
        0x0006, # UNSIGNED16
        0x0007  # UNSIGNED32
        ]:
        o["bit_length"] = 2 ** (odi - 2)
        o["data_type"] = "unsigned({:d} downto 0)".format(o.get("bit_length") - 1)
    elif odi in [
        0x000C, # TIME_OF_DAY
        0x000D  # TIME_DIFFERENCE
        ]:
        o["bit_length"] = 48
        o["data_type"] = "CanOpen.TimeOfDay"
    elif odi == 0x000F: # DOMAIN
        o["bit_length"] = 0 # variable, per CiA 301 section 7.4.7.1
        o["data_type"] = "unsigned(31 downto 0)" # placeholder
    else:
        raise TypeError("Unsupported data type with index 0x{:04X}".format(odi))
    return o


def format_signal(name, **kwargs):
    name = format_constant(name, **{"prefix": "", "suffix": ""})
    if "prefix" in kwargs:
        prefix = kwargs["prefix"]
    else:
        prefix = "\\"
    if "suffix" in kwargs:
        suffix = kwargs["suffix"]
    else:
        suffix = "\\"
    name = "".join(map(str.capitalize, name.split("_")))
    return prefix + name + suffix


def format_value(value, bit_length):
    s = ""
    x = bit_length // 4
    b = bit_length - (x * 4)
    if b > 0:
        s += ('b"{:0' + "{}".format(b) + 'b}"').format(value >> (x * 4)) # Will not truncate if value >= 2**bit_length
        if x > 0:
            s += " & "
    if x > 0:
        s += ('x"{:0' + "{}".format(x) + 'X}"').format(value & (2**(x * 4) - 1))
    return s


def make_object(o):
    obj = make_object_from_data_type(o.get("datatype"))
    obj["parameter_name"] = o.get("parametername")
    obj["access_type"] = o.get("accesstype")
    name = obj.get("parameter_name")
    default_value = o.get("defaultvalue")
    bit_length = obj.get("bit_length")
    if obj.get("access_type") =="const":
        obj["name"] = format_constant(name)
        default_value = int(default_value, 0)
        obj["default_value"] = format_value(default_value, bit_length)
    elif default_value is not None:
        obj["name"] = format_signal(name)
        if default_value.startswith("$NODEID+"):
            obj["default_value"] = " & std_logic_vector(NodeId_q)" # TODO: fix zero_pad here
            default_value = int(default_value[8:], 0)
            if default_value & 0x7F:
                  raise ValueError("Default value for '" + o.get("parametername") + "' unsupported")
            default_value >>= 7
            bit_length -= 7
        else:
            default_value = int(default_value, 0)
        obj["default_value"] = format_value(default_value, bit_length) + obj.get("default_value", "")
    else:
        obj["name"] = format_signal(name)
    if default_value is not None and not obj.get("data_type").startswith("std_logic") and obj.get("default_value").endswith("std_logic_vector(NodeId_q)"):
        obj["default_value"] = obj.get("data_type")[:obj.get("data_type").index("(")] + "(" + obj.get("default_value") + ")"
    obj["pdo_mapping"] = o.get("pdomapping", "0") == "1"
    obj["direction"] = "in" if obj.get("access_type") == "ro" else "out"
    if obj.get("access_type") in ["rw", "wo"]:
        if o.get("lowlimit") is not None:
            obj["low_limit"] = format_value(int(o.get("lowlimit"), 0), bit_length)
        if o.get("highlimit") is not None:
            obj["high_limit"] = format_value(int(o.get("highlimit"), 0), bit_length)
    obj.update(make_object_from_data_type(o.get("datatype")))
    print(o.get("parametername") + " => " + obj.get("name"))
    return obj


def parse_cob_id(s):
    if s.startswith("$NODEID+"):
         s = s[8:]
    return int(s, 0)


def zero_fill(l):
    s = format_value(0, l)
    if s != "":
        s += " & "
    return s
    s = ""
    x = l // 4
    if x > 0:
        s += 'x"' + "".ljust(x, "0") + '" & '
    b = l - (x * 4)
    if b > 0:
        s += 'b"' + "".ljust(b, "0") + '" & '
    return s


eds = ConfigParser(comment_prefixes=["#"])
eds.read(args.eds) # Loads in the EDS

#entity_name = "".join(map(str.capitalize, map(str.lower, eds["DeviceInfo"]["ProductName"].split(" ")))) + "CanOpen"
entity_name = format_signal(eds["DeviceInfo"]["ProductName"], prefix="", suffix="") + "CanOpen"
assert entity_name != ""

# Create pseudo-ObjectDictionary as a nested dict
indices = []
for section in ["MandatoryObjects", "OptionalObjects", "ManufacturerObjects"]:
    if not eds.has_section(section): continue
    n = int(eds[section]["SupportedObjects"], 0)
    for i in range(1, n + 1):
        indices.append(int(eds[section][str(i)], 0))
od = {}
for i in indices:
    oc = eds["{:04X}".format(i)]
    o = dict(oc)
    sub_number = oc.get("SubNumber")
    if sub_number is not None:
        sub_number = int(sub_number, 0)
        subs = {}
        si = 0
        while len(subs) <= sub_number and si <= 0xFF:
            section = "{:04X}sub{:d}".format(i, si)
            if eds.has_section(section):
                 subs.update({si: eds[section]})
            si += 1
        o['subs'] = subs
    od.update({i: o})

port_signals = []
segmented_sdo = False;
# Create a flat, VHDL-friendly version of the object dictionary
objects = {}
for odi in od:
    obj = od.get(odi)
    if "subs" in obj:
        subs = obj.get("subs")
        for odsi in subs:
            #if odsi == 0: continue
            so = subs.get(odsi)
            if odsi == 0:
                so["parametername"] = obj.get("parametername") + " Length"
            o = make_object(so)
            objects.update({(odi << 8) + odsi: o})
            if o.get("bit_length") == 0:
                segmented_sdo = True
                continue
            if odi >= 0x2000 or ((odi << 8) + odsi) in args.port:
                if o.get("access_type") in ["ro", "rw", "wo"]:
                    port_signals.append(o)
                if o.get("access_type") == "wo":
                    port_signals.append({
                        "name": format_signal(so.get("parametername"), suffix="_strb\\"),
                        "direction": "out",
                        "data_type": "std_logic"
                    })
    else:
        try:
            o = make_object(obj)
        except Exception as e:
            raise Exception("Error processing object 0x{:04X}".format(odi)) from e
        objects.update({odi << 8: o})
        if o.get("bit_length") == 0:
            segmented_sdo = True
            continue
        if odi >= 0x2000 or (odi << 8) in args.port:
            if o.get("access_type") in ["ro", "rw", "wo"]:
                port_signals.append(o)
            if o.get("access_type") == "wo":
                port_signals.append({
                    "name": format_signal(o.get("parameter_name"), suffix="_strb\\"),
                    "direction": "out",
                    "data_type": "std_logic"
                })

if 0x120001 not in objects:
    segmented_sdo = False;

# Prepend optional port signals
if segmented_sdo:
    port_signals.insert(0, {
        "name": "SegmentedSdoDataValid",
        "direction": "in",
        "data_type": "std_logic"
    })
    port_signals.insert(0, {
        "name": "SegmentedSdoData",
        "direction": "in",
        "data_type": "std_logic_vector(55 downto 0)"
    })
    port_signals.insert(0, {
        "name": "SegmentedSdoReadDataEnable",
        "direction": "out",
        "data_type": "std_logic"
    })
    port_signals.insert(0, {
        "name": "SegmentedSdoReadEnable",
        "direction": "out",
        "data_type": "std_logic"
    })
    port_signals.insert(0, {
        "name": "SegmentedSdoMux",
        "direction": "out",
        "data_type": "std_logic_vector(23 downto 0)",
    })
if args.timestamp:
    port_signals.insert(0, {
        "name": "Timestamp",
        "direction": "out",
        "data_type": "CanOpen.TimeOfDay"
    })
if args.gfc:
    port_signals.insert(0, {
        "name": "Gfc",
        "direction": "out",
        "data_type": "std_logic"
    })
if args.sync:
    port_signals.insert(0, {
        "name": "Sync",
        "direction": "out",
        "data_type": "std_logic"
    })

# Error checks
if 0x100000 not in objects:
    raise ValueError("Device type is required")
if 0x100100 not in objects:
    raise ValueError("Error register is required")
if 0x101800 not in objects:
    raise ValueError("Identity object is required")
if 0x101801 not in objects:
    raise ValueError("Vendor-ID is required")
names = []            
for mux in objects:
    name = objects.get(mux).get("name")
    if name in names:
        raise ValueError("Parameter names must be unique")
    names.append(name)

template = """{0} {1} is
    generic (
        CLOCK_FREQUENCY : positive --! Frequency of Clock in Hz
    );
    port (
        --! Common signals
        Clock       : in  std_logic;
        Reset_n     : in  std_logic;

        CanRx       : in std_logic;
        CanTx       : out std_logic;
        CanStatus   : out CanBus.Status;
        
        NodeId          : in std_logic_vector(6 downto 0);
        ErrorRegister   : in unsigned(7 downto 0);
        NmtState        : out std_logic_vector(6 downto 0);
        CommunicationError : out std_logic{2}

        --! Profile-specific signals
"""
template += ";\n".join(map(lambda signal: "        " + signal.get("name").ljust(19) + " : " + signal.get("direction") + " " + signal.get("data_type"), port_signals))
template += """
    );
end {0} {1};"""

fp = open(entity_name + ".vhd", "w")
fp.write("--! Generated with " + " ".join(argv) + "\n")
fp.write("""library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_misc.all;
    use ieee.numeric_std.all;

use work.CanBus;
use work.CanOpen;

""" + template.format("entity", entity_name, "" if len(port_signals) == 0 else ";") + """

architecture Behavioral of """ + entity_name + """ is
    type State is (
        STATE_RESET,
        STATE_RESET_APP,
        STATE_RESET_COMM,
        STATE_BOOTUP,
        STATE_BOOTUP_WAIT,
        STATE_IDLE,
        STATE_CAN_RX_STROBE,
        STATE_CAN_RX_READ,
        STATE_CAN_TX_STROBE,
        STATE_CAN_TX_WAIT,
        STATE_EMCY,
        STATE_TPDO1,
        STATE_TPDO2,
        STATE_TPDO3,
        STATE_TPDO4,
        STATE_SDO_RX,
        STATE_SDO_TX,
        STATE_HEARTBEAT
    );

    component CanLite is
        generic (
            BAUD_RATE_PRESCALAR         : positive range 1 to 64 := 1;
            SYNCHRONIZATION_JUMP_WIDTH  : positive range 1 to 4 := 3;
            TIME_SEGMENT_1              : positive range 1 to 16 := 8;
            TIME_SEGMENT_2              : positive range 1 to 8 := 3;
            TRIPLE_SAMPLING             : boolean := true
        );
        port (
            Clock               : in  std_logic; --! Base clock for CAN timing (24MHz recommended)
            Reset_n             : in  std_logic; --! Active-low reset

            CanRx               : in  std_logic; --! RX input from CAN transceiver
            CanTx               : out std_logic; --! TX output to CAN transceiver

            RxFrame             : out CanBus.Frame; --! To RX FIFO
            RxFifoWriteEnable   : out std_logic; --! To RX FIFO
            RxFifoFull          : in  std_logic; --! From RX FIFO

            TxFrame             : in  CanBus.Frame; --! From TX FIFO
            TxFifoReadEnable    : out std_logic; --! To TX FIFO
            TxFifoEmpty         : in std_logic; --! From TX FIFO
            TxAck               : out std_logic; --! High pulse when a message was successfully transmitted

            Status              : out CanBus.Status --! See Can_pkg.vhdl
        );
    end component CanLite;

    --! Internal signals
    signal CurrentState,
           NextState        : State; --! Primary state machine variables
    signal NodeId_q         : std_logic_vector(6 downto 0); --! Latched node-ID
    signal NmtState_ob       : std_logic_vector(6 downto 0); --! NMT state output buffer
    signal RxFrame,
           RxFrame_q,
           TxFrame,
           TxFrame_ob,
           TxFrame_q        : CanBus.Frame; --! CanLite frame interfacing
    signal RxFifoReadEnable,
           RxFifoWriteEnable,
           RxFifoEmpty,
           RxFifoFull,
           TxFifoReadEnable,
           TxFifoWriteEnable,
           TxFifoEmpty      : std_logic; --! CanLite FIFO interface
    signal TxAck            : std_logic; --! CanLite successful transmission
    signal CanStatus_ob     : CanBus.Status; --! CanLite status
    signal MicrosecondEnable,
           MillisecondEnable    : std_logic; --! Single-clock pulses
    signal CommunicationError_ob    : std_logic; --! Bit 4 of Error register
    signal Sync_ob                  : std_logic; --! Sync pulse output buffer
    signal HeartbeatConsumerError   : std_logic; --! Heartbeat timeout event has occurred
    signal EmcyEec          : std_logic_vector(15 downto 0); --! Emergency error code
    signal EmcyMsef         : std_logic_vector(39 downto 0); --! Manufacturer-specific error code
    signal Timestamp_ob     : CanOpen.TimeOfDay;
    
    --! Internal SDO signals
    signal RxSdo,
           TxSdo            : std_logic_vector(63 downto 0);
    signal RxSdoInitiateMux : std_logic_vector(23 downto 0);
    signal Tpdo1Data,
           Tpdo2Data,
           Tpdo3Data,
           Tpdo4Data        : std_logic_vector(63 downto 0);
""")
if not segmented_sdo:
    fp.write("""    signal SegmentedSdoMux         : std_logic_vector(23 downto 0);
    signal SegmentedSdoReadEnable  : std_logic;
    signal SegmentedSdoReadDataEnable  : std_logic;
    signal SegmentedSdoData        : std_logic_vector(55 downto 0);
    signal SegmentedSdoDataValid   : std_logic;
""")
fp.write("""
    --! Aliases for readability
    alias  RxCobIdFunctionCode              : std_logic_vector(3 downto 0) is RxFrame_q.Id(10 downto 7);
    alias  RxCobIdNodeId                    : std_logic_vector(6 downto 0) is RxFrame_q.Id(6 downto 0);
    alias  RxNmtNodeControlCommand          : std_logic_vector(7 downto 0) is RxFrame_q.Data(0);
    alias  RxNmtNodeControlNodeId           : std_logic_vector(6 downto 0) is RxFrame_q.Data(1)(6 downto 0);
    alias  RxSdoCs                          : std_logic_vector(2 downto 0) is RxSdo(7 downto 5);
    alias  RxSdoInitiateMuxIndex            : std_logic_vector(15 downto 0) is RxSdo(23 downto 8);
    alias  RxSdoInitiateMuxSubIndex         : std_logic_vector(7 downto 0) is RxSdo(31 downto 24);
    alias  RxSdoDownloadInitiateN           : std_logic_vector(1 downto 0) is RxSdo(3 downto 2);
    alias  RxSdoDownloadInitiateE           : std_logic is RxSdo(1);
    alias  RxSdoDownloadInitiateS           : std_logic is RxSdo(0);
    alias  RxSdoDownloadInitiateData        : std_logic_vector(31 downto 0) is RxSdo(63 downto 32);
    alias  RxSdoUploadSegmentT              : std_logic is RxSdo(4);
    alias  RxSdoUploadSegmentData           : std_logic_vector(55 downto 0) is RxSdo(55 downto 0);
    alias  RxSdoBlockUploadCs               : std_logic_vector is RxSdo(1 downto 0);
    alias  RxSdoBlockUploadInitiateCc       : std_logic is RxSdo(2);
    alias  RxSdoBlockUploadInitiateBlksize  : std_logic_vector(7 downto 0) is RxSdo(39 downto 32);
    alias  RxSdoBlockUploadInitiatePst      : std_logic_vector(7 downto 0) is RxSdo(47 downto 40);
    alias  RxSdoBlockUploadSubBlockAckseq   : std_logic_vector(7 downto 0) is RxSdo(15 downto 8);
    alias  RxSdoBlockUploadSubBlockBlksize  : std_logic_vector(7 downto 0) is RxSdo(23 downto 16);
    alias  RxSdoBlockUploadEndN             : std_logic_vector(2 downto 0) is RxSdo(4 downto 2);
    alias  RxSdoBlockUploadEndCrc           : std_logic_vector(15 downto 0) is RxSdo(23 downto 8);
    alias  TxSdoCs                          : std_logic_vector(2 downto 0) is TxSdo(7 downto 5);
    alias  TxSdoInitiateMuxIndex            : std_logic_vector(15 downto 0) is TxSdo(23 downto 8);
    alias  TxSdoInitiateMuxSubIndex         : std_logic_vector(7 downto 0) is TxSdo(31 downto 24);
    alias  TxSdoAbortCode                   : std_logic_vector(31 downto 0) is TxSdo(63 downto 32);
    alias  TxSdoUploadInitiateN             : std_logic_vector(1 downto 0) is TxSdo(3 downto 2);
    alias  TxSdoUploadInitiateE             : std_logic is TxSdo(1);
    alias  TxSdoUploadInitiateS             : std_logic is TxSdo(0);
    alias  TxSdoUploadInitiateD             : std_logic_vector(31 downto 0) is TxSdo(63 downto 32);
    alias  TxSdoUploadSegmentT              : std_logic is TxSdo(4);
    alias  TxSdoUploadSegmentN              : std_logic_vector(2 downto 0) is TxSdo(3 downto 1);
    alias  TxSdoUploadSegmentC              : std_logic is TxSdo(0);
    alias  TxSdoUploadSegmentSegData        : std_logic_vector(55 downto 0) is TxSdo(63 downto 8);
    alias  TxSdoBlockUploadSs               : std_logic is TxSdo(0);
    alias  TxSdoBlockUploadInitiateSc       : std_logic is TxSdo(2);
    alias  TxSdoBlockUploadInitiateS        : std_logic is TxSdo(1);
    alias  TxSdoBlockUploadInitiateSize     : std_logic_vector(31 downto 0) is TxSdo(63 downto 32);
    alias  TxSdoBlockUploadSubBlockC        : std_logic is TxSdo(7);
    alias  TxSdoBlockUploadSubBlockSeqno    : std_logic_vector(6 downto 0) is TxSdo(6 downto 0);
    alias  TxSdoBlockUploadSubBlockSegData  : std_logic_vector(55 downto 0) is TxSdo(63 downto 8);
    alias  TxSdoBlockUploadEndN             : std_logic_vector(2 downto 0) is TxSdo(4 downto 2);
    alias  TxSdoBlockUploadEndCrc           : std_logic_vector(15 downto 0) is TxSdo(23 downto 8);

    --! Interrupts
    signal EmcyInterrupt,
           HeartbeatProducerInterrupt,
           SdoInterrupt,
           Tpdo1Interrupt,
           Tpdo2Interrupt,
           Tpdo3Interrupt,
           Tpdo4Interrupt,
           TpdoInterruptEnable,
           Tpdo1InterruptEnable,
           Tpdo2InterruptEnable,
           Tpdo3InterruptEnable,
           Tpdo4InterruptEnable : std_logic;

    --! Object dictionary indices: Manufacturer-specific profile area
""");
for odi in od:
    obj = od.get(odi)
    if "subnumber" in obj:
        subs = obj.get("subs")
        for odsi in subs:
            if odsi == 0:
                fp.write("    constant " + format_constant(obj.get("parametername"), prefix="\\ODI_", suffix="_LENGTH\\").ljust(26) + ' : std_logic_vector(23 downto 0) := x"{:04X}{:02X}";\n'.format(odi, odsi))
            else:
                fp.write("    constant " + format_constant(subs.get(odsi).get("parametername"), prefix="\\ODI_").ljust(26) + ' : std_logic_vector(23 downto 0) := x"{:04X}{:02X}";\n'.format(odi, odsi))
    else:
        fp.write("    constant " + format_constant(obj.get("parametername"), prefix="\\ODI_").ljust(26) + ' : std_logic_vector(23 downto 0) := x"{:04X}00";\n'.format(odi))

fp.write("""
    --! Object dictionary entries
""")
for mux in objects:
    obj = objects.get(mux)
    if obj.get("access_type") == "const":
        fp.write("    constant " + obj.get("name").ljust(26) + " : " + obj.get("data_type") + " := " + obj.get("default_value") + ";\n")
    elif mux < 0x200000 and obj not in port_signals:
        fp.write("    signal " + obj.get("name").ljust(28) + " : " + obj.get("data_type") + ";\n")
    elif mux >= 0x200000 and obj.get("access_type") == "rw": # No additional declarations needed for mux >= 0x200000 and obj.get("access_type") in ["ro", "wo"]
        fp.write("    signal " + format_signal(obj.get("parameter_name"), suffix="_q\\").ljust(28) + " : " + obj.get("data_type") + ";\n")

fp.write("""
begin

    CanController : CanLite
        port map (
            Clock => Clock,
            Reset_n => Reset_n,
            CanRx => CanRx,
            CanTx => CanTx,
            RxFrame => RxFrame,
            RxFifoWriteEnable => RxFifoWriteEnable,
            RxFifoFull => RxFifoFull,
            TxFrame => TxFrame_q,
            TxFifoReadEnable => TxFifoReadEnable,
            TxFifoEmpty => TxFifoEmpty,
            TxAck => TxAck,
            Status => CanStatus_ob
        );

    --! Output signals
    NmtState <= NmtState_ob; --! Buffered
    CanStatus <= CanStatus_ob; --! Buffered
    CommunicationError <= CommunicationError_ob; --! Buffered
""")
if args.sync:
    fp.write("""    Sync <= Sync_ob; --! Buffered
""")
if args.gfc:
    fp.write("""    Gfc <= '1' when CurrentState = STATE_CAN_RX_READ and RxCobIdFunctionCode = CanOpen.FUNCTION_CODE_NMT and RxCobIdNodeId = CanOpen.NMT_GFC else '0';
""")
fp.write("""
    --! Single depth FIFO emulator for CanLite interface
    RxFifoReadEnable <= '1' when CurrentState = STATE_CAN_RX_STROBE else '0';
    RxFifoFull <= '0';
    TxFifoWriteEnable <= '1' when CurrentState = STATE_CAN_TX_STROBE else '0';
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            RxFrame_q <= (
                Id => (others => '0'),
                Rtr => '0',
                Ide => '0',
                Dlc => (others => '0'),
                Data => (others => (others => '0'))
            );
            RxFifoEmpty <= '1';
            TxFrame_ob <= (
                Id => (others => '0'),
                Rtr => '0',
                Ide => '0',
                Dlc => (others => '0'),
                Data => (others => (others => '0'))
            );
            TxFrame_q <= (
                Id => (others => '0'),
                Rtr => '0',
                Ide => '0',
                Dlc => (others => '0'),
                Data => (others => (others => '0'))
            );
            TxFifoEmpty <= '1';
        elsif rising_edge(Clock) then
            if RxFifoWriteEnable = '1' then
                RxFrame_q <= RxFrame;
            end if;
            if CanBus."="(CanStatus.State, CanBus.STATE_RESET) or CanBus."="(CanStatus.State, CanBus.STATE_BUS_OFF) then
                RxFifoEmpty <= '1';
            elsif RxFifoWriteEnable = '1' then
                RxFifoEmpty <= '0';
            elsif RxFifoReadEnable = '1' then
                RxFifoEmpty <= '1';
            end if;
            if TxFifoReadEnable = '1' then
                TxFrame_q <= TxFrame_ob;
            end if;
            if TxFifoWriteEnable = '1' then
                TxFrame_ob <= TxFrame;
            end if;
            if CanBus."="(CanStatus.State, CanBus.STATE_RESET) or CanBus."="(CanStatus.State, CanBus.STATE_BUS_OFF) then
                TxFifoEmpty <= '1';
            elsif TxFifoWriteEnable = '1' then
                TxFifoEmpty <= '0';
            elsif TxFifoReadEnable = '1' then
                TxFifoEmpty <= '1';
            end if;
        end if;
    end process;

    --! Primary state machine
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            CurrentState <= STATE_RESET;
        elsif rising_edge(Clock) then
            CurrentState <= NextState;
        end if;
    end process;

    --! Next state in state machine
    process (
""")
if 0x120001 in objects:
    fp.write("        " + objects.get(0x120001).get("name") + ",\n")
fp.write("""        CurrentState,
        TxAck,
        CanStatus.State,
        NodeId,
        EmcyInterrupt,
        HeartbeatProducerInterrupt,
        SdoInterrupt,
        Tpdo1Interrupt,
        Tpdo2Interrupt,
        Tpdo3Interrupt,
        Tpdo4Interrupt,
        RxFifoEmpty,
        NmtState_ob,
        TxFifoReadEnable,
        RxCobIdFunctionCode,
        RxCobIdNodeId,
        RxFrame_q.Dlc,
        RxNmtNodeControlNodeId,
        NodeId_q,
""")
if 0x120001 in objects:
    obj = objects.get(0x120001)
    fp.write("        " + obj.get("name") + """,
""")
fp.write("""        RxNmtNodeControlCommand
    )
    begin
        case CurrentState is
            when STATE_RESET => --! Power-on reset
                NextState <= STATE_RESET_APP;
            when STATE_RESET_APP => --! Service reset node
                    NextState <= STATE_RESET_COMM;
            when STATE_RESET_COMM => --! Service reset communication
                if CanBus."/="(CanStatus.State, CanBus.STATE_RESET) and CanBus."/="(CanStatus.State, CanBus.STATE_BUS_OFF) and NodeId /= CanOpen.BROADCAST_NODE_ID then --! Only boot if CAN bus is up and node-ID is valid
                    NextState <= STATE_BOOTUP;
                else
                    NextState <= STATE_RESET_COMM;
                end if;
            when STATE_BOOTUP => --! Service boot-up Event
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_BOOTUP_WAIT =>
                if TxAck = '1' then --! Wait until boot-up message has been sent
                    NextState <= STATE_IDLE;
                else
                    NextState <= STATE_BOOTUP_WAIT;
                end if;
            when STATE_IDLE => --! Wait for interrupt or reception of message from CanLite
                if CanBus."="(CanStatus.State, CanBus.STATE_RESET) or CanBus."="(CanStatus.State, CanBus.STATE_BUS_OFF) then
                    NextState <= STATE_IDLE;
                --! Interrupt (to transmit) priority based on CiA 301 function codes
                elsif EmcyInterrupt = '1' and (NmtState_ob = CanOpen.NMT_STATE_PREOPERATIONAL or NmtState_ob = CanOpen.NMT_STATE_OPERATIONAL) then
                    NextState <= STATE_EMCY;
                elsif Tpdo1Interrupt = '1' then
                    NextState <= STATE_TPDO1;
                elsif Tpdo2Interrupt = '1' then
                    NextState <= STATE_TPDO2;
                elsif Tpdo3Interrupt = '1' then
                    NextState <= STATE_TPDO3;
                elsif Tpdo4Interrupt = '1' then
                    NextState <= STATE_TPDO4;
                elsif SdoInterrupt = '1' then
                    NextState <= STATE_SDO_TX;
                elsif HeartbeatProducerInterrupt = '1' then
                    NextState <= STATE_HEARTBEAT;
                --! Nothing to transmit, check if need to read
                elsif RxFifoEmpty = '0' then
                    NextState <= STATE_CAN_RX_STROBE;
                else
                    NextState <= STATE_IDLE;
                end if;
            when STATE_EMCY =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_TPDO1 =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_TPDO2 =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_TPDO3 =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_TPDO4 =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_SDO_TX =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_HEARTBEAT =>
                NextState <= STATE_CAN_TX_STROBE;
            when STATE_CAN_TX_STROBE =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_CAN_TX_WAIT => --! Wait until message has been loaded into CanLite
                if NmtState_ob = CanOpen.NMT_STATE_INITIALISATION then
                    NextState <= STATE_BOOTUP_WAIT;
                elsif TxFifoReadEnable = '1' then
                    NextState <= STATE_IDLE;
                else
                    NextState <= STATE_CAN_TX_WAIT;
                end if;
            when STATE_CAN_RX_STROBE => --! Load message from CanLite
                NextState <= STATE_CAN_RX_READ;
            when STATE_CAN_RX_READ => --! Process message
                if RxCobIdFunctionCode = CanOpen.FUNCTION_CODE_NMT and RxCobIdNodeId = CanOpen.NMT_NODE_CONTROL and (RxNmtNodeControlNodeId = CanOpen.BROADCAST_NODE_ID or RxNmtNodeControlNodeId = NodeId_q) then
                    if RxNmtNodeControlCommand = CanOpen.NMT_NODE_CONTROL_RESET_APP then
                        NextState <= STATE_RESET_APP;
                    elsif RxNmtNodeControlCommand = CanOpen.NMT_NODE_CONTROL_RESET_COMM then
                        NextState <= STATE_RESET_COMM;
                    else
                        NextState <= STATE_IDLE;
                    end if;""")
if 0x120001 in objects:
    obj = objects.get(0x120001)
    fp.write("""
                elsif {0}(31) = '0' and RxFrame_q.Ide = {0}(29) and unsigned(RxFrame_q.Id(10 downto 0)) = {0}(10 downto 0) and RxFrame_q.Dlc(3) = '1' then --! SDO Request, ignore if not 8 data bytes
                    NextState <= STATE_SDO_RX;""".format(obj.get("name")))
fp.write("""
                else
                    NextState <= STATE_IDLE;
                end if;
            when STATE_SDO_RX =>
                NextState <= STATE_IDLE;
            when others =>
                NextState <= STATE_RESET;
        end case;
    end process;

    --! NMT State determination
    process (Clock, Reset_n)
    begin
        if Reset_n = '0' then
            NmtState_ob <= CanOpen.NMT_STATE_INITIALISATION;
        elsif rising_edge(Clock) then
""")
if 0x102901 in objects:
    fp.write("""            if CommunicationError_ob = '1' and NmtState_ob = CanOpen.NMT_STATE_OPERATIONAL and std_logic_vector({0}) = x"00" then
                NmtState_ob <= CanOpen.NMT_STATE_PREOPERATIONAL;
            elsif CommunicationError_ob = '1' and std_logic_vector({0}) = x"02" then
                NmtState_ob <= CanOpen.NMT_STATE_STOPPED;
""".format(objects.get(0x102901).get("name")))
    if 0x102902 in objects:
        fp.write("""            elsif {0}(0) = '1' and NmtState_ob = CanOpen.NMT_STATE_OPERATIONAL and {1} = x"00" then
                NmtState_ob <= CanOpen.NMT_STATE_PREOPERATIONAL;
            elsif {0}(0) = '1' and {1} = x"02" then
                NmtState_ob <= CanOpen.NMT_STATE_STOPPED;
""".format(objects.get(0x100100).get("name"), objects.get(0x102902).get("name")))
else:
    fp.write("""            if CommunicationError_ob = '1' and NmtState_ob = CanOpen.NMT_STATE_OPERATIONAL then
                NmtState_ob <= CanOpen.NMT_STATE_PREOPERATIONAL; --! Default behavior if the Communication error entry (0x01) of the Error behavior object (0x1029) not supported, per CiA 301
""")
fp.write("""            else
                case CurrentState is
                    when STATE_RESET =>
                        NmtState_ob <= CanOpen.NMT_STATE_INITIALISATION;
                    when STATE_RESET_APP =>
                        NmtState_ob <= CanOpen.NMT_STATE_INITIALISATION;
                    when STATE_RESET_COMM =>
                        NmtState_ob <= CanOpen.NMT_STATE_INITIALISATION;
                    when STATE_BOOTUP =>
                        NmtState_ob <= CanOpen.NMT_STATE_INITIALISATION;
                    when STATE_BOOTUP_WAIT =>
                        if TxAck = '1' then
""")
if 0x1F8000 in objects:
    fp.write("""                            if {0}(3) = '1' then
                                NmtState_ob <= CanOpen.NMT_STATE_OPERATIONAL;
                            else
                                NmtState_ob <= CanOpen.NMT_STATE_PREOPERATIONAL;
                            end if;
""".format(objects.get(0x1F8000).get("name")))
else:
    fp.write("""                            NmtState_ob <= CanOpen.NMT_STATE_PREOPERATIONAL;
""")
fp.write("""            else
                            NmtState_ob <= CanOpen.NMT_STATE_INITIALISATION;
                        end if;
                    when STATE_CAN_RX_READ =>
                        if RxCobIdFunctionCode = CanOpen.FUNCTION_CODE_NMT and RxCobIdNodeId = CanOpen.NMT_NODE_CONTROL and (RxNmtNodeControlNodeId = NodeId_q or RxNmtNodeControlNodeId = CanOpen.BROADCAST_NODE_ID) then
                            case RxNmtNodeControlCommand is
                                when CanOpen.NMT_NODE_CONTROL_OPERATIONAL =>
                                    NmtState_ob <= CanOpen.NMT_STATE_OPERATIONAL;
                                when CanOpen.NMT_NODE_CONTROL_PREOPERATIONAL =>
                                    NmtState_ob <= CanOpen.NMT_STATE_PREOPERATIONAL;
                                when CanOpen.NMT_NODE_CONTROL_STOPPED =>
                                    NmtState_ob <= CanOpen.NMT_STATE_STOPPED;
                                when others =>
                                    NmtState_ob <= NmtState_ob;
                            end case;
                        end if;
                    when others =>
                        NmtState_ob <= NmtState_ob;
                end case;
            end if;
        end if;
    end process;

    --! Latch node-ID
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            NodeId_q <= CanOpen.BROADCAST_NODE_ID;
        elsif rising_edge(Clock) then
            if CurrentState = STATE_RESET_COMM then
                NodeId_q <= NodeId;
            end if;
        end if;
    end process;

    --! TIME handling""")
if args.timestamp:
    fp.write("""
    Timestamp <= Timestamp_ob;""")
fp.write("""
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            Timestamp_ob <= (
                Milliseconds => (others => '0'),
                Days => (others => '0')
            );
        elsif rising_edge(Clock) then
            """)
if 0x101200 in objects:
    fp.write("""if CurrentState = STATE_CAN_RX_READ and {0}(31) = '1' and unsigned(RxFrame_q.Id(10 downto 0)) = {0}(10 downto 0) and RxFrame_q.Dlc = b"0110" then
                Timestamp_ob <= (
                    Milliseconds => unsigned(RxFrame_q.Data(3)(3 downto 0) & RxFrame_q.Data(2) & RxFrame_q.Data(1) & RxFrame_q.Data(0)),
                    Days => unsigned(RxFrame_q.Data(5) & RxFrame_q.Data(4))
                );
            els""".format(objects.get(0x101200).get("name")))
fp.write("""if MillisecondEnable = '1' then
                if Timestamp_ob.Milliseconds = 1000*60*60*24 - 1 then
                    Timestamp_ob.Milliseconds <= (others => '0');
                    Timestamp_ob.Days <= Timestamp_ob.Days + 1;
                else
                    Timestamp_ob.Milliseconds <= Timestamp_ob.Milliseconds + 1;
                end if;
            end if;
        end if;
    end process;
    
    --! EMCY interrupt handling
    process (Reset_n, Clock)
        variable ErrorRegisterInterrupts    : std_logic_vector(7 downto 0);
        variable ErrorRegister_q            : unsigned(7 downto 0);
    begin
        if Reset_n = '0' then
            EmcyInterrupt <= '0';
            EmcyEec <= (others => '0');
            ErrorRegisterInterrupts := (others => '0');
            ErrorRegister_q := (others => '0');
        elsif rising_edge(Clock) then
""")
for i in range(8):
    if i == 6: continue
    fp.write("""            if {0}({1}) = '1' and ErrorRegister_q({1}) = '0' then
                ErrorRegisterInterrupts({1}) := '1';
            end if;
""".format(objects.get(0x100100).get("name"), i))
fp.write("""            if EmcyInterrupt = '0' and (or_reduce(ErrorRegisterInterrupts) = '1' or ({0} = x"00" and ErrorRegister_q /= x"00")) then
                EmcyInterrupt <= '1';
                if ErrorRegisterInterrupts(0) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_GENERIC;
                    ErrorRegisterInterrupts(0) := '0';
                elsif ErrorRegisterInterrupts(1) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_CURRENT;
                    ErrorRegisterInterrupts(1) := '0';
                elsif ErrorRegisterInterrupts(2) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_VOLTAGE;
                    ErrorRegisterInterrupts(2) := '0';
                elsif ErrorRegisterInterrupts(3) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_TEMPERATURE;
                    ErrorRegisterInterrupts(3) := '0';
                elsif ErrorRegisterInterrupts(4) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_COMMUNICATION;
                    ErrorRegisterInterrupts(4) := '0';
                elsif ErrorRegisterInterrupts(5) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_DEVICE_SPECIFIC;
                    ErrorRegisterInterrupts(5) := '0';
                elsif ErrorRegisterInterrupts(7) = '1' then
                    EmcyEec <= CanOpen.EMCY_EEC_DEVICE_SPECIFIC;
                    ErrorRegisterInterrupts(7) := '0';
                else
                    EmcyEec <= CanOpen.EMCY_EEC_NO_ERROR;
                end if;
            elsif CurrentState = STATE_EMCY then
                EmcyInterrupt <= '0';
            end if;
            ErrorRegister_q := {0};
        end if;
    end process;
    EmcyMsef <= (others => '0'); --! Manufacturer-specific error code not implemented
""".format(objects.get(0x100100).get("name")))

fp.write("""
     --! Timers
    process (Reset_n, Clock)
        variable MicrosecondCounter         : natural range 0 to (CLOCK_FREQUENCY / 1000000);
        variable MillisecondCounter         : natural range 0 to 1000;
    begin
        if Reset_n = '0' then
            MicrosecondCounter := 0;
            MicrosecondEnable <= '0';
            MillisecondCounter := 0;
            MillisecondEnable <= '0';
        elsif rising_edge(Clock) then
            if MicrosecondCounter = (CLOCK_FREQUENCY / 1000000) - 1 then
                MicrosecondCounter := 0;
                MicrosecondEnable <= '1';
            else
                MicrosecondCounter := MicrosecondCounter + 1;
                MicrosecondEnable <= '0';
            end if;
            if MicrosecondEnable = '1' then
                if MillisecondCounter = 999 then
                    MillisecondCounter := 0;
                    MillisecondEnable <= '1';
                else
                    MillisecondCounter := MillisecondCounter + 1;
                    MillisecondEnable <= '0';
                end if;
            else
                MillisecondEnable <= '0';
            end if;
        end if;
    end process;
""")

# TODO: Support multiple heartbeat consumers (if so, should check for duplicate node-IDs in VHDL)
if 0x101601 in objects:
    fp.write("""
    --! Heartbeat consumer timer
    process (
        Reset_n,
        Clock,
        CurrentState,
        RxCobIdFunctionCode,
        RxCobIdNodeId,
        {0},
        TxSdoCs,
        TxSdoInitiateMuxIndex,
        TxSdoInitiateMuxSubIndex
    )
        variable HeartbeatConsumerCounter   : natural range 0 to 65535;
        variable HeartbeatConsumerEnable    : std_logic;
        variable HeartbeatConsumerReset     : std_logic;
    begin
        if CurrentState = STATE_CAN_RX_READ and RxCobIdFunctionCode = CanOpen.FUNCTION_CODE_NMT_ERROR_CONTROL and unsigned(RxCobIdNodeId(6 downto 0)) = {0}(22 downto 16) then
            HeartbeatConsumerReset := '1';
        elsif CurrentState = STATE_SDO_TX and TxSdoCs = CanOpen.SDO_SCS_IDR and TxSdoInitiateMuxIndex = x"1016" and TxSdoInitiateMuxSubIndex = x"01" then
            HeartbeatConsumerReset := '1';
        else
            HeartbeatConsumerReset := '0';
        end if;
        if Reset_n = '0' then
            HeartbeatConsumerCounter := 0;
            HeartbeatConsumerEnable := '0';
            HeartbeatConsumerError <= '0';
        elsif rising_edge(Clock) then
            if {0}(23 downto 16) = 0 or {0}(23 downto 16) > 127 or {0}(15 downto 0) = 0 then --! Check if entry is valid
                HeartbeatConsumerEnable := '0';
            elsif HeartbeatConsumerReset = '1' then --! Enable heartbeat consumer after first heartbeat is received
                HeartbeatConsumerEnable := '1';
            end if;
            if HeartbeatConsumerEnable = '0' or HeartbeatConsumerReset = '1' then
                HeartbeatConsumerCounter := 0;
            elsif MillisecondEnable = '1' and HeartbeatConsumerCounter < {0}(15 downto 0) then
                HeartbeatConsumerCounter := HeartbeatConsumerCounter + 1;
            end if;
            if HeartbeatConsumerEnable = '0' or HeartbeatConsumerReset = '1' then
                HeartbeatConsumerError <= '0';
            elsif HeartbeatConsumerCounter = {0}(15 downto 0) then
                HeartbeatConsumerError <= '1';
            end if;
        end if;
    end process;
""".format(objects.get(0x101601).get("name")))
else:
    fp.write("""
    HeartbeatConsumerError <= '0';
""")

if 0x101700 in objects:
    fp.write("""
    --! Heartbeat producer timer
    process (Reset_n, Clock)
        variable HeartbeatProducerCounter   : natural range 0 to 65535;
        variable HeartbeatConsumerReset     : std_logic;
    begin
        if Reset_n = '0' then
            HeartbeatProducerCounter := 0;
            HeartbeatProducerInterrupt <= '0';
        elsif rising_edge(Clock) then
            if (
                NmtState_ob = CanOpen.NMT_STATE_INITIALISATION
                or {0} = 0
                or CurrentState = STATE_RESET_COMM
                or (CurrentState = STATE_SDO_TX and TxSdoCs = CanOpen.SDO_SCS_IDR and TxSdoInitiateMuxIndex = x"1017" and TxSdoInitiateMuxSubIndex = x"00")
            ) then
                HeartbeatProducerCounter := 0;
            elsif MillisecondEnable = '1' then
                if HeartbeatProducerCounter = {0} - 1 then
                    HeartbeatProducerCounter := 0;
                else
                    HeartbeatProducerCounter := HeartbeatProducerCounter + 1;
                end if;
            end if;
            if MillisecondEnable = '1' and HeartbeatProducerCounter = {0} - 1 then
                HeartbeatProducerInterrupt <= '1';
            elsif CurrentState = STATE_HEARTBEAT then
                HeartbeatProducerInterrupt <= '0';
            end if;
        end if;
    end process;
""".format(objects.get(0x101700).get("name")))
else:
    fp.write("""
    HeartbeatProducerInterrupt <= '0';
""")

fp.write("""
    --! TPDO
    TpdoInterruptEnable <= '1' when Sync_ob = '1' and NmtState_ob = CanOpen.NMT_STATE_OPERATIONAL else '0'; --! "Global" TPDO interrupt enable\n""")

for i in range(4):
    fp.write("""
    --! TPDO{0} interrupt
""".format(i + 1))
    mux = ((0x1800 + i) << 8) + 0x01
    if mux not in objects:
        fp.write("""    Tpdo{0}InterruptEnable <= '0';
    Tpdo{0}Interrupt <= '0';
""".format(i + 1))
        continue
    obj = objects.get(mux)
    fp.write("""    Tpdo{0}InterruptEnable <= '1' when TpdoInterruptEnable = '1' or (CurrentState = STATE_CAN_RX_READ and {1}(31) = '0' and RxFrame_q.Ide = {1}(29) and unsigned(RxFrame_q.Id) ={1}(28 downto 0) and RxFrame_q.Rtr = '1') else '0';
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            Tpdo{0}Interrupt <= '0';
        elsif rising_edge(Clock) then
            if Tpdo{0}InterruptEnable = '1' then
                Tpdo{0}Interrupt <= '1';
            elsif CurrentState = STATE_TPDO{0} then
                Tpdo{0}Interrupt <= '0';
            end if;
        end if;
    end process;
""".format(i + 1, obj.get("name")))

fp.write("""
    --! TPDO mappings
""")
# TODO: Rewrite this section to use "objects" instead of "od"
tpdo_lengths = []
for i in range(4):
    fp.write("    Tpdo{:d}Data <= ".format(i + 1))
    tpdo_length = 0
    if 0x1A00 + i in od:
        tpdo = []
        tpdo_length = 0
        obj = od.get(0x1A00 + i)
        subs = obj.get("subs")
        for odsi in subs:
            if odsi == 0: continue
            mapping = parse_cob_id(subs.get(odsi).get("defaultvalue"))
            mux = mapping >> 8
            bit_length = mapping & 0xFF
            if not mux in objects:
                raise IndexError("TPDO{:d} Mapping {:d} (0x{:06X}) does not exist in object dictionary".format(i + 1, odsi, mux))
            mappee = objects.get(mux)
            if mappee.get("access_type") == "wo":
                raise ValueError("TPDO{:d} Mapping {:d} (0x{:06X}) is write-only".format(i + 1, odsi, mux))
            if not mappee.get("pdo_mapping"):
                raise ValueError("TPDO{:d} Mapping {:d} (0x{:06X}) is not mappable".format(i + 1, odsi, mux))
            if bit_length != mappee.get("bit_length"):
                raise ValueError("TPDO{:d} Mapping {:d} length mismatch".format(i + 1, odsi))
            name = mappee.get("name")
            if mappee.get("data_type") not in ["std_logic", "std_logic_vector"]:
                 name = "std_logic_vector(" + name + ")"
            tpdo.append(name)
            tpdo_length += bit_length;
        if tpdo_length > 64:
            raise ValueError("TPDO{:d} Mapping is greater than 64 bits".format(i + i))
        tpdo.reverse()
        fp.write(zero_fill(64 - tpdo_length) + " & ".join(tpdo))
    else:
        fp.write("(others => '0')")
    fp.write(";\n")
    tpdo_lengths.append(tpdo_length)
    
fp.write("""
    --! Load CAN TX frame
    process (Clock, Reset_n)
    begin
        if Reset_n = '0' then
            TxFrame <= (
                Id => (others => '0'),
                Rtr => '0',
                Ide => '0',
                Dlc => (others => '0'),
                Data => (others => (others => '0'))
            );
        elsif rising_edge(Clock) then
            TxFrame.Id(28 downto 11) <= (others => '0');
            TxFrame.Rtr <= '0'; --! Need to set these, otherwise latch is inferred
            TxFrame.Ide <= '0';
            if CurrentState = STATE_BOOTUP then
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_NMT_ERROR_CONTROL & NodeId_q;
                TxFrame.Dlc <= b"0001";
                TxFrame.Data <= (others => (others => '0'));
""")
if 0x101400 in objects:
    fp.write("""            elsif CurrentState = STATE_EMCY then
                TxFrame.Id(10 downto 0) <= std_logic_vector(""" + objects.get(0x101400).get("name") + """(10 downto 0));
                TxFrame.Dlc <= b"1000";
                TxFrame.Data(0) <= EmcyEec(7 downto 0);
                TxFrame.Data(1) <= EmcyEec(15 downto 8);
                TxFrame.Data(2) <= std_logic_vector(""" + objects.get(0x100100).get("name") + """);
                TxFrame.Data(3) <= EmcyMsef(7 downto 0);
                TxFrame.Data(4) <= EmcyMsef(15 downto 8);
                TxFrame.Data(5) <= EmcyMsef(23 downto 16);
                TxFrame.Data(6) <= EmcyMsef(31 downto 24);
                TxFrame.Data(7) <= EmcyMsef(39 downto 32);
""")
for i in range(4):
    mux = ((0x1800 + i) << 8) + 0x01
    if mux not in objects: continue
    obj = objects.get(mux)
    dlc, r = divmod(tpdo_lengths[i], 8)
    if r > 0:
        dlc += 1
    fp.write("""            elsif CurrentState = STATE_TPDO{0} then
                TxFrame.Id(10 downto 0) <= std_logic_vector({1}(10 downto 0));
                TxFrame.Dlc <= b"{2:04b}";
                TxFrame.Data(0) <= Tpdo{0}Data(7 downto 0);
                TxFrame.Data(1) <= Tpdo{0}Data(15 downto 8);
                TxFrame.Data(2) <= Tpdo{0}Data(23 downto 16);
                TxFrame.Data(3) <= Tpdo{0}Data(31 downto 24);
                TxFrame.Data(4) <= Tpdo{0}Data(39 downto 32);
                TxFrame.Data(5) <= Tpdo{0}Data(47 downto 40);
                TxFrame.Data(6) <= Tpdo{0}Data(55 downto 48);
                TxFrame.Data(7) <= Tpdo{0}Data(63 downto 56);
""".format(i + 1, obj.get("name"), dlc))
if 0x120002 in objects:
    obj = objects.get(0x120002)
    fp.write("""            elsif CurrentState = STATE_SDO_TX then
                TxFrame.Id(10 downto 0) <= std_logic_vector(""" + obj.get("name") + """(10 downto 0));
                TxFrame.Dlc <= b"1000";
                TxFrame.Data(0) <= TxSdo(7 downto 0);
                TxFrame.Data(1) <= TxSdo(15 downto 8);
                TxFrame.Data(2) <= TxSdo(23 downto 16);
                TxFrame.Data(3) <= TxSdo(31 downto 24);
                TxFrame.Data(4) <= TxSdo(39 downto 32);
                TxFrame.Data(5) <= TxSdo(47 downto 40);
                TxFrame.Data(6) <= TxSdo(55 downto 48);
                TxFrame.Data(7) <= TxSdo(63 downto 56);
""")
fp.write("""            elsif CurrentState = STATE_HEARTBEAT then
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_NMT_ERROR_CONTROL & NodeId_q;
                TxFrame.Dlc <= b"0001";
                TxFrame.Data <= (0 => '0' & NmtState_ob, others => (others => '0'));
            end if;
        end if;
    end process;
""")

fp.write("""
    --! Save SDO request
""")
if 0x120001 in objects:
    obj = objects.get(0x120001)
    fp.write("""    process (Clock, Reset_n)
    begin
        if Reset_n = '0' then
            RxSdo <= (others => '0');
        elsif rising_edge(Clock) then
            if CurrentState = STATE_CAN_RX_READ and {0}(31) = '0' and RxFrame_q.Ide = {0}(29) and unsigned(RxFrame_q.Id(10 downto 0)) = {0}(10 downto 0) and RxFrame_q.Dlc(3) = '1' then --! SDO Request, ignore if not 8 data bytes
                RxSdo <= RxFrame_q.Data(7) & RxFrame_q.Data(6) & RxFrame_q.Data(5) & RxFrame_q.Data(4) & RxFrame_q.Data(3) & RxFrame_q.Data(2) & RxFrame_q.Data(1) & RxFrame_q.Data(0);
            end if;
        end if;
    end process;
""".format(obj.get("name")))
else:
    fp.write("""    RxSdo <= (others => '0');
""")

if 0x120001 in objects:
    fp.write("""
    --! SDO
    RxSdoInitiateMux <= RxSdoInitiateMuxIndex & RxSdoInitiateMuxSubIndex;
    process (Clock, Reset_n, SegmentedSdoData, SegmentedSdoDataValid)
        variable SegmentedSdoReadBytes : unsigned(31 downto 0);
        variable SdoActive          : boolean; --! In non-expedited transaction
        variable SdoBlockCrc        : std_logic_vector(15 downto 0);
        variable SdoBlockMode       : boolean; --! Sending sub-blocks
        variable SdoBlockSize       : unsigned(6 downto 0); --! From client
        variable SdoExternal        : boolean;
        variable SdoMux             : std_logic_vector(23 downto 0); --! Upload request mux
        variable SdoPending         : boolean; --! Waiting for SegmentedSdoDataValid
        variable SdoSegData         : std_logic_vector(55 downto 0);
        variable SdoSegDataInternal : std_logic_vector(55 downto 0);
        variable SdoSegDataValid    : std_logic;
        variable SdoSequenceNumber  : unsigned(6 downto 0);
        variable SdoToggle          : std_logic; --! Toggle bit for segmented transfer
    begin
        if SdoExternal then
            SdoSegData := SegmentedSdoData;
            SdoSegDataValid := SegmentedSdoDataValid;
        else
            SdoSegData := SdoSegDataInternal;
            SdoSegDataValid := '1';
        end if;
        if Reset_n = '0' then
            TxSdo <= (others => '0');
            SdoInterrupt <= '0';
            SegmentedSdoReadBytes := (others => '0');
            SegmentedSdoReadDataEnable <= '0';
            SdoActive := false;
            SdoBlockMode := false;
            SdoBlockSize := (others => '0');
            SdoBlockCrc := (others => '0');
            SdoExternal := false;
            SdoMux := (others => '0');
            SdoPending := false;
            SdoSegDataInternal := (others => '0');
            SdoSequenceNumber := (others => '0');
            SdoToggle := '0';
        elsif rising_edge(Clock) then
            if CurrentState = STATE_CAN_RX_READ then
                if {0}(31) = '0' and RxFrame_q.Ide = {0}(29) and unsigned(RxFrame_q.Id(10 downto 0)) = {0}(10 downto 0) and RxFrame_q.Dlc(3) = '1' then --! Next state is STATE_SDO_TX
                    if RxFrame_q.Data(0)(7 downto 5) = CanOpen.SDO_CCS_IUR or (RxFrame_q.Data(0)(7 downto 5) = CanOpen.SDO_CCS_BUR and RxFrame_q.Data(0)(1 downto 0) = CanOpen.SDO_BLOCK_SUBCOMMAND_INITIATE) then
                        SdoMux := RxFrame_q.Data(2) & RxFrame_q.Data(1) & RxFrame_q.Data(3);
                        SdoExternal := true; --! Note: this will be deasserted in STATE_CAN_RX if not internal mux is used
                    end if;
                end if;
            elsif CurrentState = STATE_SDO_RX then
                if RxSdoCs = CanOpen.SDO_CS_ABORT then
                    SegmentedSdoReadBytes := (others => '0');
                    SdoActive := false;
                    SdoBlockMode := false;
                    SdoPending := false;
                    SdoExternal := false;
                    SegmentedSdoReadDataEnable <= '0';
                elsif RxSdoCs = CanOpen.SDO_CCS_IDR then
                    TxSdo(4 downto 0) <= (others => '0'); 
                    TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                    TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                    if RxSdoDownloadInitiateE = '0' then
                        TxSdoCs <= CanOpen.SDO_CS_ABORT;
                        TxSdoAbortCode <= CanOpen.SDO_ABORT_ACCESS;
                    else
                        case RxSdoInitiateMux is
""".format(objects.get(0x120001).get("name")))
    for mux in objects:
        obj = objects.get(mux)
        fp.write("""                            when """ + format_constant(obj.get("parameter_name"), prefix="\\ODI_") + """ =>
""")
        if obj.get("access_type") in ["const", "ro"]:
            fp.write("""                                TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                TxSdoAbortCode <= CanOpen.SDO_ABORT_RO;
""")
            continue;
        fp.write("""                                if RxSdoDownloadInitiateN = b"{:02b}" or RxSdoDownloadInitiateS = '0' then
""".format(4 - math.ceil(obj.get("bit_length") / 8)))
        if obj.get("low_limit") is not None or obj.get("high_limit") is not None:
            if obj.get("data_type").startswith("std_logic"):
                assignment = "RxSdoDownloadInitiateData"
                if obj.get("data_type") == "std_logic":
                     assignment += "(0)"
            else:
                assignment = re.sub("(\w+)\(", r"\1(RxSdoDownloadInitiateData(", obj.get("data_type")) + ")"
            conditionals = []
            if obj.get("low_limit") is not None:
                conditionals.append(assignment + " >= " + obj.get("low_limit"))
            if obj.get("high_limit") is not None:
                conditionals.append(assignment + " <= " + obj.get("high_limit"))
            fp.write("                                      if " + " and ".join(conditionals) + """ then
                                            TxSdoCs <= CanOpen.SDO_SCS_IDR;
                                            TxSdo(63 downto 32) <= (others => '0');
                                        else
                                            TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                            TxSdoAbortCode <= CanOpen.SDO_ABORT_PARAM_INVALID;
                                        end if;
""")
        else:
            fp.write("""                                    TxSdoCs <= CanOpen.SDO_SCS_IDR;
                                    TxSdo(63 downto 32) <= (others => '0');
""")
        fp.write("""                                else
                                    TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                    TxSdoAbortCode <= CanOpen.SDO_ABORT_PARAM_LENGTH;
                                end if;
""")
    fp.write("""                            when others =>
                                TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                TxSdoAbortCode <= CanOpen.SDO_ABORT_DNE;
                        end case;
                    end if;
                    SdoActive := false;
                    SdoBlockMode := false;
                    SdoPending := false;
                    SdoExternal := false;
                    SegmentedSdoReadDataEnable <= '0';
                    SdoInterrupt <= '1';
                elsif RxSdoCs = CanOpen.SDO_CCS_IUR then
                    TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                    TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                    SdoToggle := '0';
                    case RxSdoInitiateMux is
""")
    for mux in objects:
        obj = objects.get(mux)
        fp.write("""                        when """ + format_constant(obj.get("parameter_name"), prefix="\\ODI_") + """ =>
""")
        if obj.get("access_type") == "wo":
            fp.write("""                            TxSdoCs <= CanOpen.SDO_CS_ABORT;
                            TxSdo(4 downto 0) <= (others => '0');
                            TxSdoAbortCode <= CanOpen.SDO_ABORT_WO;
                            SdoActive := false;
                            SdoBlockMode := false;
                            SdoPending := false;
                            SdoExternal := false;
                            SegmentedSdoReadDataEnable <= '0';
""")
        else:
            cs = "SCS_IUR"
            s = 1
            data = ""
            if obj.get("bit_length") > 32 or obj.get("bit_length") == 0:
                n = 0
                e = 0
                data = "SegmentedSdoData(31 downto 0)";
            else:
                b, r = divmod(obj.get("bit_length"), 8)
                if r > 0:
                    b += 1
                n = 4 - b
                e = 1
                if not obj.get("data_type").startswith("std_logic"):
                     data += "std_logic_vector("
                if mux >= 0x200000 and obj.get("access_type") == "rw":
                     data += format_signal(obj.get("parameter_name"), suffix="_q\\")
                else:
                    data += obj.get("name")
                if not obj.get("data_type").startswith("std_logic"):
                     data += ")"
                data = zero_fill(32 - obj.get("bit_length")) + data
            fp.write("""                            TxSdoCs <= CanOpen.SDO_""" + cs + """;
                            TxSdoUploadInitiateN <= b"{:02b}";
                            TxSdoUploadInitiateE <= '{:d}';
                            TxSdoUploadInitiateS <= '{:d}';
                            TxSdoUploadInitiateD <= """.format(n, e, s) + data + """;
""")
            if e == 0:
                fp.write("""                            SdoActive := true;
                            SegmentedSdoReadBytes := unsigned(SegmentedSdoData(31 downto 0));
""")
            else:
                fp.write("""                            SdoActive := false;
                            SdoExternal := false;
""")
    fp.write("""                        when others =>
                            TxSdoCs <= CanOpen.SDO_CS_ABORT;
                            TxSdo(4 downto 0) <= (others => '0');
                            TxSdoAbortCode <= CanOpen.SDO_ABORT_DNE;
                            SdoExternal := false;
                            SegmentedSdoReadDataEnable <= '0';
                            SdoActive := false;
                            SdoBlockMode := false;
                            SdoPending := false;
                    end case;
                    SdoInterrupt <= '1';
                elsif RxSdoCs = CanOpen.SDO_CCS_USR then
                    if RxSdoUploadSegmentT /= SdoToggle then
                        TxSdoCs <= CanOpen.SDO_CS_ABORT;
                        TxSdo(4 downto 0) <= (others => '0');
                        TxSdoInitiateMuxIndex <= SdoMux(23 downto 8);
                        TxSdoInitiateMuxSubIndex <= SdoMux(7 downto 0);
                        TxSdoAbortCode <= CanOpen.SDO_ABORT_TOGGLE;
                        SdoActive := false;
                        SdoBlockMode := false;
                        SdoPending := false;
                        SdoExternal := false;
                        SegmentedSdoReadDataEnable <= '0';
                        SdoInterrupt <= '1';
                    else
                        TxSdoCs <= CanOpen.SDO_SCS_USR;
                        TxSdoUploadSegmentC <= '0';
                        SdoPending := true;
                    end if;
                elsif RxSdoCs = CanOpen.SDO_CCS_BUR then
                    if RxSdoBlockUploadCs = CanOpen.SDO_BLOCK_SUBCOMMAND_INITIATE then
                        if SdoActive then
                            TxSdoCs <= CanOpen.SDO_CS_ABORT;
                            TxSdo(4 downto 0) <= (others => '0');
                            TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                            TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                            TxSdoAbortCode <= CanOpen.SDO_ABORT_CS; --! Unexpected subcommand
                            SdoExternal := false;
                            SegmentedSdoReadDataEnable <= '0';
                            SdoActive := false;
                            SdoBlockMode := false;
                            SdoPending := false;
                        else
                            if RxSdoBlockUploadInitiateBlksize(7) = '1' or RxSdoBlockUploadInitiateBlksize(6 downto 0) = b"0000000" then
                                TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                TxSdo(4 downto 0) <= (others => '0');
                                TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                                TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                                TxSdoAbortCode <= CanOpen.SDO_ABORT_BLKSIZE;
                                SdoExternal := false;
                                SegmentedSdoReadDataEnable <= '0';
                                SdoActive := false;
                                SdoBlockMode := false;
                                SdoPending := false;
                            else
                                case SdoMux is
""")
    for mux in objects:
        obj = objects.get(mux)
        fp.write("""                                   when x"{:06X}" =>
""".format(mux))
        if obj.get("access_type") == "wo":
            fp.write("""                                    TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                        TxSdo(4 downto 0) <= (others => '0');
                                        TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                                        TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                                        TxSdoAbortCode <= CanOpen.SDO_ABORT_WO;
                                        SdoExternal := false;
                                        SegmentedSdoReadDataEnable <= '0';
                                        SdoActive := false;
                                        SdoBlockMode := false;
""")
            continue;
        if obj.get("bit_length") == 0 or obj.get("bit_length") > 32:
            fp.write("""                                        if SegmentedSdoData(31 downto 0) = x"00000000" then
                                            TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                            TxSdo(4 downto 0) <= (others => '0');
                                            TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                                            TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                                            TxSdoAbortCode <= CanOpen.SDO_ABORT_NO_DATA;
                                            SdoExternal := false;
                                            SegmentedSdoReadDataEnable <= '0';
                                            SdoActive := false;
                                            SdoBlockMode := false;
                                            SdoPending := false;
                                        else
                                            TxSdoCs <= CanOpen.SDO_SCS_BUR;
                                            TxSdo(4 downto 3) <= (others => '0');
                                            TxSdoBlockUploadInitiateSc <= '1'; --! Server CRC support
                                            TxSdoBlockUploadInitiateS <= '1'; --! Size indicator
                                            TxSdoBlockUploadSs <= CanOpen.SDO_BLOCK_SUBCOMMAND_INITIATE(0);
                                            TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                                            TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                                            TxSdoBlockUploadInitiateSize <= SegmentedSdoData(31 downto 0);
                                            SegmentedSdoReadBytes := unsigned(SegmentedSdoData(31 downto 0));
                                            SdoActive := true;
                                            SdoBlockSize := unsigned(RxSdoBlockUploadInitiateBlksize(6 downto 0));
                                            SdoSequenceNumber := (others => '0');
                                        end if;
""")
        else:
            n = 4 - math.ceil(obj.get("bit_length") / 8)
            data = ""
            if not obj.get("data_type").startswith("std_logic"):
                 data += "std_logic_vector("
            if mux >= 0x200000 and obj.get("access_type") == "rw":
                 data += format_signal(obj.get("parameter_name"), suffix="_q\\")
            else:
                data += obj.get("name")
            if not obj.get("data_type").startswith("std_logic"):
                 data += ")"
            fp.write("""                                        TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                                        TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                                        if RxSdoBlockUploadInitiatePst /= x"00" and unsigned(RxSdoBlockUploadInitiatePst) <= 4 then
                                            TxSdoCs <= CanOpen.SDO_SCS_IUR;
                                            TxSdoUploadInitiateN <= b"{0:02b}";
                                            TxSdoUploadInitiateE <= '1';
                                            TxSdoUploadInitiateS <= '1';
                                            TxSdoUploadInitiateD <= {1};
                                        else
                                            TxSdoCs <= CanOpen.SDO_SCS_BUR;
                                            TxSdo(4 downto 3) <= (others => '0');
                                            TxSdoBlockUploadInitiateSc <= '1'; --! Server CRC support
                                            TxSdoBlockUploadInitiateS <= '1'; --! Size indicator
                                            TxSdoBlockUploadSs <= CanOpen.SDO_BLOCK_SUBCOMMAND_INITIATE(0);
                                            TxSdoBlockUploadInitiateSize <= x"{2:08X}";
                                            SegmentedSdoReadBytes := x"{2:08X}";
                                            SdoActive := true;
                                            SdoBlockSize := unsigned(RxSdoBlockUploadInitiateBlksize(6 downto 0));
                                            SdoExternal := false;
                                            SdoSegDataInternal := {3};
                                            SdoSequenceNumber := (others => '0');
                                        end if;
""".format(n, zero_fill(32 - obj.get("bit_length")) + data, 4 - n, zero_fill(56 - obj.get("bit_length")) + data))
    fp.write("""                                    when others =>
                                        TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                        TxSdo(4 downto 0) <= (others => '0');
                                        TxSdoInitiateMuxIndex <= RxSdoInitiateMuxIndex;
                                        TxSdoInitiateMuxSubIndex <= RxSdoInitiateMuxSubIndex;
                                        TxSdoAbortCode <= CanOpen.SDO_ABORT_DNE;
                                        SdoExternal := false;
                                        SegmentedSdoReadDataEnable <= '0';
                                        SdoActive := false;
                                        SdoBlockMode := false;
                                        SdoPending := false;                                
                                end case;
                            end if;
                        end if;
                        SdoInterrupt <= '1';
                    elsif SdoActive then
                        if RxSdoBlockUploadCs = CanOpen.SDO_BLOCK_SUBCOMMAND_START then
                            SdoBlockCrc := (others => '0'); --! Initialize CRC
                            SdoBlockMode := true;
                            SdoPending := true;
                        elsif RxSdoBlockUploadCs = CanOpen.SDO_BLOCK_SUBCOMMAND_RESPONSE then
                            if unsigned(RxSdoBlockUploadSubBlockAckseq(6 downto 0)) /= SdoSequenceNumber then --! ackseq check
                                TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                TxSdo(4 downto 0) <= (others => '0');
                                TxSdoInitiateMuxIndex <= SdoMux(23 downto 8);
                                TxSdoInitiateMuxSubIndex <= SdoMux(7 downto 0);
                                TxSdoAbortCode <= CanOpen.SDO_ABORT_SEQNO;
                                SdoExternal := false;
                                SegmentedSdoReadDataEnable <= '0';
                                SdoInterrupt <= '1';
                                SdoActive := false;
                                SdoBlockMode := false;
                                SdoPending := false;
                            elsif TxSdoBlockUploadSubBlockC = '1' then --! Complete
                                TxSdoCs <= CanOpen.SDO_SCS_BUR;
                                TxSdoBlockUploadEndN <= std_logic_vector(resize(7 - SegmentedSdoReadBytes, 3));
                                TxSdo(1) <= CanOpen.SDO_BLOCK_SUBCOMMAND_END(1);
                                TxSdoBlockUploadSs <= CanOpen.SDO_BLOCK_SUBCOMMAND_END(0);
                                TxSdoBlockUploadEndCrc <= SdoBlockCrc;
                                TxSdo(63 downto 24) <= (others => '0');
                                SdoInterrupt <= '1';
                                SdoActive := false;
                            elsif RxSdoBlockUploadSubBlockBlksize(7) = '1' or RxSdoBlockUploadSubBlockBlksize(6 downto 0) = b"0000000" then
                                TxSdoCs <= CanOpen.SDO_CS_ABORT;
                                TxSdo(4 downto 0) <= (others => '0');
                                TxSdoInitiateMuxIndex <= SdoMux(23 downto 8);
                                TxSdoInitiateMuxSubIndex <= SdoMux(7 downto 0);
                                TxSdoAbortCode <= CanOpen.SDO_ABORT_BLKSIZE;
                                SdoExternal := false;
                                SegmentedSdoReadDataEnable <= '0';
                                SdoInterrupt <= '1';
                                SdoActive := false;
                                SdoBlockMode := false;
                                SdoPending := false;
                            else
                                SdoBlockSize := unsigned(RxSdoBlockUploadSubBlockBlksize(6 downto 0));
                                SdoBlockMode := true;
                                SdoPending := true;
                                SdoSequenceNumber := (others => '0');
                            end if;
                        elsif RxSdoBlockUploadCs = CanOpen.SDO_BLOCK_SUBCOMMAND_END then
                            SdoActive := false;
                        end if;
                    else --! SDO Block Upload was not initialized
                        TxSdoCs <= CanOpen.SDO_CS_ABORT;
                        TxSdo(4 downto 0) <= (others => '0');
                        TxSdoInitiateMuxIndex <= (others => '0');
                        TxSdoInitiateMuxSubIndex <= (others => '0');
                        TxSdoAbortCode <= CanOpen.SDO_ABORT_CS; --! Unexpected subcommand
                        SdoExternal := false;
                        SegmentedSdoReadDataEnable <= '0';
                        SdoInterrupt <= '1';
                        SdoActive := false;
                        SdoBlockMode := false;
                        SdoPending := false;
                    end if;
                else
                    TxSdoCs <= CanOpen.SDO_CS_ABORT;
                    TxSdo(4 downto 0) <= (others => '0');
                    TxSdoInitiateMuxIndex <= (others => '0');
                    TxSdoInitiateMuxSubIndex <= (others => '0');
                    TxSdoAbortCode <= CanOpen.SDO_ABORT_CS;
                    SdoExternal := false;
                    SegmentedSdoReadDataEnable <= '0';
                    SdoInterrupt <= '1';
                    SdoActive := false;
                    SdoBlockMode := false;
                    SdoPending := false;
                end if;
            elsif CurrentState = STATE_SDO_TX then
                SdoInterrupt <= '0';
            elsif SdoPending then
                if SdoSegDataValid = '1' then
                    SegmentedSdoReadDataEnable <= '0';
                elsif SdoInterrupt = '0' then
                    SegmentedSdoReadDataEnable <= '1';
                end if;
                if SdoSegDataValid = '1' and SdoInterrupt = '0' then
                    SdoPending := false;
                    if SdoBlockMode then
                        SdoSequenceNumber := SdoSequenceNumber + 1;
                        if SegmentedSdoReadBytes > 7 then
                            SdoBlockCrc := CanOpen.Crc16(SdoSegData, SdoBlockCrc, 7);
                            TxSdoBlockUploadSubBlockC <= '0';
                            SegmentedSdoReadBytes := SegmentedSdoReadBytes - 7;
                            if SdoSequenceNumber = SdoBlockSize then
                                SdoBlockMode := false;
                            else
                                SdoPending := true;
                            end if;
                        else
                            SdoBlockCrc := CanOpen.Crc16(SdoSegData, SdoBlockCrc, to_integer(SegmentedSdoReadBytes));
                            TxSdoBlockUploadSubBlockC <= '1';
                            SdoExternal := false;
                            SdoBlockMode := false;
                        end if;
                        TxSdoBlockUploadSubBlockSeqno <= std_logic_vector(SdoSequenceNumber);
                        TxSdoBlockUploadSubBlockSegData <= SdoSegData;
                    else
                        TxSdoUploadSegmentT <= SdoToggle;
                        if SegmentedSdoReadBytes > 7 then
                            TxSdoUploadSegmentN <= (others => '0');
                            TxSdoUploadSegmentC <= '0';
                            SegmentedSdoReadBytes := SegmentedSdoReadBytes - 7;
                            SdoToggle := not SdoToggle;
                        else
                            TxSdoUploadSegmentN <= std_logic_vector(resize(7 - SegmentedSdoReadBytes, TxSdoUploadSegmentN'length));
                            TxSdoUploadSegmentC <= '1';
                            SegmentedSdoReadBytes := (others => '0');
                            SdoExternal := false;
                            SdoActive := false;
                        end if;
                        TxSdoUploadSegmentSegData <= SdoSegData;
                    end if;
                    SdoInterrupt <= '1';
                end if;
            end if;
        end if;
        SegmentedSdoMux <= SdoMux;
        if SdoExternal then
            SegmentedSdoReadEnable <= '1';
        else
            SegmentedSdoReadEnable <= '0';
        end if;
    end process;
""")
    if not segmented_sdo:
        fp.write("""    SegmentedSdoData <= (others => '0');
    SegmentedSdoDataValid <= '0';
""")
else:
    fp.write("""    SdoInterrupt <= '0';
    TxSdo <= (others => '0');
""")

fp.write("""
    --! Object dictionary communication profile area assignments
""")
if 0x100500 in objects:
    fp.write("    Sync_ob <= '1' when CurrentState = STATE_CAN_RX_READ and RxFrame_q.Ide = " + objects.get(0x100500).get("name") + "(29) and unsigned(RxFrame_q.Id(10 downto 0)) = " + objects.get(0x100500).get("name") + "(10 downto 0) else '0';\n")
else:
    fp.write("    Sync_ob <= '0';\n")
fp.write("""    CommunicationError_ob <= '1' when CanBus."="(CanStatus_ob.State, CanBus.STATE_BUS_OFF) or CanStatus_ob.Overflow = '1' or HeartbeatConsumerError = '1' else '0';\n""")
for mux in objects:
    obj = objects.get(mux)
    if mux >= 0x200000 or obj in port_signals: continue
    # Handle special cases
    if mux == 0x100100: # Error register
        fp.write("""    {0}(0) <= ErrorRegister(0);
    {0}(1) <= ErrorRegister(1);
    {0}(2) <= ErrorRegister(2);
    {0}(3) <= ErrorRegister(3);
    {0}(4) <= CommunicationError_ob;
    {0}(5) <= ErrorRegister(5);
    {0}(6) <= '0'; --! reserved (always 0)
    {0}(7) <= ErrorRegister(7);
""".format(objects.get(0x100100).get("name")))
        continue;
    if mux == 0x102100: continue #Store EDS
    if obj.get("access_type") == "const": continue # Constant values assigned in declaration
    if obj.get("access_type") == "rw":
        if obj.get("data_type").startswith("std_logic"):
            assignment = "RxSdoDownloadInitiateData"
            if obj.get("data_type") == "std_logic":
                assignment += "(0)"
        else:
            assignment = re.sub("(\w+)\(", r"\1(RxSdoDownloadInitiateData(", obj.get("data_type")) + ")"
        fp.write("""    process (Clock, Reset_n)
    begin
        if Reset_n = '0' then
            {0} <= {1};
        elsif rising_edge(Clock) then
            if CurrentState = STATE_RESET_COMM then
                {0} <= {1};
            elsif CurrentState = STATE_SDO_TX and TxSdoCs = CanOpen.SDO_SCS_IDR and TxSdoInitiateMuxIndex = x"{2:04X}" and TxSdoInitiateMuxSubIndex = x"{3:02X}" then
                {0} <= {4};
            end if;
        end if;
    end process;
""".format(obj.get("name"), obj.get("default_value"), mux >> 8, mux & 0xFF, assignment))
    else: # obj.access_type == "ro"
        fp.write("    " + obj.get("name") + " <= " + obj.get("default_value") + ";\n")

fp.write("""
    --! Remaining object dictionary assignments
""")
for mux in objects:
    if mux < 0x200000: continue
    obj = objects.get(mux)
    if obj.get("access_type") not in ["rw", "wo"]: continue
    if obj.get("data_type").startswith("std_logic"):
        assignment = "RxSdoDownloadInitiateData"
        if obj.get("data_type") == "std_logic":
             assignment += "(0)"
    else:
        assignment = re.sub("(\w+)\(", r"\1(RxSdoDownloadInitiateData(", obj.get("data_type")) + ")"
    limit_check = ""
    if obj.get("low_limit") is not None:
        limit_check += " and {} >= {}".format(assignment, obj.get("low_limit"))
    if obj.get("high_limit") is not None:
        limit_check += " and {} >= {}".format(assignment, obj.get("high_limit"))
    if obj.get("default_value") is None:
        raise Exception("DefaultValue is required for mux 0x{:06}".format(mux))
    if obj.get("access_type") == "rw":
        fp.write("""    process (Clock, Reset_n)
    begin
        if Reset_n = '0' then
            {0} <= {1};
        elsif rising_edge(Clock) then
            if CurrentState = STATE_RESET_APP then
              {0} <= {1};
            elsif CurrentState = STATE_SDO_TX and TxSdoCs = CanOpen.SDO_SCS_IDR and TxSdoInitiateMuxIndex = x"{2:04X}" and TxSdoInitiateMuxSubIndex = x"{3:02X}" then
               {0} <= {4};
            end if;
        end if;
    end process;
""".format(format_signal(obj.get("parameter_name"), suffix="_q\\"), obj.get("default_value"), mux >> 8, mux & 0xFF, assignment))
    else: # obj.get("access_type") == "wo"
        fp.write("""    process (Clock, Reset_n)
    begin
        if Reset_n = '0' then
            {0} <= {1};
            {2} <= '0';
        elsif rising_edge(Clock) then
            if CurrentState = STATE_SDO_TX and TxSdoCs = Canopen.SDO_SCS_IDR and TxSdoInitiateMuxIndex = x"{3:04X}" and TxSdoInitiateMuxSubIndex = x"{4:02X}" then
                {0} <= {5};
                {2} <= '1';
            else
                {0} <= {1};
                {2} <= '0';
            end if;
        end if;
    end process;
""".format(obj.get("name"), obj.get("default_value"), format_signal(obj.get("parameter_name"), suffix="_strb\\"), mux >> 8, mux & 0xFF, assignment))
fp.write("""    --! Output port assignments from buffers)
""")
for mux in objects:
    if mux < 0x200000: continue
    obj = objects.get(mux)
    if obj.get("access_type") != "rw": continue
    fp.write("    {} <= {};\n".format(obj.get("name"), format_signal(obj.get("parameter_name"), suffix="_q\\")))

fp.write("""
end Behavioral;
""")
fp.write("""
--! Component declaration template
--    """ + "\n--    ".join(template.format("component", entity_name, "" if len(port_signals) == 0 else ";").split("\n")))
fp.write("\n\n")
fp.write("""--! Component instantiation template
--    CanOpenController : """ + entity_name + """
--        generic map (
--            CLOCK_FREQUENCY => CLOCK_FREQUENCY
--        )
--        port map (
--            Clock => Clock,
--            Reset_n => Reset_n,
--            CanRx => CanRx,
--            CanTx => CanTx,
--            CanStatus => CanStatus,
--            NodeId => NodeId,
--            ErrorRegister => ErrorRegister, --! Bits 5 and 6 are ignored
--            NmtState => NmtState,
--            CommunicationError => CommunicationError, --! Bit 5 of CANopen Error Register
--""" + ",\n--".join(map(lambda signal: "            {0} => {0}".format(signal.get("name")), port_signals)) + """
--        );""")
