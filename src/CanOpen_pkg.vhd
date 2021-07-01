library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    
package CanOpen is
    ------------------------------------------------------------
    --! TYPES
    ------------------------------------------------------------
    type TimeOfDay is record
        Milliseconds    : unsigned(27 downto 0);
        Days            : unsigned(15 downto 0);
    end record TimeOfDay;
    
    type NodeIdArray is array (integer range <>) of std_logic_vector(6 downto 0);
    
--    type NmtState is (
--        NMT_STATE_INITIALISATION,
--        NMT_STATE_PREOPERATIONAL,
--        NMT_STATE_OPERATIONAL,
--        NMT_STATE_STOPPED
--    );

--    ... needs this ...

--    attribute Encoding  : std_logic_vector(6 downto 0);
--    attribute Encoding of NMT_STATE_INITIALISATION[return NmtState] : literal is b"0000000";
--    attribute Encoding of NMT_STATE_PREOPERATIONAL[return NmtState] : literal is b"0000100";
--    attribute Encoding of NMT_STATE_OPERATIONAL[return NmtState]    : literal is b"0000101";
--    attribute Encoding of NMT_STATE_STOPPED[return NmtState]        : literal is b"1111111";

--    NmtStateValue <= NodeNmtState'Encoding; --! Usage

--    ... or this ...

--    type NmtStateLookup is array(NmtState) of std_logic_vector(6 downto 0);

--    constant NMT_STATE_LOOKUP   : NmtStateLookup := (
--        NMT_STATE_INITIALISATION    => b"0000000",
--        NMT_STATE_STOPPED           => b"0000100",
--        NMT_STATE_OPERATIONAL       => b"0000101",
--        NMT_STATE_PREOPERATIONAL    => b"1111111"
--    );

