library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use work.CanBus;
use work.CanOpen;

entity CanOpenNode is
    generic (
        CLOCK_FREQUENCY                 : positive; --! Clock frequency in Hz
        DEFAULT_CANOPEN_DEVICE_TYPE     : std_logic_vector(31 downto 0) := (others => '0'); --! 0 is non-standard device type
        DEFAULT_CANOPEN_ID_VENDOR       : std_logic_vector(31 downto 0) := (others => '0'); --! 0 is unassigned by CiA
        DEFAULT_CANOPEN_ID_PRODUCT      : std_logic_vector(31 downto 0) := (others => '0');
        DEFAULT_CANOPEN_HEARTBEAT_PRODUCER_TIME : std_logic_vector(15 downto 0) := x"03E8";
        DEFAULT_CANOPEN_TPDO1_DISABLE   : std_logic := '1';
        DEFAULT_CANOPEN_TPDO2_DISABLE   : std_logic := '1';
        DEFAULT_CANOPEN_TPDO3_DISABLE   : std_logic := '1';
        DEFAULT_CANOPEN_TPDO4_DISABLE   : std_logic := '1';
        DEFAULT_CANOPEN_NMT_STARTUP     : std_logic_vector(31 downto 0) := x"00000000"
    );
    port (
        --! Signals common to all CANopen nodes
        Clock           : in  std_logic;
        Reset_n         : in  std_logic;
        
        CanRx           : in  std_logic;
        CanTx           : out std_logic;
        
        NodeId          : in natural range 0 to 127;
    
        NmtState        : out std_logic_vector(6 downto 0);
        CanStatus       : out CanBus.Status;
        
        Sync            : out std_logic;
        Gfc             : out std_logic
    );
end entity CanOpenNode;

