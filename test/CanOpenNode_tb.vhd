library ieee;
use ieee.std_logic_1164.all;
use work.CanBus;
use work.CanOpen;

entity CanOpenNode_tb is
end CanOpenNode_tb;

architecture Behavioral of CanOpenNode_tb is
    component CanOpenNode is
        generic (
            CLOCK_FREQUENCY                 : positive; --! Clock frequency in Hz
            DEFAULT_CANOPEN_DEVICE_TYPE     : std_logic_vector(31 downto 0) := (others => '0'); --! 0 is non-standard device type
            DEFAULT_CANOPEN_ID_VENDOR       : std_logic_vector(31 downto 0) := (others => '0'); --! 0 is unassigned by CiA
            DEFAULT_CANOPEN_ID_PRODUCT      : std_logic_vector(31 downto 0) := (others => '0');
            DEFAULT_CANOPEN_HEARTBEAT_PRODUCER_TIME  : std_logic_vector(15 downto 0) := x"03E8";
            DEFAULT_CANOPEN_TPDO1_DISABLE   : std_logic := '0';
            DEFAULT_CANOPEN_TPDO2_DISABLE   : std_logic := '0';
            DEFAULT_CANOPEN_TPDO3_DISABLE   : std_logic := '0';
            DEFAULT_CANOPEN_TPDO4_DISABLE   : std_logic := '0';
            DEFAULT_CANOPEN_NMT_STARTUP     : std_logic_vector(31 downto 0) := x"00000000"
        );
        port (
            --! Signals common to all CANopen nodes
            Clock           : in  std_logic;
            Reset_n         : in  std_logic;
            
            CanRx           : in  std_logic;
            CanTx           : out std_logic;
            
            NodeId          : in integer range 1 to 127;
    
            NmtState        : out std_logic_vector(6 downto 0);
            CanStatus       : out CanBus.Status;
            
            Sync            : out std_logic;
            Gfc             : out std_logic
        );
    end component CanopenNode;
    
    component CanOpenIndicators is
        generic (
            CLOCK_FREQUENCY : positive --! Clock frequency in Hz
        );
        port (
            Clock       : in  std_logic; --! Clock
            Reset_n     : in  std_logic; --! Active-low reset
            NmtState    : in  std_logic_vector(6 downto 0);
            CanStatus   : in  CanBus.Status;
            RunIndicator: out std_logic; --! Green
            ErrIndicator: out std_logic --! Red
        );
    end component CanOpenIndicators;
    
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
    
    signal Clock        : std_logic;
    signal Reset_n      : std_logic;
    signal CanRx, CanTx, CanStimulus : std_logic;
    signal TxFrame      : CanBus.Frame;
    signal RxFifoWriteEnable, TxFifoReadEnable, TxFifoEmpty : std_logic;
    signal NmtState     : std_logic_vector(6 downto 0);
    signal CanStatus    : CanBus.Status;