--    NmtStateValue <= NMT_STATE_LOOKUP(NodeNmtState); --! Usage

    ------------------------------------------------------------
    --! FUNCTIONS
    ------------------------------------------------------------
    function to_std_logic_vector(X: TimeOfDay)
        return std_logic_vector;
        
    --! CRC-16-CCITT/XMODEM algorithm for SDO block upload
    function Crc16 (
        Data: std_logic_vector(55 downto 0);
        Crc:  std_logic_vector(15 downto 0);
        Bytes: integer range 0 to 7
    )
    return std_logic_vector;

    ------------------------------------------------------------
    --! CONSTANTS
    ------------------------------------------------------------
    --! CANopen function codes per CiA 301
    constant FUNCTION_CODE_NMT                      : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_SYNC                     : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_EMCY                     : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_TIME                     : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_TPDO1                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_RPDO1                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_TPDO2                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_RPDO2                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_TPDO3                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_RPDO3                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_TPDO4                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_RPDO4                    : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_SDO_TX                   : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_SDO_RX                   : std_logic_vector(3 downto 0);
    constant FUNCTION_CODE_NMT_ERROR_CONTROL        : std_logic_vector(3 downto 0);
    
    constant BROADCAST_NODE_ID          : std_logic_vector(6 downto 0);
        
    --! CANopen NMT commands per CiA 301
    constant NMT_NODE_CONTROL           : std_logic_vector(6 downto 0);
    constant NMT_GFC                    : std_logic_vector(6 downto 0);
    constant NMT_MASTER_NODE_ID         : std_logic_vector(6 downto 0);
    
    --! CANopen NMT node control commands per CiA 301
    constant NMT_NODE_CONTROL_OPERATIONAL       : std_logic_vector(7 downto 0);
    constant NMT_NODE_CONTROL_STOPPED           : std_logic_vector(7 downto 0);
    constant NMT_NODE_CONTROL_PREOPERATIONAL    : std_logic_vector(7 downto 0);
    constant NMT_NODE_CONTROL_RESET_APP         : std_logic_vector(7 downto 0);
    constant NMT_NODE_CONTROL_RESET_COMM        : std_logic_vector(7 downto 0);
    
    --! CANopen NMT states per CiA 301
    constant NMT_STATE_INITIALISATION   : std_logic_vector(6 downto 0);
    constant NMT_STATE_STOPPED          : std_logic_vector(6 downto 0);
    constant NMT_STATE_OPERATIONAL      : std_logic_vector(6 downto 0);
    constant NMT_STATE_PREOPERATIONAL   : std_logic_vector(6 downto 0);
    
    --! CANopen SDO Command Specifiers per CiA 301
    constant SDO_CS_ABORT               : std_logic_vector(2 downto 0); --! Abort transfer
    
    --! CANopen SDO Client Command Specifiers (CCSs) per CiA 301
    constant SDO_CCS_DSR                : std_logic_vector(2 downto 0); --! Download segment request
    constant SDO_CCS_IDR                : std_logic_vector(2 downto 0); --! Initiate download request
    constant SDO_CCS_IUR                : std_logic_vector(2 downto 0); --! Intiate upload request
    constant SDO_CCS_USR                : std_logic_vector(2 downto 0); --! Upload segment request
    constant SDO_CCS_BUR                : std_logic_vector(2 downto 0); --! Block upload request
    constant SDO_CCS_BDR                : std_logic_vector(2 downto 0); --! Block download request
    
    --! CANopen SDO Server Command Specifiers (SCSs) per CiA 301
    constant SDO_SCS_USR                : std_logic_vector(2 downto 0); --! Upload segment response
    constant SDO_SCS_DSR                : std_logic_vector(2 downto 0); --! Download segment response
    constant SDO_SCS_IUR                : std_logic_vector(2 downto 0); --! Initiate upload response
    constant SDO_SCS_IDR                : std_logic_vector(2 downto 0); --! Initiate download response
    constant SDO_SCS_BDR                : std_logic_vector(2 downto 0); --! Block download response
    constant SDO_SCS_BUR                : std_logic_vector(2 downto 0); --! Block upload response
    
    --! CANopen SDO Block Client and Server Subcommands
    constant SDO_BLOCK_SUBCOMMAND_INITIATE  : std_logic_vector(1 downto 0); --! Block subcommand initiate (upload/download request/response)
    constant SDO_BLOCK_SUBCOMMAND_END       : std_logic_vector(1 downto 0); --! Block subcommand end (upload/download request/response)
    constant SDO_BLOCK_SUBCOMMAND_RESPONSE  : std_logic_vector(1 downto 0); --! Block subcommand response (upload/download response)
    constant SDO_BLOCK_SUBCOMMAND_START     : std_logic_vector(1 downto 0); --! Block subcommand start (upload request)
    
    --! CANopen SDO abort codes per CiA 301
    constant SDO_ABORT_TOGGLE           : std_logic_vector(31 downto 0); --! Toggle bit not alternated
    constant SDO_ABORT_CS               : std_logic_vector(31 downto 0); --! Client/server command specifier not valid or unknown
    constant SDO_ABORT_BLKSIZE          : std_logic_vector(31 downto 0); --! Invalid block size (block mode only)
    constant SDO_ABORT_SEQNO            : std_logic_vector(31 downto 0); --! Invalid sequence number (block mode only)
    constant SDO_ABORT_CRC              : std_logic_vector(31 downto 0); --! CRC error (block mode only)
    constant SDO_ABORT_ACCESS           : std_logic_vector(31 downto 0); --! Unsupported access to an object
    constant SDO_ABORT_WO               : std_logic_vector(31 downto 0); --! Attempt to read a write only object
    constant SDO_ABORT_RO               : std_logic_vector(31 downto 0); --! Attempt to write a read only object
    constant SDO_ABORT_DNE              : std_logic_vector(31 downto 0); --! Object does not exist in the object dictionary
    constant SDO_ABORT_PARAM_LENGTH     : std_logic_vector(31 downto 0); --! Data type does not match, length of service parameter does not match
    constant SDO_ABORT_PARAM_LONG       : std_logic_vector(31 downto 0); --! Data type does not match, length of service parameter too high
    constant SDO_ABORT_PARAM_SHORT      : std_logic_vector(31 downto 0); --! Data type does not match, length of service parameter too low
    constant SDO_ABORT_PARAM_INVALID    : std_logic_vector(31 downto 0); --! Invalid value for parameter (download only)
    constant SDO_ABORT_PARAM_HIGH       : std_logic_vector(31 downto 0); --! Value of parameter written too high (download only)
    constant SDO_ABORT_PARAM_LOW        : std_logic_vector(31 downto 0); --! Value of parameter written too low (download only)
    constant SDO_ABORT_GENERAL          : std_logic_vector(31 downto 0); --! General error
    constant SDO_ABORT_NO_DATA          : std_logic_vector(31 downto 0); --! No data available
    
    --! CANopen Object Dictionary (OD)
    --! Mandatory indices per CiA 301
    constant ODI_DEVICE_TYPE            : std_logic_vector(23 downto 0);
    constant ODI_ERROR                  : std_logic_vector(23 downto 0);
    constant ODI_ID_LENGTH              : std_logic_vector(23 downto 0);
    constant ODI_ID_VENDOR              : std_logic_vector(23 downto 0);
    constant ODI_VERSION_COUNT          : std_logic_vector(23 downto 0);
    constant ODI_VERSION_1              : std_logic_vector(23 downto 0);
    constant ODI_VERSION_2              : std_logic_vector(23 downto 0);
    --! Conditional/optional indices per CiA 301
    constant ODI_SYNC                   : std_logic_vector(23 downto 0); --! If PDO communication on a synchronous base
    constant ODI_TIME                   : std_logic_vector(23 downto 0); --! If TIME producer/consumer
    constant ODI_EMCY                   : std_logic_vector(23 downto 0); --! If Emergency supported
    constant ODI_HEARTBEAT_CONSUMER_TIME : std_logic_vector(23 downto 0); --! If Heartbeat consumer
    constant ODI_HEARTBEAT_PRODUCER_TIME : std_logic_vector(23 downto 0); --! If Heartbeat Protocol
    constant ODI_ID_PRODUCT             : std_logic_vector(23 downto 0);
    constant ODI_ID_REVISION            : std_logic_vector(23 downto 0);
    constant ODI_ID_SERIAL              : std_logic_vector(23 downto 0);
    constant ODI_SYNC_COUNTER_OVERFLOW  : std_logic_vector(23 downto 0); --! If synchronous counter
    constant ODI_STORE_EDS              : std_logic_vector(23 downto 0);
    constant ODI_STORE_FORMAT           : std_logic_vector(23 downto 0);
    constant ODI_ERROR_BEHAVIOR         : std_logic_vector(23 downto 0);
    constant ODI_SDO_SERVER_COUNT       : std_logic_vector(23 downto 0); --! If SDO
    constant ODI_SDO_SERVER_RX_ID       : std_logic_vector(23 downto 0); --! CAN ID used for SDO client-to-server
    constant ODI_SDO_SERVER_TX_ID       : std_logic_vector(23 downto 0); --! CAN ID used for SDO server-to-client
    constant ODI_GFC                    : std_logic_vector(23 downto 0); --! Global Failsafe Command
    constant ODI_TPDO1_COMM_COUNT       : std_logic_vector(23 downto 0); --! If PDO1 TX
    constant ODI_TPDO1_COMM_ID          : std_logic_vector(23 downto 0); --! CAN ID used for TPDO1 (0x180 + Address)
    constant ODI_TPDO1_COMM_TYPE        : std_logic_vector(23 downto 0); --! Transmission (trigger) type for TPDO1
    constant ODI_TPDO2_COMM_COUNT       : std_logic_vector(23 downto 0); --! If PDO2 TX
    constant ODI_TPDO2_COMM_ID          : std_logic_vector(23 downto 0); --! CAN ID used for TPDO2 (0x181 + Address)
    constant ODI_TPDO2_COMM_TYPE        : std_logic_vector(23 downto 0); --! Transmission (trigger) type for TPDO2
    constant ODI_TPDO3_COMM_COUNT       : std_logic_vector(23 downto 0); --! If PDO3 TX
    constant ODI_TPDO3_COMM_ID          : std_logic_vector(23 downto 0); --! CAN ID used for TPDO3 (0x182 + Address)
    constant ODI_TPDO3_COMM_TYPE        : std_logic_vector(23 downto 0); --! Transmission (trigger) type for TPDO3
    constant ODI_TPDO4_COMM_COUNT       : std_logic_vector(23 downto 0); --! If PDO4 TX
    constant ODI_TPDO4_COMM_ID          : std_logic_vector(23 downto 0); --! CAN ID used for TPDO4 (0x183 + Address)
    constant ODI_TPDO4_COMM_TYPE        : std_logic_vector(23 downto 0); --! Transmission (trigger) type for TPDO4
    constant ODI_TPDO1_MAPPING          : std_logic_vector(23 downto 0);
    constant ODI_TPDO2_MAPPING          : std_logic_vector(23 downto 0);
    constant ODI_TPDO3_MAPPING          : std_logic_vector(23 downto 0);
    constant ODI_TPDO4_MAPPING          : std_logic_vector(23 downto 0);
    constant ODI_NMT_STARTUP            : std_logic_vector(23 downto 0);
    
    --! Emergency error codes
    constant EMCY_EEC_NO_ERROR          : std_logic_vector(15 downto 0);
    constant EMCY_EEC_GENERIC           : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CURRENT           : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CURRENT_INPUT     : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CURRENT_INSIDE    : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CURRENT_OUTPUT    : std_logic_vector(15 downto 0);
    constant EMCY_EEC_VOLTAGE           : std_logic_vector(15 downto 0);
    constant EMCY_EEC_VOLTAGE_MAINS     : std_logic_vector(15 downto 0);
    constant EMCY_EEC_VOLTAGE_INSIDE    : std_logic_vector(15 downto 0);
    constant EMCY_EEC_VOLTAGE_OUTPUT    : std_logic_vector(15 downto 0);
    constant EMCY_EEC_TEMPERATURE       : std_logic_vector(15 downto 0);
    constant EMCY_EEC_TEMPERATURE_AMBIENT : std_logic_vector(15 downto 0);
    constant EMCY_EEC_TEMPERATURE_DEVICE : std_logic_vector(15 downto 0);
    constant EMCY_EEC_HARDWARE          : std_logic_vector(15 downto 0);
    constant EMCY_EEC_SOFTWARE          : std_logic_vector(15 downto 0);
    constant EMCY_EEC_SOFTWARE_INTERNAL : std_logic_vector(15 downto 0);
    constant EMCY_EEC_SOFTWARE_USER     : std_logic_vector(15 downto 0);
    constant EMCY_EEC_SOFTWARE_DATA_SET : std_logic_vector(15 downto 0);
    constant EMCY_EEC_ADDITIONAL_MODULES : std_logic_vector(15 downto 0);
    constant EMCY_EEC_MONITORING        : std_logic_vector(15 downto 0);
    constant EMCY_EEC_COMMUNICATION     : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CAN_OVERRUN       : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CAN_ERROR_PASSIVE : std_logic_vector(15 downto 0);
    constant EMCY_EEC_HEARTBEAT         : std_logic_vector(15 downto 0);
    constant EMCY_EEC_BUS_OFF_RECOVERY  : std_logic_vector(15 downto 0);
    constant EMCY_EEC_CAN_ID_COLLISION  : std_logic_vector(15 downto 0);
    constant EMCY_EEC_PROTOCOL          : std_logic_vector(15 downto 0);
    constant EMCY_EEC_PDO_NOT_PROCESSED : std_logic_vector(15 downto 0);
    constant EMCY_EEC_PDO_LENGTH_EXCEEDED : std_logic_vector(15 downto 0);
    constant EMCY_EEC_DAM_MPDO_NA       : std_logic_vector(15 downto 0);
    constant EMCY_EEC_SYNC_LENGTH       : std_logic_vector(15 downto 0);
    constant EMCY_EEC_RPDO_TIMEOUT      : std_logic_vector(15 downto 0);
    constant EMCY_EEC_EXTERNAL          : std_logic_vector(15 downto 0);
    constant EMCY_EEC_ADDITIONAL_FUNCTIONS : std_logic_vector(15 downto 0);
    constant EMCY_EEC_DEVICE_SPECIFIC   : std_logic_vector(15 downto 0);
    
    --! CANopen Device Profiles
    constant DEVICE_PROFILE_GENERIC_IO      : std_logic_vector(15 downto 0);
end package CanOpen;