architecture Behavioral of CanOpenNode is

    type State is (
        STATE_RESET,
        STATE_RESET_APP,
        STATE_RESET_COMM,
        STATE_RESET_BOOTUP,
        STATE_BOOTUP,
        STATE_BOOTUP_WAIT,
        STATE_IDLE,
        STATE_CAN_RX_STROBE,
        STATE_CAN_RX_READ,
        STATE_CAN_TX_WAIT,
        STATE_HEARTBEAT,
        STATE_TPDO1,
        STATE_TPDO2,
        STATE_TPDO3,
        STATE_TPDO4,
        STATE_SDO
    );
    
    function to_std_logic(b : boolean) return std_logic is
    begin
        if b then return('1'); else return('0'); end if;
    end;
    
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
    signal CurrentState     : State;
    signal NextState        : State;
    signal NodeId_q         : std_logic_vector(6 downto 0);
    signal RxFrame, RxFrame_q, TxFrame, TxFrame_q : CanBus.Frame;
    signal RxFifoReadEnable : std_logic;
    signal RxFifoWriteEnable : std_logic;
    signal RxFifoEmpty      : std_logic;
    signal RxFifoFull       : std_logic;
    signal TxFifoReadEnable : std_logic;
    signal TxFifoWriteEnable : std_logic;
    signal TxFifoEmpty      : std_logic;
    signal TxAck            : std_logic;
    signal CanStatus_buf    : CanBus.Status;
    
    --! CANopen aliases
    signal RxCobId          : CanOpen.CobId;
    signal RxNmtNodeControlCommand  : std_logic_vector(7 downto 0);
    signal RxNmtNodeControlNodeId   : std_logic_vector(6 downto 0);
    signal RxSdo            : CanOpen.Sdo;
    signal TxSdo            : CanOpen.Sdo;
    
    --! CANopen variables
    signal NmtState_buf : std_logic_vector(6 downto 0);
    signal NmtState_q   : std_logic_vector(6 downto 0);
        
    --! Asynchronous Interrupts
	signal Sync_buf             : std_logic;
    signal HeartbeatProducerInterrupt   : std_logic;
    signal Tpdo1Interrupt       : std_logic;
    signal Tpdo2Interrupt       : std_logic;
    signal Tpdo3Interrupt       : std_logic;
    signal Tpdo4Interrupt       : std_logic;
    signal TpdoInterruptEnable  : std_logic;
    signal Tpdo1InterruptEnable : std_logic;
    signal Tpdo2InterruptEnable : std_logic;
    signal Tpdo3InterruptEnable : std_logic;
    signal Tpdo4InterruptEnable : std_logic;

    --! Object Dictionary registers
    signal Errors       : std_logic_vector(7 downto 0);

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
            TxFrame => TxFrame,
            TxFifoReadEnable => TxFifoReadEnable,
            TxFifoEmpty => TxFifoEmpty,
            TxAck => TxAck,
            Status => CanStatus_buf
        );
    
    --! CANopen aliases
    RxCobId.FunctionCode <= RxFrame_q.Id(10 downto 7);
    RxCobId.NodeId <= RxFrame_q.Id(6 downto 0);
    RxNmtNodeControlCommand <= RxFrame_q.Data(0);
    RxNmtNodeControlNodeId <= RxFrame_q.Data(1)(6 downto 0);
    RxSdo.Cs <= RxFrame_q.Data(0)(7 downto 5);
    RxSdo.N <= RxFrame_q.Data(0)(3 downto 2);
    RxSdo.E <= RxFrame_q.Data(0)(1);
    RxSdo.S <= RxFrame_q.Data(0)(0);
    RxSdo.Mux <= RxFrame_q.Data(2) & RxFrame_q.Data(1) & RxFrame_q.Data(3);
    RxSdo.Data <= RxFrame_q.Data(7) & RxFrame_q.Data(6) & RxFrame_q.Data(5) & RxFrame_q.Data(4); --! LSB first
            
    NmtState <= NmtState_buf;
    CanStatus <= CanStatus_buf;
                
    Errors <= (0 => or_reduce(Errors(7 downto 1)), 4 => to_std_logic(CanBus."="(CanStatus_buf.State, CanBus.STATE_BUS_OFF)) or CanStatus_buf.Overflow, others => '0');
    Gfc <= '1' when CurrentState = STATE_CAN_RX_READ and RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_NMT and RxCobId.NodeId = CanOpen.NMT_GFC else '0';
    Sync_buf <= '1' when CurrentState = STATE_CAN_RX_READ and RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_SYNC and RxCobId.NodeId = CanOpen.BROADCAST_NODE_ID else '0';
    Sync <= Sync_buf;
    
    --! Single depth FIFO emulator
    RxFifoFull <= '0';
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
            if TxFifoWriteEnable = '1' then
                TxFrame_q <= TxFrame;
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
    
    --! Simple registered signals
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            CurrentState <= STATE_RESET;
            NmtState_q <= CanOpen.NMT_STATE_INITIALISATION;
        elsif rising_edge(Clock) then
            CurrentState <= NextState;
            NmtState_q <= NmtState_buf;
        end if;
    end process;
    
    --! Next state in state machine
    process (CurrentState, TxAck, CanStatus.State, NodeId, HeartbeatProducerInterrupt, Tpdo1Interrupt, Tpdo2Interrupt, Tpdo3Interrupt, Tpdo4Interrupt, RxFifoEmpty, TxFifoReadEnable, RxCobId.FunctionCode, RxCobId.NodeId, RxNmtNodeControlNodeId, NodeId_q, RxNmtNodeControlCommand)
    begin
        case CurrentState is
            when STATE_RESET =>
                NextState <= STATE_RESET_APP;
            when STATE_RESET_APP =>
                    NextState <= STATE_RESET_COMM;
            when STATE_RESET_COMM =>
                if CanBus."/="(CanStatus.State, CanBus.STATE_RESET) and CanBus."/="(CanStatus.State, CanBus.STATE_BUS_OFF) and NodeId /= to_integer(unsigned(CanOpen.BROADCAST_NODE_ID)) then
                    NextState <= STATE_BOOTUP;
                else
                    NextState <= STATE_RESET_COMM;
                end if;
            when STATE_BOOTUP =>
                NextState <= STATE_BOOTUP_WAIT;
            when STATE_BOOTUP_WAIT =>
                if TxAck = '1' then --! Wait until boot-up message has been sent
                    NextState <= STATE_IDLE;
                else
                    NextState <= STATE_BOOTUP_WAIT;
                end if;
            when STATE_IDLE =>
                if CanBus."="(CanStatus.State, CanBus.STATE_RESET) or CanBus."="(CanStatus.State, CanBus.STATE_BUS_OFF) then
                    NextState <= STATE_IDLE;
                elsif HeartbeatProducerInterrupt = '1' then
                    NextState <= STATE_HEARTBEAT;
                elsif Tpdo1Interrupt = '1' then
                    NextState <= STATE_TPDO1;
                elsif Tpdo2Interrupt = '1' then
                    NextState <= STATE_TPDO2;
                elsif Tpdo3Interrupt = '1' then
                    NextState <= STATE_TPDO3;
                elsif Tpdo4Interrupt = '1' then
                    NextState <= STATE_TPDO4;
                elsif RxFifoEmpty = '0' then
                    NextState <= STATE_CAN_RX_STROBE;
                else
                    NextState <= STATE_IDLE;
                end if;
            when STATE_HEARTBEAT =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_TPDO1 =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_TPDO2 =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_TPDO3 =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_TPDO4 =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_SDO =>
                NextState <= STATE_CAN_TX_WAIT;
            when STATE_CAN_TX_WAIT =>
                if TxFifoReadEnable = '1' then
                    NextState <= STATE_IDLE;
                else
                    NextState <= STATE_CAN_TX_WAIT;
                end if;
            when STATE_CAN_RX_STROBE =>
                NextState <= STATE_CAN_RX_READ;
            when STATE_CAN_RX_READ =>
                if RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_NMT and RxCobId.NodeId = CanOpen.NMT_NODE_CONTROL and (RxNmtNodeControlNodeId = CanOpen.BROADCAST_NODE_ID or RxNmtNodeControlNodeId = NodeId_q) then
                    if RxNmtNodeControlCommand = CanOpen.NMT_NODE_CONTROL_RESET_APP then
                        NextState <= STATE_RESET_APP;
                    elsif RxNmtNodeControlCommand = CanOpen.NMT_NODE_CONTROL_RESET_COMM then
                        NextState <= STATE_RESET_COMM;
                    else
                        NextState <= STATE_IDLE;
                    end if;
                elsif RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_SDO_RX and RxCobId.NodeId = NodeId_q then --! SDO Request
                    NextState <= STATE_SDO;
                else
                    NextState <= STATE_IDLE;
                end if;
            when others =>
                NextState <= STATE_RESET;
        end case;
    end process;
    
    --! NMT State determination
    process (CurrentState, CanStatus.State, TxAck, RxCobId.FunctionCode, RxCobId.NodeId, RxNmtNodeControlNodeId, NodeId_q, RxNmtNodeControlNodeId, RxNmtNodeControlCommand, NmtState_q)
    begin
        if CanBus."="(CanStatus.State, CanBus.STATE_BUS_OFF) and NmtState_q = CanOpen.NMT_STATE_OPERATIONAL then
            NmtState_buf <= CanOpen.NMT_STATE_PREOPERATIONAL;
        else
            case CurrentState is
                when STATE_RESET =>
                    NmtState_buf <= CanOpen.NMT_STATE_INITIALISATION;
                when STATE_RESET_APP =>
                    NmtState_buf <= CanOpen.NMT_STATE_INITIALISATION;
                when STATE_RESET_COMM =>
                    NmtState_buf <= CanOpen.NMT_STATE_INITIALISATION;
                when STATE_BOOTUP =>
                    NmtState_buf <= CanOpen.NMT_STATE_INITIALISATION;
                when STATE_BOOTUP_WAIT =>
                    if TxAck = '1' then
                        if DEFAULT_CANOPEN_NMT_STARTUP(3) = '1' then --! Per CiA 302-2
                            NmtState_buf <= CanOpen.NMT_STATE_OPERATIONAL;
                        else
                            NmtState_buf <= CanOpen.NMT_STATE_PREOPERATIONAL;
                        end if;
                    else
                        NmtState_buf <= CanOpen.NMT_STATE_INITIALISATION;
                    end if;
                when STATE_CAN_RX_READ =>
                    if RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_NMT and RxCobId.NodeId = CanOpen.NMT_NODE_CONTROL and (RxNmtNodeControlNodeId = NodeId_q or RxNmtNodeControlNodeId = CanOpen.BROADCAST_NODE_ID) then
                        case RxNmtNodeControlCommand is
                            when CanOpen.NMT_NODE_CONTROL_OPERATIONAL =>
                                NmtState_buf <= CanOpen.NMT_STATE_OPERATIONAL;
                            when CanOpen.NMT_NODE_CONTROL_PREOPERATIONAL =>
                                NmtState_buf <= CanOpen.NMT_STATE_PREOPERATIONAL;
                            when CanOpen.NMT_NODE_CONTROL_STOPPED =>
                                NmtState_buf <= CanOpen.NMT_STATE_STOPPED;
                            when others =>
                                NmtState_buf <= NmtState_q;
                        end case;
                    else
                        NmtState_buf <= NmtState_q;
                    end if;
                when others =>
                    NmtState_buf <= NmtState_q;
            end case;
        end if;
    end process;
    
    --! Latch NodeId
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            NodeId_q <= CanOpen.BROADCAST_NODE_ID;
        elsif rising_edge(Clock) then
            if CurrentState = STATE_RESET_COMM then
                NodeId_q <= std_logic_vector(to_unsigned(NodeId, NodeId_q'length));
            end if;
        end if;
    end process;
      
    --! Timers
    process (Reset_n, Clock)
        variable HeartbeatProducerCounter   : integer range 0 to 65535;
        variable MillisecondCounter         : integer range 0 to (CLOCK_FREQUENCY / 1000);
        variable MillisecondEnable          : std_logic;
    begin
        if Reset_n = '0' then
            HeartbeatProducerCounter := 0;
            MillisecondCounter := 0;
            MillisecondEnable := '0';
            HeartbeatProducerInterrupt <= '0';
        elsif rising_edge(Clock) then
            if MillisecondCounter = (CLOCK_FREQUENCY / 1000) then
                MillisecondCounter := 0;
                MillisecondEnable := '1';
            else
                MillisecondCounter := MillisecondCounter + 1;
                MillisecondEnable := '0';
            end if;
            if MillisecondEnable = '1' then 
                if HeartbeatProducerCounter = unsigned(DEFAULT_CANOPEN_HEARTBEAT_PRODUCER_TIME) then
                    HeartbeatProducerCounter := 0;
                else
                    HeartbeatProducerCounter := HeartbeatProducerCounter + 1;
                end if;
            end if;
            if MillisecondEnable = '1' and HeartbeatProducerCounter = unsigned(DEFAULT_CANOPEN_HEARTBEAT_PRODUCER_TIME) then
                HeartbeatProducerInterrupt <= '1';
            elsif CurrentState = STATE_HEARTBEAT then
                HeartbeatProducerInterrupt <= '0';
            end if;
        end if;
    end process;
    
    TpdoInterruptEnable <= '1' when Sync_buf = '1' and NmtState_buf = CanOpen.NMT_STATE_OPERATIONAL else '0';
    
    --! TPDO1 interrupt
    Tpdo1InterruptEnable <= '1' when DEFAULT_CANOPEN_TPDO1_DISABLE = '0' and (TpdoInterruptEnable = '1' or (CurrentState = STATE_CAN_RX_READ and RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_TPDO1 and RxCobId.NodeId = NodeId_q and RxFrame_q.Rtr = '1')) else '0';
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            Tpdo1Interrupt <= '0';
        elsif rising_edge(Clock) then
            if Tpdo1InterruptEnable = '1' then
                Tpdo1Interrupt <= '1';
            elsif CurrentState = STATE_TPDO1 then
                Tpdo1Interrupt <= '0';
            end if;
        end if;
    end process;
    
    --! TPDO2 interrupt
    Tpdo2InterruptEnable <= '1' when DEFAULT_CANOPEN_TPDO2_DISABLE = '0' and (TpdoInterruptEnable = '1' or (CurrentState = STATE_CAN_RX_READ and RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_TPDO2 and RxCobId.NodeId = NodeId_q and RxFrame_q.Rtr = '1')) else '0';
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            Tpdo2Interrupt <= '0';
        elsif rising_edge(Clock) then
            if Tpdo2InterruptEnable = '1' then
                Tpdo2Interrupt <= '1';
            elsif CurrentState = STATE_TPDO2 then
                Tpdo2Interrupt <= '0';
            end if;
        end if;
    end process;

    --! TPDO3 interrupt
    Tpdo3InterruptEnable <= '1' when DEFAULT_CANOPEN_TPDO3_DISABLE = '0' and (TpdoInterruptEnable = '1' or (CurrentState = STATE_CAN_RX_READ and RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_TPDO3 and RxCobId.NodeId = NodeId_q and RxFrame_q.Rtr = '1')) else '0';
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            Tpdo3Interrupt <= '0';
        elsif rising_edge(Clock) then
            if Tpdo3InterruptEnable = '1' then
                Tpdo3Interrupt <= '1';
            elsif CurrentState = STATE_TPDO3 then
                Tpdo3Interrupt <= '0';
            end if;
        end if;
    end process;

    --! TPDO4 interrupt
    Tpdo4InterruptEnable <= '1' when DEFAULT_CANOPEN_TPDO4_DISABLE = '0' and (TpdoInterruptEnable = '1' or (CurrentState = STATE_CAN_RX_READ and RxCobId.FunctionCode = CanOpen.FUNCTION_CODE_TPDO4 and RxCobId.NodeId = NodeId_q and RxFrame_q.Rtr = '1')) else '0';
    process (Reset_n, Clock)
    begin
        if Reset_n = '0' then
            Tpdo4Interrupt <= '0';
        elsif rising_edge(Clock) then
            if Tpdo4InterruptEnable = '1' then
                Tpdo4Interrupt <= '1';
            elsif CurrentState = STATE_TPDO4 then
                Tpdo4Interrupt <= '0';
            end if;
        end if;
    end process;
    
    RxFifoReadEnable <= '1' when CurrentState = STATE_CAN_RX_STROBE else '0';
    
    --! Load CAN TX registers
    TxFrame.Id(28 downto 11) <= (others => '0'); --! TX of extended frames unsupported
    TxFrame.Rtr <= '0'; --! TX of RTR unsupported
    TxFrame.Ide <= '0'; --! TX of extended frames unsupported
    process (CurrentState, NodeId_q, NmtState_buf, TxSdo.Cs, TxSdo.N, RxFrame_q.Data, TxSdo.Data, TxFrame_q)
    begin
        case CurrentState is
            when STATE_BOOTUP =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_NMT_ERROR_CONTROL & NodeId_q;
                TxFrame.Dlc <= b"0001";
                TxFrame.Data <= (others => (others => '0'));
                TxFifoWriteEnable <= '1';
            when STATE_HEARTBEAT =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_NMT_ERROR_CONTROL & NodeId_q;
                TxFrame.Dlc <= b"0001";
                TxFrame.Data <= (0 => '0' & NmtState_buf, others => (others => '0'));
                TxFifoWriteEnable <= '1';
            when STATE_TPDO1 =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_TPDO1 & NodeId_q;
                TxFrame.Dlc <= b"0000"; --! TODO: look this up via mappings
                TxFrame.Data <= (others => (others => '0')); --! TODO: look this up via mappings
                TxFifoWriteEnable <= '1';
            when STATE_TPDO2 =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_TPDO2 & NodeId_q;
                TxFrame.Dlc <= b"0000"; --! TODO: look this up via mappings
                TxFrame.Data <= (others => (others => '0')); --! TODO: look this up via mappings
                TxFifoWriteEnable <= '1';
            when STATE_TPDO3 =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_TPDO3 & NodeId_q;
                TxFrame.Dlc <= b"0000"; --! TODO: look this up via mappings
                TxFrame.Data <= (others => (others => '0')); --! TODO: look this up via mappings
                TxFifoWriteEnable <= '1';
            when STATE_TPDO4 =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_TPDO4 & NodeId_q;
                TxFrame.Dlc <= b"0000"; --! TODO: look this up via mappings
                TxFrame.Data <= (others => (others => '0')); --! TODO: look this up via mappings
                TxFifoWriteEnable <= '1';
            when STATE_SDO =>
                TxFrame.Id(10 downto 0) <= CanOpen.FUNCTION_CODE_SDO_TX & NodeId_q;
                TxFrame.Dlc <= b"1000";
                TxFrame.Data(0)(7 downto 5) <= TxSdo.Cs;
                TxFrame.Data(0)(4) <= '0';
                TxFrame.Data(0)(3 downto 2) <= TxSdo.N;
                TxFrame.Data(0)(1) <= '1'; --! Expedited
                TxFrame.Data(0)(0) <= '1'; --! Size indicator
                TxFrame.Data(1) <= RxFrame_q.Data(1);
                TxFrame.Data(2) <= RxFrame_q.Data(2);
                TxFrame.Data(3) <= RxFrame_q.Data(3); --! Echo object dictionary index
                TxFrame.Data(4) <= TxSdo.Data(7 downto 0);
                TxFrame.Data(5) <= TxSdo.Data(15 downto 8);
                TxFrame.Data(6) <= TxSdo.Data(23 downto 16);
                TxFrame.Data(7) <= TxSdo.Data(31 downto 24);
                TxFifoWriteEnable <= '1';
            when others =>
                TxFrame.Id(10 downto 0) <= TxFrame_q.Id(10 downto 0);
                TxFrame.Dlc <= TxFrame_q.Dlc;
                TxFrame.Data <= TxFrame_q.Data;
                TxFifoWriteEnable <= '0';
        end case;
    end process;
    
    --! SDO
    process (CurrentState, RxSdo.Cs, RxSdo.Mux, RxSdo.Data, Errors, NodeId_q) --! TxSdo.Data should be right-justified (zero-padded to the left)
    begin
        if CurrentState = STATE_SDO then
            if RxSdo.Cs = CanOpen.SDO_CCS_IDR then --! Initiate Download (write) Response; writes to OD registers handled in individual processes
                TxSdo.N <= b"00";
                case RxSdo.Mux is
                    when CanOpen.ODI_DEVICE_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_ERROR =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_SYNC =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_ID_LENGTH =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_ID_VENDOR =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_ID_SERIAL =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_HEARTBEAT_PRODUCER_TIME =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_SDO_SERVER_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_SDO_SERVER_RX_ID =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_SDO_SERVER_TX_ID =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO1_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO1_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO1_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO2_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO2_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO2_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO3_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO3_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO3_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO4_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO4_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO4_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO1_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO2_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO3_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_TPDO4_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when CanOpen.ODI_NMT_STARTUP =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_RO;
                    when others =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.Data <= CanOpen.SDO_ABORT_DNE;
                end case;
            elsif RxSdo.Cs = CanOpen.SDO_CCS_IUR then --! Initiate Upload (read) Request
                case RxSdo.Mux is
                    when CanOpen.ODI_DEVICE_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <= DEFAULT_CANOPEN_DEVICE_TYPE;
                    when CanOpen.ODI_ERROR =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"000000" & Errors;
                    when CanOpen.ODI_SYNC =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <= b"000000000000000000000" & CanOpen.FUNCTION_CODE_SYNC & CanOpen.BROADCAST_NODE_ID;
                    when CanOpen.ODI_ID_LENGTH =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000002";
                    when CanOpen.ODI_ID_VENDOR =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <= DEFAULT_CANOPEN_ID_VENDOR;
                    when CanOpen.ODI_ID_PRODUCT =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <= DEFAULT_CANOPEN_ID_PRODUCT;
                    when CanOpen.ODI_HEARTBEAT_PRODUCER_TIME =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"10";
                        TxSdo.Data <= x"0000" & DEFAULT_CANOPEN_HEARTBEAT_PRODUCER_TIME;
                    when CanOpen.ODI_SDO_SERVER_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000002";
                    when CanOpen.ODI_SDO_SERVER_RX_ID =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <=  '0' --! valid: SDO exists / is valid
                                    & '0' --! dyn: Value is assigned statically
                                    & '0' --! frame: 11-bit CAN-ID valid (CAN base frame)
                                    & b"000000000000000000" & CanOpen.FUNCTION_CODE_SDO_RX & NodeId_q; --! 11-bit CAN-ID of the CAN base frame
                    when CanOpen.ODI_SDO_SERVER_TX_ID =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <=  '0' --! valid: SDO exists / is valid
                                    & '0' --! dyn: Value is assigned statically
                                    & '0' --! frame: 11-bit CAN-ID valid (CAN base frame)
                                    & b"000000000000000000" & CanOpen.FUNCTION_CODE_SDO_TX & NodeId_q; --! 11-bit CAN-ID of the CAN base frame
                    when CanOpen.ODI_TPDO1_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000002";
                    when CanOpen.ODI_TPDO1_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <=  DEFAULT_CANOPEN_TPDO1_DISABLE --! valid: PDO exists / is valid
                                    & '0' --! RTR: RTR allowed on this PDO
                                    & '0' --! frame: 11-bit CAN-ID valid (CAN base frame)
                                    & b"000000000000000000" & CanOpen.FUNCTION_CODE_TPDO1 & NodeId_q; --! 11-bit CAN-ID of the CAN base frame
                    when CanOpen.ODI_TPDO1_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000001"; --! synchronous (cyclic every sync)
                    when CanOpen.ODI_TPDO2_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000002";
                    when CanOpen.ODI_TPDO2_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <=  DEFAULT_CANOPEN_TPDO2_DISABLE --! valid: PDO does not exist / is not valid
                                    & '0' --! RTR: RTR allowed on this PDO
                                    & '0' --! frame: 11-bit CAN-ID valid (CAN base frame)
                                    & b"000000000000000000" & CanOpen.FUNCTION_CODE_TPDO2 & NodeId_q; --! 11-bit CAN-ID of the CAN base frame
                    when CanOpen.ODI_TPDO2_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000001"; --! synchronous (cyclic every sync)
                    when CanOpen.ODI_TPDO3_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000002";
                    when CanOpen.ODI_TPDO3_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <=  DEFAULT_CANOPEN_TPDO3_DISABLE --! valid: PDO does not exist / is not valid
                                    & '0' --! RTR: RTR allowed on this PDO
                                    & '0' --! frame: 11-bit CAN-ID valid (CAN base frame)
                                    & b"000000000000000000" & CanOpen.FUNCTION_CODE_TPDO3 & NodeId_q; --! 11-bit CAN-ID of the CAN base frame
                    when CanOpen.ODI_TPDO3_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000001"; --! synchronous (cyclic every sync)
                    when CanOpen.ODI_TPDO4_COMM_COUNT =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000002";
                    when CanOpen.ODI_TPDO4_COMM_ID =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <=  DEFAULT_CANOPEN_TPDO4_DISABLE --! valid: PDO does not exist / is not valid
                                    & '0' --! RTR: RTR allowed on this PDO
                                    & '0' --! frame: 11-bit CAN-ID valid (CAN base frame)
                                    & b"000000000000000000" & CanOpen.FUNCTION_CODE_TPDO4 & NodeId_q; --! 11-bit CAN-ID of the CAN base frame
                    when CanOpen.ODI_TPDO4_COMM_TYPE =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000001"; --! synchronous (cyclic every sync)
                    when CanOpen.ODI_TPDO1_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000000"; --! Mapping disabled
                    when CanOpen.ODI_TPDO2_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000000"; --! Mapping disabled
                    when CanOpen.ODI_TPDO3_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000000"; --! Mapping disabled
                    when CanOpen.ODI_TPDO4_MAPPING =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"11";
                        TxSdo.Data <= x"00000000"; --! Mapping disabled
                    when CanOpen.ODI_NMT_STARTUP =>
                        TxSdo.Cs <= CanOpen.SDO_SCS_IUR;
                        TxSdo.N <= b"00";
                        TxSdo.Data <= DEFAULT_CANOPEN_NMT_STARTUP;
                    when others =>
                        TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                        TxSdo.N <= b"00";
                        TxSdo.Data <= CanOpen.SDO_ABORT_DNE;
                end case;
            else
                TxSdo.Cs <= CanOpen.SDO_CS_ABORT;
                TxSdo.N <= b"00";
                TxSdo.Data <= CanOpen.SDO_ABORT_CS;
            end if;
        else
            TxSdo.Cs <= (others => '0');
            TxSdo.N <= b"00";
            TxSdo.Data <= (others => '0');
        end if;
    end process;
   
end Behavioral;