begin
    Node : CanOpenNode
        generic map (
            CLOCK_FREQUENCY => 24000000
        )
        port map (
            Clock => Clock,
            Reset_n => Reset_n,
            CanRx => CanRx,
            CanTx => CanTx,
            NodeId => 5,
            NmtState => NmtState,
            CanStatus => CanStatus,
            Sync => open,
            Gfc => open
        );
        
    Indicators : CanOpenIndicators
        generic map (
            CLOCK_FREQUENCY => 24000000
        )
        port map (
            Clock => Clock,
            Reset_n => Reset_n,
            NmtState => NmtState,
            CanStatus => CanStatus,
            RunIndicator => open,
            ErrIndicator => open
        );
        
    Stimulus : CanLite
        port map (
            Clock => Clock,
            Reset_n => Reset_n,
            CanRx => CanRx,
            CanTx => CanStimulus,
            RxFrame => open,
            RxFifoWriteEnable => RxFifoWriteEnable,
            RxFifoFull => '0',
            TxFrame => TxFrame,
            TxFifoReadEnable => TxFifoReadEnable,
            TxFifoEmpty => TxFifoEmpty,
            TxAck => open,
            Status => open
        );
    
    CanRx <= CanTx and CanStimulus;
    
    process --! 24MHz clock
    begin
        Clock <= '0';
        wait for 20.833ns;
        Clock <= '1';
        wait for 20.833ns;
    end process;
    
    process
    begin
        Reset_n <= '0';
        TxFrame <= (
            Id => (others => '0'),
            Rtr => '0',
            Ide => '0',
            Dlc => (others => '0'),
            Data => (others => (others => '0'))
        );  
        TxFifoEmpty <= '1';
        wait for 10us;
        Reset_n <= '1';
        --wait until rising_edge(RxFifoWriteEnable); --! Wait for bootup message
        wait for 100us;
        
        wait until falling_edge(Clock);
        TxFrame <= (
            Id => b"000000000000000000" & b"11000000101", --! SDO Request
            Rtr => '0',
            Ide => '0',
            Dlc => b"1111",
            Data => (
                0 => x"40", --! Upload
                1 => x"18", --! Identity object length
                2 => x"10",
                3 => x"00",
                others => (others => '0')
            )
        );  
        TxFifoEmpty <= '0'; --! Trigger send
        wait until rising_edge(TxFifoReadEnable); --! Wait until acknowledged
        wait until falling_edge(Clock);
        TxFifoEmpty <= '1'; --! Do not send again
        --wait until rising_edge(RxFifoWriteEnable); --! Wait until SDO response is received
        wait for 250us;

        wait until falling_edge(Clock);
        TxFrame <= (
            Id => b"000000000000000000" & CanOpen.FUNCTION_CODE_NMT & CanOpen.NMT_NODE_CONTROL,
            Rtr => '0',
            Ide => '0',
            Dlc => b"0010",
            Data => (
                0 => CanOpen.NMT_NODE_CONTROL_OPERATIONAL,
                1 => '0' & CanOpen.BROADCAST_NODE_ID,
                others => (others => '0')
            )
        );  
        TxFifoEmpty <= '0'; --! Trigger send
        wait until rising_edge(TxFifoReadEnable); --! Wait until acknowledged
        wait until falling_edge(Clock);
        TxFifoEmpty <= '1'; --! Do not send again
        --wait until rising_edge(RxFifoWriteEnable); --! Wait until SDO response is received
        wait for 100us;
        
        wait until falling_edge(Clock);
        TxFrame <= (
            Id => b"000000000000000000" & CanOpen.FUNCTION_CODE_SYNC & b"0000000",
            Rtr => '0',
            Ide => '0',
            Dlc => b"0000",
            Data => (others => (others => '0'))
        );  
        TxFifoEmpty <= '0'; --! Trigger send
        wait until rising_edge(TxFifoReadEnable); --! Wait until acknowledged
        wait until falling_edge(Clock);
        TxFifoEmpty <= '1'; --! Do not send again
        --wait until rising_edge(RxFifoWriteEnable); --! Wait until SDO response is received
        wait for 500us;
        
        wait until falling_edge(Clock);
        TxFrame <= (
            Id => b"000000000000000000" & CanOpen.FUNCTION_CODE_NMT & CanOpen.NMT_GFC,
            Rtr => '0',
            Ide => '0',
            Dlc => b"0000",
            Data => (others => (others => '0'))
        );  
        TxFifoEmpty <= '0'; --! Trigger send
        wait until rising_edge(TxFifoReadEnable); --! Wait until acknowledged
        wait until falling_edge(Clock);
        TxFifoEmpty <= '1'; --! Do not send again
        --wait until rising_edge(RxFifoWriteEnable); --! Wait until SDO response is received
        wait for 100us;
        
        wait;
    end process;

end Behavioral;