package body CanOpen is
    ------------------------------------------------------------
    --! FUNCTIONS
    ------------------------------------------------------------
    function to_std_logic_vector(X: TimeOfDay)
        return std_logic_vector is
    begin
        return std_logic_vector(X.Days) & x"0" & std_logic_vector(X.Milliseconds);
    end to_std_logic_vector;
    
    --! CRC-16-CCITT/XMODEM algorithm for SDO block upload
    function Crc16 (
        Data: std_logic_vector(55 downto 0);
        Crc:  std_logic_vector(15 downto 0);
        Bytes: integer range 0 to 7
    )
    return std_logic_vector is
        variable d:      std_logic_vector(55 downto 0);
        variable c:      std_logic_vector(15 downto 0);
        variable NextCrc: std_logic_vector(15 downto 0);
    begin
        c := Crc;
        case Bytes is
            when 1 =>
                d := Data;
                NextCrc(0) := d(4) xor d(0) xor c(8) xor c(12);
                NextCrc(1) := d(5) xor d(1) xor c(9) xor c(13);
                NextCrc(2) := d(6) xor d(2) xor c(10) xor c(14);
                NextCrc(3) := d(7) xor d(3) xor c(11) xor c(15);
                NextCrc(4) := d(4) xor c(12);
                NextCrc(5) := d(5) xor d(4) xor d(0) xor c(8) xor c(12) xor c(13);
                NextCrc(6) := d(6) xor d(5) xor d(1) xor c(9) xor c(13) xor c(14);
                NextCrc(7) := d(7) xor d(6) xor d(2) xor c(10) xor c(14) xor c(15);
                NextCrc(8) := d(7) xor d(3) xor c(0) xor c(11) xor c(15);
                NextCrc(9) := d(4) xor c(1) xor c(12);
                NextCrc(10) := d(5) xor c(2) xor c(13);
                NextCrc(11) := d(6) xor c(3) xor c(14);
                NextCrc(12) := d(7) xor d(4) xor d(0) xor c(4) xor c(8) xor c(12) xor c(15);
                NextCrc(13) := d(5) xor d(1) xor c(5) xor c(9) xor c(13);
                NextCrc(14) := d(6) xor d(2) xor c(6) xor c(10) xor c(14);
                NextCrc(15) := d(7) xor d(3) xor c(7) xor c(11) xor c(15);
            when 2 =>
                d := x"0000000000" & Data(7 downto 0) & Data(15 downto 8);
                NextCrc(0) := d(12) xor d(11) xor d(8) xor d(4) xor d(0) xor c(0) xor c(4) xor c(8) xor c(11) xor c(12);
                NextCrc(1) := d(13) xor d(12) xor d(9) xor d(5) xor d(1) xor c(1) xor c(5) xor c(9) xor c(12) xor c(13);
                NextCrc(2) := d(14) xor d(13) xor d(10) xor d(6) xor d(2) xor c(2) xor c(6) xor c(10) xor c(13) xor c(14);
                NextCrc(3) := d(15) xor d(14) xor d(11) xor d(7) xor d(3) xor c(3) xor c(7) xor c(11) xor c(14) xor c(15);
                NextCrc(4) := d(15) xor d(12) xor d(8) xor d(4) xor c(4) xor c(8) xor c(12) xor c(15);
                NextCrc(5) := d(13) xor d(12) xor d(11) xor d(9) xor d(8) xor d(5) xor d(4) xor d(0) xor c(0) xor c(4) xor c(5) xor c(8) xor c(9) xor c(11) xor c(12) xor c(13);
                NextCrc(6) := d(14) xor d(13) xor d(12) xor d(10) xor d(9) xor d(6) xor d(5) xor d(1) xor c(1) xor c(5) xor c(6) xor c(9) xor c(10) xor c(12) xor c(13) xor c(14);
                NextCrc(7) := d(15) xor d(14) xor d(13) xor d(11) xor d(10) xor d(7) xor d(6) xor d(2) xor c(2) xor c(6) xor c(7) xor c(10) xor c(11) xor c(13) xor c(14) xor c(15);
                NextCrc(8) := d(15) xor d(14) xor d(12) xor d(11) xor d(8) xor d(7) xor d(3) xor c(3) xor c(7) xor c(8) xor c(11) xor c(12) xor c(14) xor c(15);
                NextCrc(9) := d(15) xor d(13) xor d(12) xor d(9) xor d(8) xor d(4) xor c(4) xor c(8) xor c(9) xor c(12) xor c(13) xor c(15);
                NextCrc(10) := d(14) xor d(13) xor d(10) xor d(9) xor d(5) xor c(5) xor c(9) xor c(10) xor c(13) xor c(14);
                NextCrc(11) := d(15) xor d(14) xor d(11) xor d(10) xor d(6) xor c(6) xor c(10) xor c(11) xor c(14) xor c(15);
                NextCrc(12) := d(15) xor d(8) xor d(7) xor d(4) xor d(0) xor c(0) xor c(4) xor c(7) xor c(8) xor c(15);
                NextCrc(13) := d(9) xor d(8) xor d(5) xor d(1) xor c(1) xor c(5) xor c(8) xor c(9);
                NextCrc(14) := d(10) xor d(9) xor d(6) xor d(2) xor c(2) xor c(6) xor c(9) xor c(10);
                NextCrc(15) := d(11) xor d(10) xor d(7) xor d(3) xor c(3) xor c(7) xor c(10) xor c(11);
            when 3 =>
                d := x"00000000" & Data(7 downto 0) & Data(15 downto 8) & Data(23 downto 16);
                NextCrc(0) := d(22) xor d(20) xor d(19) xor d(12) xor d(11) xor d(8) xor d(4) xor d(0) xor c(0) xor c(3) xor c(4) xor c(11) xor c(12) xor c(14);
                NextCrc(1) := d(23) xor d(21) xor d(20) xor d(13) xor d(12) xor d(9) xor d(5) xor d(1) xor c(1) xor c(4) xor c(5) xor c(12) xor c(13) xor c(15);
                NextCrc(2) := d(22) xor d(21) xor d(14) xor d(13) xor d(10) xor d(6) xor d(2) xor c(2) xor c(5) xor c(6) xor c(13) xor c(14);
                NextCrc(3) := d(23) xor d(22) xor d(15) xor d(14) xor d(11) xor d(7) xor d(3) xor c(3) xor c(6) xor c(7) xor c(14) xor c(15);
                NextCrc(4) := d(23) xor d(16) xor d(15) xor d(12) xor d(8) xor d(4) xor c(0) xor c(4) xor c(7) xor c(8) xor c(15);
                NextCrc(5) := d(22) xor d(20) xor d(19) xor d(17) xor d(16) xor d(13) xor d(12) xor d(11) xor d(9) xor d(8) xor d(5) xor d(4) xor d(0) xor c(0) xor c(1) xor c(3) xor c(4) xor c(5) xor c(8) xor c(9) xor c(11) xor c(12) xor c(14);
                NextCrc(6) := d(23) xor d(21) xor d(20) xor d(18) xor d(17) xor d(14) xor d(13) xor d(12) xor d(10) xor d(9) xor d(6) xor d(5) xor d(1) xor c(1) xor c(2) xor c(4) xor c(5) xor c(6) xor c(9) xor c(10) xor c(12) xor c(13) xor c(15);
                NextCrc(7) := d(22) xor d(21) xor d(19) xor d(18) xor d(15) xor d(14) xor d(13) xor d(11) xor d(10) xor d(7) xor d(6) xor d(2) xor c(2) xor c(3) xor c(5) xor c(6) xor c(7) xor c(10) xor c(11) xor c(13) xor c(14);
                NextCrc(8) := d(23) xor d(22) xor d(20) xor d(19) xor d(16) xor d(15) xor d(14) xor d(12) xor d(11) xor d(8) xor d(7) xor d(3) xor c(0) xor c(3) xor c(4) xor c(6) xor c(7) xor c(8) xor c(11) xor c(12) xor c(14) xor c(15);
                NextCrc(9) := d(23) xor d(21) xor d(20) xor d(17) xor d(16) xor d(15) xor d(13) xor d(12) xor d(9) xor d(8) xor d(4) xor c(0) xor c(1) xor c(4) xor c(5) xor c(7) xor c(8) xor c(9) xor c(12) xor c(13) xor c(15);
                NextCrc(10) := d(22) xor d(21) xor d(18) xor d(17) xor d(16) xor d(14) xor d(13) xor d(10) xor d(9) xor d(5) xor c(1) xor c(2) xor c(5) xor c(6) xor c(8) xor c(9) xor c(10) xor c(13) xor c(14);
                NextCrc(11) := d(23) xor d(22) xor d(19) xor d(18) xor d(17) xor d(15) xor d(14) xor d(11) xor d(10) xor d(6) xor c(2) xor c(3) xor c(6) xor c(7) xor c(9) xor c(10) xor c(11) xor c(14) xor c(15);
                NextCrc(12) := d(23) xor d(22) xor d(18) xor d(16) xor d(15) xor d(8) xor d(7) xor d(4) xor d(0) xor c(0) xor c(7) xor c(8) xor c(10) xor c(14) xor c(15);
                NextCrc(13) := d(23) xor d(19) xor d(17) xor d(16) xor d(9) xor d(8) xor d(5) xor d(1) xor c(0) xor c(1) xor c(8) xor c(9) xor c(11) xor c(15);
                NextCrc(14) := d(20) xor d(18) xor d(17) xor d(10) xor d(9) xor d(6) xor d(2) xor c(1) xor c(2) xor c(9) xor c(10) xor c(12);
                NextCrc(15) := d(21) xor d(19) xor d(18) xor d(11) xor d(10) xor d(7) xor d(3) xor c(2) xor c(3) xor c(10) xor c(11) xor c(13);
            when 4 =>
                d := x"000000" & Data(7 downto 0) & Data(15 downto 8) & Data(23 downto 16) & Data(31 downto 24);
                NextCrc(0) := d(28) xor d(27) xor d(26) xor d(22) xor d(20) xor d(19) xor d(12) xor d(11) xor d(8) xor d(4) xor d(0) xor c(3) xor c(4) xor c(6) xor c(10) xor c(11) xor c(12);
                NextCrc(1) := d(29) xor d(28) xor d(27) xor d(23) xor d(21) xor d(20) xor d(13) xor d(12) xor d(9) xor d(5) xor d(1) xor c(4) xor c(5) xor c(7) xor c(11) xor c(12) xor c(13);
                NextCrc(2) := d(30) xor d(29) xor d(28) xor d(24) xor d(22) xor d(21) xor d(14) xor d(13) xor d(10) xor d(6) xor d(2) xor c(5) xor c(6) xor c(8) xor c(12) xor c(13) xor c(14);
                NextCrc(3) := d(31) xor d(30) xor d(29) xor d(25) xor d(23) xor d(22) xor d(15) xor d(14) xor d(11) xor d(7) xor d(3) xor c(6) xor c(7) xor c(9) xor c(13) xor c(14) xor c(15);
                NextCrc(4) := d(31) xor d(30) xor d(26) xor d(24) xor d(23) xor d(16) xor d(15) xor d(12) xor d(8) xor d(4) xor c(0) xor c(7) xor c(8) xor c(10) xor c(14) xor c(15);
                NextCrc(5) := d(31) xor d(28) xor d(26) xor d(25) xor d(24) xor d(22) xor d(20) xor d(19) xor d(17) xor d(16) xor d(13) xor d(12) xor d(11) xor d(9) xor d(8) xor d(5) xor d(4) xor d(0) xor c(0) xor c(1) xor c(3) xor c(4) xor c(6) xor c(8) xor c(9) xor c(10) xor c(12) xor c(15);
                NextCrc(6) := d(29) xor d(27) xor d(26) xor d(25) xor d(23) xor d(21) xor d(20) xor d(18) xor d(17) xor d(14) xor d(13) xor d(12) xor d(10) xor d(9) xor d(6) xor d(5) xor d(1) xor c(1) xor c(2) xor c(4) xor c(5) xor c(7) xor c(9) xor c(10) xor c(11) xor c(13);
                NextCrc(7) := d(30) xor d(28) xor d(27) xor d(26) xor d(24) xor d(22) xor d(21) xor d(19) xor d(18) xor d(15) xor d(14) xor d(13) xor d(11) xor d(10) xor d(7) xor d(6) xor d(2) xor c(2) xor c(3) xor c(5) xor c(6) xor c(8) xor c(10) xor c(11) xor c(12) xor c(14);
                NextCrc(8) := d(31) xor d(29) xor d(28) xor d(27) xor d(25) xor d(23) xor d(22) xor d(20) xor d(19) xor d(16) xor d(15) xor d(14) xor d(12) xor d(11) xor d(8) xor d(7) xor d(3) xor c(0) xor c(3) xor c(4) xor c(6) xor c(7) xor c(9) xor c(11) xor c(12) xor c(13) xor c(15);
                NextCrc(9) := d(30) xor d(29) xor d(28) xor d(26) xor d(24) xor d(23) xor d(21) xor d(20) xor d(17) xor d(16) xor d(15) xor d(13) xor d(12) xor d(9) xor d(8) xor d(4) xor c(0) xor c(1) xor c(4) xor c(5) xor c(7) xor c(8) xor c(10) xor c(12) xor c(13) xor c(14);
                NextCrc(10) := d(31) xor d(30) xor d(29) xor d(27) xor d(25) xor d(24) xor d(22) xor d(21) xor d(18) xor d(17) xor d(16) xor d(14) xor d(13) xor d(10) xor d(9) xor d(5) xor c(0) xor c(1) xor c(2) xor c(5) xor c(6) xor c(8) xor c(9) xor c(11) xor c(13) xor c(14) xor c(15);
                NextCrc(11) := d(31) xor d(30) xor d(28) xor d(26) xor d(25) xor d(23) xor d(22) xor d(19) xor d(18) xor d(17) xor d(15) xor d(14) xor d(11) xor d(10) xor d(6) xor c(1) xor c(2) xor c(3) xor c(6) xor c(7) xor c(9) xor c(10) xor c(12) xor c(14) xor c(15);
                NextCrc(12) := d(31) xor d(29) xor d(28) xor d(24) xor d(23) xor d(22) xor d(18) xor d(16) xor d(15) xor d(8) xor d(7) xor d(4) xor d(0) xor c(0) xor c(2) xor c(6) xor c(7) xor c(8) xor c(12) xor c(13) xor c(15);
                NextCrc(13) := d(30) xor d(29) xor d(25) xor d(24) xor d(23) xor d(19) xor d(17) xor d(16) xor d(9) xor d(8) xor d(5) xor d(1) xor c(0) xor c(1) xor c(3) xor c(7) xor c(8) xor c(9) xor c(13) xor c(14);
                NextCrc(14) := d(31) xor d(30) xor d(26) xor d(25) xor d(24) xor d(20) xor d(18) xor d(17) xor d(10) xor d(9) xor d(6) xor d(2) xor c(1) xor c(2) xor c(4) xor c(8) xor c(9) xor c(10) xor c(14) xor c(15);
                NextCrc(15) := d(31) xor d(27) xor d(26) xor d(25) xor d(21) xor d(19) xor d(18) xor d(11) xor d(10) xor d(7) xor d(3) xor c(2) xor c(3) xor c(5) xor c(9) xor c(10) xor c(11) xor c(15);
            when 5 =>
                d := x"0000" & Data(7 downto 0) & Data(15 downto 8) & Data(23 downto 16) & Data(31 downto 24) & Data(39 downto 32);
                NextCrc(0) := d(35) xor d(33) xor d(32) xor d(28) xor d(27) xor d(26) xor d(22) xor d(20) xor d(19) xor d(12) xor d(11) xor d(8) xor d(4) xor d(0) xor c(2) xor c(3) xor c(4) xor c(8) xor c(9) xor c(11);
                NextCrc(1) := d(36) xor d(34) xor d(33) xor d(29) xor d(28) xor d(27) xor d(23) xor d(21) xor d(20) xor d(13) xor d(12) xor d(9) xor d(5) xor d(1) xor c(3) xor c(4) xor c(5) xor c(9) xor c(10) xor c(12);
                NextCrc(2) := d(37) xor d(35) xor d(34) xor d(30) xor d(29) xor d(28) xor d(24) xor d(22) xor d(21) xor d(14) xor d(13) xor d(10) xor d(6) xor d(2) xor c(0) xor c(4) xor c(5) xor c(6) xor c(10) xor c(11) xor c(13);
                NextCrc(3) := d(38) xor d(36) xor d(35) xor d(31) xor d(30) xor d(29) xor d(25) xor d(23) xor d(22) xor d(15) xor d(14) xor d(11) xor d(7) xor d(3) xor c(1) xor c(5) xor c(6) xor c(7) xor c(11) xor c(12) xor c(14);
                NextCrc(4) := d(39) xor d(37) xor d(36) xor d(32) xor d(31) xor d(30) xor d(26) xor d(24) xor d(23) xor d(16) xor d(15) xor d(12) xor d(8) xor d(4) xor c(0) xor c(2) xor c(6) xor c(7) xor c(8) xor c(12) xor c(13) xor c(15);
                NextCrc(5) := d(38) xor d(37) xor d(35) xor d(31) xor d(28) xor d(26) xor d(25) xor d(24) xor d(22) xor d(20) xor d(19) xor d(17) xor d(16) xor d(13) xor d(12) xor d(11) xor d(9) xor d(8) xor d(5) xor d(4) xor d(0) xor c(0) xor c(1) xor c(2) xor c(4) xor c(7) xor c(11) xor c(13) xor c(14);
                NextCrc(6) := d(39) xor d(38) xor d(36) xor d(32) xor d(29) xor d(27) xor d(26) xor d(25) xor d(23) xor d(21) xor d(20) xor d(18) xor d(17) xor d(14) xor d(13) xor d(12) xor d(10) xor d(9) xor d(6) xor d(5) xor d(1) xor c(1) xor c(2) xor c(3) xor c(5) xor c(8) xor c(12) xor c(14) xor c(15);
                NextCrc(7) := d(39) xor d(37) xor d(33) xor d(30) xor d(28) xor d(27) xor d(26) xor d(24) xor d(22) xor d(21) xor d(19) xor d(18) xor d(15) xor d(14) xor d(13) xor d(11) xor d(10) xor d(7) xor d(6) xor d(2) xor c(0) xor c(2) xor c(3) xor c(4) xor c(6) xor c(9) xor c(13) xor c(15);
                NextCrc(8) := d(38) xor d(34) xor d(31) xor d(29) xor d(28) xor d(27) xor d(25) xor d(23) xor d(22) xor d(20) xor d(19) xor d(16) xor d(15) xor d(14) xor d(12) xor d(11) xor d(8) xor d(7) xor d(3) xor c(1) xor c(3) xor c(4) xor c(5) xor c(7) xor c(10) xor c(14);
                NextCrc(9) := d(39) xor d(35) xor d(32) xor d(30) xor d(29) xor d(28) xor d(26) xor d(24) xor d(23) xor d(21) xor d(20) xor d(17) xor d(16) xor d(15) xor d(13) xor d(12) xor d(9) xor d(8) xor d(4) xor c(0) xor c(2) xor c(4) xor c(5) xor c(6) xor c(8) xor c(11) xor c(15);
                NextCrc(10) := d(36) xor d(33) xor d(31) xor d(30) xor d(29) xor d(27) xor d(25) xor d(24) xor d(22) xor d(21) xor d(18) xor d(17) xor d(16) xor d(14) xor d(13) xor d(10) xor d(9) xor d(5) xor c(0) xor c(1) xor c(3) xor c(5) xor c(6) xor c(7) xor c(9) xor c(12);
                NextCrc(11) := d(37) xor d(34) xor d(32) xor d(31) xor d(30) xor d(28) xor d(26) xor d(25) xor d(23) xor d(22) xor d(19) xor d(18) xor d(17) xor d(15) xor d(14) xor d(11) xor d(10) xor d(6) xor c(1) xor c(2) xor c(4) xor c(6) xor c(7) xor c(8) xor c(10) xor c(13);
                NextCrc(12) := d(38) xor d(31) xor d(29) xor d(28) xor d(24) xor d(23) xor d(22) xor d(18) xor d(16) xor d(15) xor d(8) xor d(7) xor d(4) xor d(0) xor c(0) xor c(4) xor c(5) xor c(7) xor c(14);
                NextCrc(13) := d(39) xor d(32) xor d(30) xor d(29) xor d(25) xor d(24) xor d(23) xor d(19) xor d(17) xor d(16) xor d(9) xor d(8) xor d(5) xor d(1) xor c(0) xor c(1) xor c(5) xor c(6) xor c(8) xor c(15);
                NextCrc(14) := d(33) xor d(31) xor d(30) xor d(26) xor d(25) xor d(24) xor d(20) xor d(18) xor d(17) xor d(10) xor d(9) xor d(6) xor d(2) xor c(0) xor c(1) xor c(2) xor c(6) xor c(7) xor c(9);
                NextCrc(15) := d(34) xor d(32) xor d(31) xor d(27) xor d(26) xor d(25) xor d(21) xor d(19) xor d(18) xor d(11) xor d(10) xor d(7) xor d(3) xor c(1) xor c(2) xor c(3) xor c(7) xor c(8) xor c(10);
            when 6 =>
                d := x"00" & Data(7 downto 0) & Data(15 downto 8) & Data(23 downto 16) & Data(31 downto 24) & Data(39 downto 32) & Data(47 downto 40);
                NextCrc(0) := d(42) xor d(35) xor d(33) xor d(32) xor d(28) xor d(27) xor d(26) xor d(22) xor d(20) xor d(19) xor d(12) xor d(11) xor d(8) xor d(4) xor d(0) xor c(0) xor c(1) xor c(3) xor c(10);
                NextCrc(1) := d(43) xor d(36) xor d(34) xor d(33) xor d(29) xor d(28) xor d(27) xor d(23) xor d(21) xor d(20) xor d(13) xor d(12) xor d(9) xor d(5) xor d(1) xor c(1) xor c(2) xor c(4) xor c(11);
                NextCrc(2) := d(44) xor d(37) xor d(35) xor d(34) xor d(30) xor d(29) xor d(28) xor d(24) xor d(22) xor d(21) xor d(14) xor d(13) xor d(10) xor d(6) xor d(2) xor c(2) xor c(3) xor c(5) xor c(12);
                NextCrc(3) := d(45) xor d(38) xor d(36) xor d(35) xor d(31) xor d(30) xor d(29) xor d(25) xor d(23) xor d(22) xor d(15) xor d(14) xor d(11) xor d(7) xor d(3) xor c(3) xor c(4) xor c(6) xor c(13);
                NextCrc(4) := d(46) xor d(39) xor d(37) xor d(36) xor d(32) xor d(31) xor d(30) xor d(26) xor d(24) xor d(23) xor d(16) xor d(15) xor d(12) xor d(8) xor d(4) xor c(0) xor c(4) xor c(5) xor c(7) xor c(14);
                NextCrc(5) := d(47) xor d(42) xor d(40) xor d(38) xor d(37) xor d(35) xor d(31) xor d(28) xor d(26) xor d(25) xor d(24) xor d(22) xor d(20) xor d(19) xor d(17) xor d(16) xor d(13) xor d(12) xor d(11) xor d(9) xor d(8) xor d(5) xor d(4) xor d(0) xor c(3) xor c(5) xor c(6) xor c(8) xor c(10) xor c(15);
                NextCrc(6) := d(43) xor d(41) xor d(39) xor d(38) xor d(36) xor d(32) xor d(29) xor d(27) xor d(26) xor d(25) xor d(23) xor d(21) xor d(20) xor d(18) xor d(17) xor d(14) xor d(13) xor d(12) xor d(10) xor d(9) xor d(6) xor d(5) xor d(1) xor c(0) xor c(4) xor c(6) xor c(7) xor c(9) xor c(11);
                NextCrc(7) := d(44) xor d(42) xor d(40) xor d(39) xor d(37) xor d(33) xor d(30) xor d(28) xor d(27) xor d(26) xor d(24) xor d(22) xor d(21) xor d(19) xor d(18) xor d(15) xor d(14) xor d(13) xor d(11) xor d(10) xor d(7) xor d(6) xor d(2) xor c(1) xor c(5) xor c(7) xor c(8) xor c(10) xor c(12);
                NextCrc(8) := d(45) xor d(43) xor d(41) xor d(40) xor d(38) xor d(34) xor d(31) xor d(29) xor d(28) xor d(27) xor d(25) xor d(23) xor d(22) xor d(20) xor d(19) xor d(16) xor d(15) xor d(14) xor d(12) xor d(11) xor d(8) xor d(7) xor d(3) xor c(2) xor c(6) xor c(8) xor c(9) xor c(11) xor c(13);
                NextCrc(9) := d(46) xor d(44) xor d(42) xor d(41) xor d(39) xor d(35) xor d(32) xor d(30) xor d(29) xor d(28) xor d(26) xor d(24) xor d(23) xor d(21) xor d(20) xor d(17) xor d(16) xor d(15) xor d(13) xor d(12) xor d(9) xor d(8) xor d(4) xor c(0) xor c(3) xor c(7) xor c(9) xor c(10) xor c(12) xor c(14);
                NextCrc(10) := d(47) xor d(45) xor d(43) xor d(42) xor d(40) xor d(36) xor d(33) xor d(31) xor d(30) xor d(29) xor d(27) xor d(25) xor d(24) xor d(22) xor d(21) xor d(18) xor d(17) xor d(16) xor d(14) xor d(13) xor d(10) xor d(9) xor d(5) xor c(1) xor c(4) xor c(8) xor c(10) xor c(11) xor c(13) xor c(15);
                NextCrc(11) := d(46) xor d(44) xor d(43) xor d(41) xor d(37) xor d(34) xor d(32) xor d(31) xor d(30) xor d(28) xor d(26) xor d(25) xor d(23) xor d(22) xor d(19) xor d(18) xor d(17) xor d(15) xor d(14) xor d(11) xor d(10) xor d(6) xor c(0) xor c(2) xor c(5) xor c(9) xor c(11) xor c(12) xor c(14);
                NextCrc(12) := d(47) xor d(45) xor d(44) xor d(38) xor d(31) xor d(29) xor d(28) xor d(24) xor d(23) xor d(22) xor d(18) xor d(16) xor d(15) xor d(8) xor d(7) xor d(4) xor d(0) xor c(6) xor c(12) xor c(13) xor c(15);
                NextCrc(13) := d(46) xor d(45) xor d(39) xor d(32) xor d(30) xor d(29) xor d(25) xor d(24) xor d(23) xor d(19) xor d(17) xor d(16) xor d(9) xor d(8) xor d(5) xor d(1) xor c(0) xor c(7) xor c(13) xor c(14);
                NextCrc(14) := d(47) xor d(46) xor d(40) xor d(33) xor d(31) xor d(30) xor d(26) xor d(25) xor d(24) xor d(20) xor d(18) xor d(17) xor d(10) xor d(9) xor d(6) xor d(2) xor c(1) xor c(8) xor c(14) xor c(15);
                NextCrc(15) := d(47) xor d(41) xor d(34) xor d(32) xor d(31) xor d(27) xor d(26) xor d(25) xor d(21) xor d(19) xor d(18) xor d(11) xor d(10) xor d(7) xor d(3) xor c(0) xor c(2) xor c(9) xor c(15);
            when 7 =>
                d := Data(7 downto 0) & Data(15 downto 8) & Data(23 downto 16) & Data(31 downto 24) & Data(39 downto 32) & Data(47 downto 40) & Data(55 downto 48);
                NextCrc(0) := d(55) xor d(52) xor d(51) xor d(49) xor d(48) xor d(42) xor d(35) xor d(33) xor d(32) xor d(28) xor d(27) xor d(26) xor d(22) xor d(20) xor d(19) xor d(12) xor d(11) xor d(8) xor d(4) xor d(0) xor c(2) xor c(8) xor c(9) xor c(11) xor c(12) xor c(15);
                NextCrc(1) := d(53) xor d(52) xor d(50) xor d(49) xor d(43) xor d(36) xor d(34) xor d(33) xor d(29) xor d(28) xor d(27) xor d(23) xor d(21) xor d(20) xor d(13) xor d(12) xor d(9) xor d(5) xor d(1) xor c(3) xor c(9) xor c(10) xor c(12) xor c(13);
                NextCrc(2) := d(54) xor d(53) xor d(51) xor d(50) xor d(44) xor d(37) xor d(35) xor d(34) xor d(30) xor d(29) xor d(28) xor d(24) xor d(22) xor d(21) xor d(14) xor d(13) xor d(10) xor d(6) xor d(2) xor c(4) xor c(10) xor c(11) xor c(13) xor c(14);
                NextCrc(3) := d(55) xor d(54) xor d(52) xor d(51) xor d(45) xor d(38) xor d(36) xor d(35) xor d(31) xor d(30) xor d(29) xor d(25) xor d(23) xor d(22) xor d(15) xor d(14) xor d(11) xor d(7) xor d(3) xor c(5) xor c(11) xor c(12) xor c(14) xor c(15);
                NextCrc(4) := d(55) xor d(53) xor d(52) xor d(46) xor d(39) xor d(37) xor d(36) xor d(32) xor d(31) xor d(30) xor d(26) xor d(24) xor d(23) xor d(16) xor d(15) xor d(12) xor d(8) xor d(4) xor c(6) xor c(12) xor c(13) xor c(15);
                NextCrc(5) := d(55) xor d(54) xor d(53) xor d(52) xor d(51) xor d(49) xor d(48) xor d(47) xor d(42) xor d(40) xor d(38) xor d(37) xor d(35) xor d(31) xor d(28) xor d(26) xor d(25) xor d(24) xor d(22) xor d(20) xor d(19) xor d(17) xor d(16) xor d(13) xor d(12) xor d(11) xor d(9) xor d(8) xor d(5) xor d(4) xor d(0) xor c(0) xor c(2) xor c(7) xor c(8) xor c(9) xor c(11) xor c(12) xor c(13) xor c(14) xor c(15);
                NextCrc(6) := d(55) xor d(54) xor d(53) xor d(52) xor d(50) xor d(49) xor d(48) xor d(43) xor d(41) xor d(39) xor d(38) xor d(36) xor d(32) xor d(29) xor d(27) xor d(26) xor d(25) xor d(23) xor d(21) xor d(20) xor d(18) xor d(17) xor d(14) xor d(13) xor d(12) xor d(10) xor d(9) xor d(6) xor d(5) xor d(1) xor c(1) xor c(3) xor c(8) xor c(9) xor c(10) xor c(12) xor c(13) xor c(14) xor c(15);
                NextCrc(7) := d(55) xor d(54) xor d(53) xor d(51) xor d(50) xor d(49) xor d(44) xor d(42) xor d(40) xor d(39) xor d(37) xor d(33) xor d(30) xor d(28) xor d(27) xor d(26) xor d(24) xor d(22) xor d(21) xor d(19) xor d(18) xor d(15) xor d(14) xor d(13) xor d(11) xor d(10) xor d(7) xor d(6) xor d(2) xor c(0) xor c(2) xor c(4) xor c(9) xor c(10) xor c(11) xor c(13) xor c(14) xor c(15);
                NextCrc(8) := d(55) xor d(54) xor d(52) xor d(51) xor d(50) xor d(45) xor d(43) xor d(41) xor d(40) xor d(38) xor d(34) xor d(31) xor d(29) xor d(28) xor d(27) xor d(25) xor d(23) xor d(22) xor d(20) xor d(19) xor d(16) xor d(15) xor d(14) xor d(12) xor d(11) xor d(8) xor d(7) xor d(3) xor c(0) xor c(1) xor c(3) xor c(5) xor c(10) xor c(11) xor c(12) xor c(14) xor c(15);
                NextCrc(9) := d(55) xor d(53) xor d(52) xor d(51) xor d(46) xor d(44) xor d(42) xor d(41) xor d(39) xor d(35) xor d(32) xor d(30) xor d(29) xor d(28) xor d(26) xor d(24) xor d(23) xor d(21) xor d(20) xor d(17) xor d(16) xor d(15) xor d(13) xor d(12) xor d(9) xor d(8) xor d(4) xor c(1) xor c(2) xor c(4) xor c(6) xor c(11) xor c(12) xor c(13) xor c(15);
                NextCrc(10) := d(54) xor d(53) xor d(52) xor d(47) xor d(45) xor d(43) xor d(42) xor d(40) xor d(36) xor d(33) xor d(31) xor d(30) xor d(29) xor d(27) xor d(25) xor d(24) xor d(22) xor d(21) xor d(18) xor d(17) xor d(16) xor d(14) xor d(13) xor d(10) xor d(9) xor d(5) xor c(0) xor c(2) xor c(3) xor c(5) xor c(7) xor c(12) xor c(13) xor c(14);
                NextCrc(11) := d(55) xor d(54) xor d(53) xor d(48) xor d(46) xor d(44) xor d(43) xor d(41) xor d(37) xor d(34) xor d(32) xor d(31) xor d(30) xor d(28) xor d(26) xor d(25) xor d(23) xor d(22) xor d(19) xor d(18) xor d(17) xor d(15) xor d(14) xor d(11) xor d(10) xor d(6) xor c(1) xor c(3) xor c(4) xor c(6) xor c(8) xor c(13) xor c(14) xor c(15);
                NextCrc(12) := d(54) xor d(52) xor d(51) xor d(48) xor d(47) xor d(45) xor d(44) xor d(38) xor d(31) xor d(29) xor d(28) xor d(24) xor d(23) xor d(22) xor d(18) xor d(16) xor d(15) xor d(8) xor d(7) xor d(4) xor d(0) xor c(4) xor c(5) xor c(7) xor c(8) xor c(11) xor c(12) xor c(14);
                NextCrc(13) := d(55) xor d(53) xor d(52) xor d(49) xor d(48) xor d(46) xor d(45) xor d(39) xor d(32) xor d(30) xor d(29) xor d(25) xor d(24) xor d(23) xor d(19) xor d(17) xor d(16) xor d(9) xor d(8) xor d(5) xor d(1) xor c(5) xor c(6) xor c(8) xor c(9) xor c(12) xor c(13) xor c(15);
                NextCrc(14) := d(54) xor d(53) xor d(50) xor d(49) xor d(47) xor d(46) xor d(40) xor d(33) xor d(31) xor d(30) xor d(26) xor d(25) xor d(24) xor d(20) xor d(18) xor d(17) xor d(10) xor d(9) xor d(6) xor d(2) xor c(0) xor c(6) xor c(7) xor c(9) xor c(10) xor c(13) xor c(14);
                NextCrc(15) := d(55) xor d(54) xor d(51) xor d(50) xor d(48) xor d(47) xor d(41) xor d(34) xor d(32) xor d(31) xor d(27) xor d(26) xor d(25) xor d(21) xor d(19) xor d(18) xor d(11) xor d(10) xor d(7) xor d(3) xor c(1) xor c(7) xor c(8) xor c(10) xor c(11) xor c(14) xor c(15);
            when others =>
                NextCrc := c;
        end case;
        return NextCrc;
    end Crc16;
        
    ------------------------------------------------------------
    --! CONSTANTS
    ------------------------------------------------------------
    --! CANopen function codes per CiA 301
    constant FUNCTION_CODE_NMT                      : std_logic_vector(3 downto 0) := b"0000";
    constant FUNCTION_CODE_SYNC                     : std_logic_vector(3 downto 0) := b"0001";
    constant FUNCTION_CODE_EMCY                     : std_logic_vector(3 downto 0) := b"0001";
    constant FUNCTION_CODE_TIME                     : std_logic_vector(3 downto 0) := b"0010";
    constant FUNCTION_CODE_TPDO1                    : std_logic_vector(3 downto 0) := b"0011";
    constant FUNCTION_CODE_RPDO1                    : std_logic_vector(3 downto 0) := b"0100";
    constant FUNCTION_CODE_TPDO2                    : std_logic_vector(3 downto 0) := b"0101";
    constant FUNCTION_CODE_RPDO2                    : std_logic_vector(3 downto 0) := b"0110";
    constant FUNCTION_CODE_TPDO3                    : std_logic_vector(3 downto 0) := b"0111";
    constant FUNCTION_CODE_RPDO3                    : std_logic_vector(3 downto 0) := b"1000";
    constant FUNCTION_CODE_TPDO4                    : std_logic_vector(3 downto 0) := b"1001";
    constant FUNCTION_CODE_RPDO4                    : std_logic_vector(3 downto 0) := b"1010";
    constant FUNCTION_CODE_SDO_TX                   : std_logic_vector(3 downto 0) := b"1011";
    constant FUNCTION_CODE_SDO_RX                   : std_logic_vector(3 downto 0) := b"1100";
    constant FUNCTION_CODE_NMT_ERROR_CONTROL        : std_logic_vector(3 downto 0) := b"1110";
    
    constant BROADCAST_NODE_ID          : std_logic_vector(6 downto 0) := (others => '0');
    
    --! CANopen NMT commands per CiA 301
    constant NMT_NODE_CONTROL           : std_logic_vector(6 downto 0) := b"0000000";
    constant NMT_GFC                    : std_logic_vector(6 downto 0) := b"0000001";
    constant NMT_MASTER_NODE_ID         : std_logic_vector(6 downto 0) := b"1110001";
    
    --! CANopen NMT node control commands
    constant NMT_NODE_CONTROL_OPERATIONAL       : std_logic_vector(7 downto 0) := x"01";
    constant NMT_NODE_CONTROL_STOPPED           : std_logic_vector(7 downto 0) := x"02";
    constant NMT_NODE_CONTROL_PREOPERATIONAL    : std_logic_vector(7 downto 0) := x"80";
    constant NMT_NODE_CONTROL_RESET_APP         : std_logic_vector(7 downto 0) := x"81";
    constant NMT_NODE_CONTROL_RESET_COMM        : std_logic_vector(7 downto 0) := x"82";
    
    --! CANopen NMT states per CiA 301
    constant NMT_STATE_INITIALISATION   : std_logic_vector(6 downto 0) := b"0000000";
    constant NMT_STATE_STOPPED          : std_logic_vector(6 downto 0) := b"0000100";
    constant NMT_STATE_OPERATIONAL      : std_logic_vector(6 downto 0) := b"0000101";
    constant NMT_STATE_PREOPERATIONAL   : std_logic_vector(6 downto 0) := b"1111111";
    
    --! CANopen SDO Command Specifiers per CiA 301
    constant SDO_CS_ABORT               : std_logic_vector(2 downto 0) := b"100"; --! Abort transfer
    
    --! CANopen SDO Client Command Specifiers (CCSs) per CiA 301
    constant SDO_CCS_DSR                : std_logic_vector(2 downto 0) := b"000"; --! Download segment request
    constant SDO_CCS_IDR                : std_logic_vector(2 downto 0) := b"001"; --! Initiate download request
    constant SDO_CCS_IUR                : std_logic_vector(2 downto 0) := b"010"; --! Intiate upload request
    constant SDO_CCS_USR                : std_logic_vector(2 downto 0) := b"011"; --! Upload segment request
    constant SDO_CCS_BUR                : std_logic_vector(2 downto 0) := b"101"; --! Block upload request
    constant SDO_CCS_BDR                : std_logic_vector(2 downto 0) := b"110"; --! Block download request
    
    --! CANopen SDO Server Command Specifiers (SCSs) per CiA 301
    constant SDO_SCS_USR                : std_logic_vector(2 downto 0) := b"000"; --! Upload segment response
    constant SDO_SCS_DSR                : std_logic_vector(2 downto 0) := b"001"; --! Download segment response
    constant SDO_SCS_IUR                : std_logic_vector(2 downto 0) := b"010"; --! Initiate upload response
    constant SDO_SCS_IDR                : std_logic_vector(2 downto 0) := b"011"; --! Initiate download response
    constant SDO_SCS_BDR                : std_logic_vector(2 downto 0) := b"101"; --! Block download response
    constant SDO_SCS_BUR                : std_logic_vector(2 downto 0) := b"110"; --! Block upload response

    --! CANopen SDO Block Client and Server Subcommands
    constant SDO_BLOCK_SUBCOMMAND_INITIATE  : std_logic_vector(1 downto 0) := b"00"; --! Block subcommand initiate (upload/download request/response)
    constant SDO_BLOCK_SUBCOMMAND_END       : std_logic_vector(1 downto 0) := b"01"; --! Block subcommand end (upload/download request/response)
    constant SDO_BLOCK_SUBCOMMAND_RESPONSE  : std_logic_vector(1 downto 0) := b"10"; --! Block subcommand response (upload/download response)
    constant SDO_BLOCK_SUBCOMMAND_START     : std_logic_vector(1 downto 0) := b"11"; --! Block subcommand start (upload request)
    
    --! CANopen SDO abort codes per CiA 301
    constant SDO_ABORT_TOGGLE           : std_logic_vector(31 downto 0) := x"05030000"; --! Toggle bit not alternated
    constant SDO_ABORT_CS               : std_logic_vector(31 downto 0) := x"05040001"; --! Client/server command specifier not valid or unknown
    constant SDO_ABORT_BLKSIZE          : std_logic_vector(31 downto 0) := x"05040002"; --! Invalid block size (block mode only)
    constant SDO_ABORT_SEQNO            : std_logic_vector(31 downto 0) := x"05040003"; --! Invalid sequence number (block mode only)
    constant SDO_ABORT_CRC              : std_logic_vector(31 downto 0) := x"05040004"; --! CRC error (block mode only)
    constant SDO_ABORT_ACCESS           : std_logic_vector(31 downto 0) := x"06010000"; --! Unsupported access to an object
    constant SDO_ABORT_WO               : std_logic_vector(31 downto 0) := x"06010001"; --! Attempt to read a write only object
    constant SDO_ABORT_RO               : std_logic_vector(31 downto 0) := x"06010002"; --! Attempt to write a read only object
    constant SDO_ABORT_DNE              : std_logic_vector(31 downto 0) := x"06020000"; --! Object does not exist in the object dictionary
    constant SDO_ABORT_PARAM_LENGTH     : std_logic_vector(31 downto 0) := x"06070010"; --! Data type does not match, length of service parameter does not match
    constant SDO_ABORT_PARAM_LONG       : std_logic_vector(31 downto 0) := x"06070012"; --! Data type does not match, length of service parameter too high
    constant SDO_ABORT_PARAM_SHORT      : std_logic_vector(31 downto 0) := x"06070013"; --! Data type does not match, length of service parameter too low
    constant SDO_ABORT_PARAM_INVALID    : std_logic_vector(31 downto 0) := x"06090030"; --! Invalid value for parameter (download only)
    constant SDO_ABORT_PARAM_HIGH       : std_logic_vector(31 downto 0) := x"06090031"; --! Value of parameter written too high (download only)
    constant SDO_ABORT_PARAM_LOW        : std_logic_vector(31 downto 0) := x"06090032"; --! Value of parameter written too low (download only)
    constant SDO_ABORT_GENERAL          : std_logic_vector(31 downto 0) := x"08000000"; --! General error
    constant SDO_ABORT_NO_DATA          : std_logic_vector(31 downto 0) := x"08000024"; --! No data available
    
    --! CANopen Object Dictionary indices (ODIs) 
    --! Mandatory indices per CiA 301
    constant ODI_DEVICE_TYPE            : std_logic_vector(23 downto 0) := x"100000";
    constant ODI_ERROR                  : std_logic_vector(23 downto 0) := x"100100";
    constant ODI_ID_LENGTH              : std_logic_vector(23 downto 0) := x"101800";
    constant ODI_ID_VENDOR              : std_logic_vector(23 downto 0) := x"101801";
    constant ODI_VERSION_COUNT          : std_logic_vector(23 downto 0) := x"103000";
    constant ODI_VERSION_1              : std_logic_vector(23 downto 0) := x"103001";
    constant ODI_VERSION_2              : std_logic_vector(23 downto 0) := x"103002";
    --! Conditional indices (based on supported features) per CiA 301
    constant ODI_SYNC                   : std_logic_vector(23 downto 0) := x"100500"; --! If PDO communication on a synchronous base
    constant ODI_TIME                   : std_logic_vector(23 downto 0) := x"101200"; --! If TIME producer/consumer
    constant ODI_EMCY                   : std_logic_vector(23 downto 0) := x"101400"; --! If Emergency supported
    constant ODI_HEARTBEAT_CONSUMER_TIME : std_logic_vector(23 downto 0) := x"101600"; --! If Heartbeat consumer
    constant ODI_HEARTBEAT_PRODUCER_TIME : std_logic_vector(23 downto 0) := x"101700"; --! If Heartbeat Protocol
    constant ODI_ID_PRODUCT             : std_logic_vector(23 downto 0) := x"101802";
    constant ODI_ID_REVISION            : std_logic_vector(23 downto 0) := x"101803";
    constant ODI_ID_SERIAL              : std_logic_vector(23 downto 0) := x"101804";
    constant ODI_SYNC_COUNTER_OVERFLOW  : std_logic_vector(23 downto 0) := x"101900"; --! If synchronous counter
    constant ODI_STORE_EDS              : std_logic_vector(23 downto 0) := x"102100";
    constant ODI_STORE_FORMAT           : std_logic_vector(23 downto 0) := x"102200";
    constant ODI_ERROR_BEHAVIOR         : std_logic_vector(23 downto 0) := x"102900";
    constant ODI_SDO_SERVER_COUNT       : std_logic_vector(23 downto 0) := x"120000"; --! If SDO
    constant ODI_SDO_SERVER_RX_ID       : std_logic_vector(23 downto 0) := x"120001"; --! CAN ID used for SDO client-to-server
    constant ODI_SDO_SERVER_TX_ID       : std_logic_vector(23 downto 0) := x"120002"; --! CAN ID used for SDO server-to-client
    constant ODI_GFC                    : std_logic_vector(23 downto 0) := x"130000"; --! Global Failsafe Command
    constant ODI_TPDO1_COMM_COUNT       : std_logic_vector(23 downto 0) := x"180000"; --! If PDO1 TX
    constant ODI_TPDO1_COMM_ID          : std_logic_vector(23 downto 0) := x"180001"; --! CAN ID used for TPDO1 (0x180 + Address)
    constant ODI_TPDO1_COMM_TYPE        : std_logic_vector(23 downto 0) := x"180002"; --! Transmission (trigger) type for TPDO1
    constant ODI_TPDO2_COMM_COUNT       : std_logic_vector(23 downto 0) := x"180100"; --! If PDO2 TX
    constant ODI_TPDO2_COMM_ID          : std_logic_vector(23 downto 0) := x"180101"; --! CAN ID used for TPDO2 (0x181 + Address)
    constant ODI_TPDO2_COMM_TYPE        : std_logic_vector(23 downto 0) := x"180102"; --! Transmission (trigger) type for TPDO2
    constant ODI_TPDO3_COMM_COUNT       : std_logic_vector(23 downto 0) := x"180200"; --! If PDO3 TX
    constant ODI_TPDO3_COMM_ID          : std_logic_vector(23 downto 0) := x"180201"; --! CAN ID used for TPDO3 (0x182 + Address)
    constant ODI_TPDO3_COMM_TYPE        : std_logic_vector(23 downto 0) := x"180202"; --! Transmission (trigger) type for TPDO3
    constant ODI_TPDO4_COMM_COUNT       : std_logic_vector(23 downto 0) := x"180300"; --! If PDO4 TX
    constant ODI_TPDO4_COMM_ID          : std_logic_vector(23 downto 0) := x"180301"; --! CAN ID used for TPDO4 (0x183 + Address)
    constant ODI_TPDO4_COMM_TYPE        : std_logic_vector(23 downto 0) := x"180302"; --! Transmission (trigger) type for TPDO4
    constant ODI_TPDO1_MAPPING          : std_logic_vector(23 downto 0) := x"1A0000";
    constant ODI_TPDO2_MAPPING          : std_logic_vector(23 downto 0) := x"1A0100";
    constant ODI_TPDO3_MAPPING          : std_logic_vector(23 downto 0) := x"1A0200";
    constant ODI_TPDO4_MAPPING          : std_logic_vector(23 downto 0) := x"1A0300";
    constant ODI_NMT_STARTUP            : std_logic_vector(23 downto 0) := x"1F8000";

    --! Emergency error codes
    constant EMCY_EEC_NO_ERROR          : std_logic_vector(15 downto 0) := x"0000";
    constant EMCY_EEC_GENERIC           : std_logic_vector(15 downto 0) := x"1000";
    constant EMCY_EEC_CURRENT           : std_logic_vector(15 downto 0) := x"2000";
    constant EMCY_EEC_CURRENT_INPUT     : std_logic_vector(15 downto 0) := x"2100";
    constant EMCY_EEC_CURRENT_INSIDE    : std_logic_vector(15 downto 0) := x"2200";
    constant EMCY_EEC_CURRENT_OUTPUT    : std_logic_vector(15 downto 0) := x"2300";
    constant EMCY_EEC_VOLTAGE           : std_logic_vector(15 downto 0) := x"3000";
    constant EMCY_EEC_VOLTAGE_MAINS     : std_logic_vector(15 downto 0) := x"3100";
    constant EMCY_EEC_VOLTAGE_INSIDE    : std_logic_vector(15 downto 0) := x"3200";
    constant EMCY_EEC_VOLTAGE_OUTPUT    : std_logic_vector(15 downto 0) := x"3300";
    constant EMCY_EEC_TEMPERATURE       : std_logic_vector(15 downto 0) := x"4000";
    constant EMCY_EEC_TEMPERATURE_AMBIENT : std_logic_vector(15 downto 0) := x"4100";
    constant EMCY_EEC_TEMPERATURE_DEVICE : std_logic_vector(15 downto 0) := x"4200";
    constant EMCY_EEC_HARDWARE          : std_logic_vector(15 downto 0) := x"5000";
    constant EMCY_EEC_SOFTWARE          : std_logic_vector(15 downto 0) := x"6000";
    constant EMCY_EEC_SOFTWARE_INTERNAL : std_logic_vector(15 downto 0) := x"6100";
    constant EMCY_EEC_SOFTWARE_USER     : std_logic_vector(15 downto 0) := x"6200";
    constant EMCY_EEC_SOFTWARE_DATA_SET : std_logic_vector(15 downto 0) := x"6300";
    constant EMCY_EEC_ADDITIONAL_MODULES : std_logic_vector(15 downto 0) := x"7000";
    constant EMCY_EEC_MONITORING        : std_logic_vector(15 downto 0) := x"8000";
    constant EMCY_EEC_COMMUNICATION     : std_logic_vector(15 downto 0) := x"8100";
    constant EMCY_EEC_CAN_OVERRUN       : std_logic_vector(15 downto 0) := x"8110";
    constant EMCY_EEC_CAN_ERROR_PASSIVE : std_logic_vector(15 downto 0) := x"8120";
    constant EMCY_EEC_HEARTBEAT         : std_logic_vector(15 downto 0) := x"8130";
    constant EMCY_EEC_BUS_OFF_RECOVERY  : std_logic_vector(15 downto 0) := x"8140";
    constant EMCY_EEC_CAN_ID_COLLISION  : std_logic_vector(15 downto 0) := x"8150";
    constant EMCY_EEC_PROTOCOL          : std_logic_vector(15 downto 0) := x"8200";
    constant EMCY_EEC_PDO_NOT_PROCESSED : std_logic_vector(15 downto 0) := x"8210";
    constant EMCY_EEC_PDO_LENGTH_EXCEEDED : std_logic_vector(15 downto 0) := x"8220";
    constant EMCY_EEC_DAM_MPDO_NA       : std_logic_vector(15 downto 0) := x"8230";
    constant EMCY_EEC_SYNC_LENGTH       : std_logic_vector(15 downto 0) := x"8240";
    constant EMCY_EEC_RPDO_TIMEOUT      : std_logic_vector(15 downto 0) := x"8250";
    constant EMCY_EEC_EXTERNAL          : std_logic_vector(15 downto 0) := x"9000";
    constant EMCY_EEC_ADDITIONAL_FUNCTIONS : std_logic_vector(15 downto 0) := x"F000";
    constant EMCY_EEC_DEVICE_SPECIFIC   : std_logic_vector(15 downto 0) := x"FF00";
     
    --! CANopen Device Profiles
    constant DEVICE_PROFILE_GENERIC_IO      : std_logic_vector(15 downto 0) := x"0191";
end package body CanOpen;
