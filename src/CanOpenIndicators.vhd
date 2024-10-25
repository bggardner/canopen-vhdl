library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.CanBus;
use work.CanOpen;

entity CanOpenIndicators is
    generic (
        CLOCK_FREQUENCY : positive -- Clock frequency in Hz
    );
    port (
        Clock       : in  std_logic; -- Clock
        Reset_n     : in  std_logic; -- Active-low reset
        NmtState    : in  std_logic_vector(6 downto 0); -- CANopen node NMT state
        CanStatus   : in  CanBus.Status;
        RunIndicator: out std_logic; -- Green
        ErrIndicator: out std_logic -- Red
    );
end entity CanOpenIndicators;

architecture Behavioral of CanOpenIndicators is
    -- CANopen indicator states per CiA 303-3
    type IndicatorState is (
        INDICATOR_OFF,      -- The LED shall be constantly off.
        INDICATOR_1FLASH,   -- That shall indicate one short flash (approximately 200 ms) followed by a long off phase (approximately 1000 ms).
        INDICATOR_2FLASH,   -- That shall indicate a sequence of two short flashes (approximately 200 ms), separated by an off phase (approximately 200 ms). The sequence is finished by a long off phase (approximately 1000 ms).
        INDICATOR_3FLASH,   -- That shall indicate a sequence of three short flashes (approximately 200 ms), separated by an off phase (approximately 200 ms). The sequence is finished by a long off phase (approximately 1000 ms).
        INDICATOR_4FLASH,   -- That shall indicate a sequence of four short flashes (approximately 200 ms), separated by an off phase (approximately 200 ms). The sequence is finished by a long off phase (approximately 1000 ms).
        INDICATOR_BLINK,    -- That shall indicate the iso-phase on and off with a frequency of approximately 2,5 Hz: on for approximately 200 ms followed by off for approximately 200 ms.
        INDICATOR_FLICKER,  -- That shall indicate the iso-phase on and off with a frequency of approximately 10 Hz: on for approximately 50 ms and off for approximately 50 ms.
        INDICATOR_ON        -- The LED shall be constantly on.
    );
    
    signal ClockEnable          : std_logic; -- Used to divide Clock from CLOCK_FREQUENCY to 20 Hz
    signal Blink                : std_logic;
    signal Flicker              : std_logic;
    signal Enable1Flash         : std_logic;
    signal Enable2Flash         : std_logic;
    signal Enable3Flash         : std_logic;
    signal Enable4Flash         : std_logic;
    signal RunState, ErrState   : IndicatorState;
begin
    -- CANopen indicator states
    RunState <= INDICATOR_BLINK     when NmtState = CanOpen.NMT_STATE_PREOPERATIONAL else
                INDICATOR_1FLASH    when NmtState = CanOpen.NMT_STATE_STOPPED else
                INDICATOR_ON        when NmtState = CanOpen.NMT_STATE_OPERATIONAL else
                INDICATOR_OFF;
    ErrState <= INDICATOR_ON        when CanBus."="(CanStatus.State, CanBus.STATE_RESET) or CanBus."="(CanStatus.State, CanBus.STATE_BUS_OFF) else
                INDICATOR_1FLASH    when CanStatus.ErrorWarning = '1' else
                INDICATOR_OFF;

    -- RunIndicator and ErrIndicator must be out of phase
    process (RunState, Enable1Flash, Enable2Flash, Enable3Flash, Enable4Flash, Blink, Flicker)
    begin
        case RunState is
            when INDICATOR_OFF =>       RunIndicator <= '0';
            when INDICATOR_1FLASH =>    RunIndicator <= Enable1Flash and Blink;
            when INDICATOR_2FLASH =>    RunIndicator <= Enable2Flash and Blink;
            when INDICATOR_3FLASH =>    RunIndicator <= Enable3Flash and Blink;
            when INDICATOR_4FLASH =>    RunIndicator <= Enable4Flash and Blink;
            when INDICATOR_BLINK =>     RunIndicator <= Blink;
            when INDICATOR_FLICKER =>   RunIndicator <= Flicker;
            when INDICATOR_ON =>        RunIndicator <= '1';
            when others =>                      RunIndicator <= '0';
        end case;
    end process;
    
    process (ErrState, Enable1Flash, Enable2Flash, Enable3Flash, Enable4Flash, Blink, Flicker)
    begin
        case ErrState is
            when INDICATOR_OFF =>       ErrIndicator <= '0';
            when INDICATOR_1FLASH =>    ErrIndicator <= Enable1Flash and not Blink;
            when INDICATOR_2FLASH =>    ErrIndicator <= Enable2Flash and not Blink;
            when INDICATOR_3FLASH =>    ErrIndicator <= Enable3Flash and not Blink;
            when INDICATOR_4FLASH =>    ErrIndicator <= Enable4Flash and not Blink;
            when INDICATOR_BLINK =>     ErrIndicator <= not Blink;
            when INDICATOR_FLICKER =>   ErrIndicator <= not Flicker;
            when INDICATOR_ON =>        ErrIndicator <= '1';
            when others =>                      ErrIndicator <= '1';
        end case;
    end process;
                
    -- Generate 20Hz clock enable for CANopen indicators
    ClockEnableProcess : process (Reset_n, Clock)
        variable Counter    : integer range 0 to CLOCK_FREQUENCY;
    begin
        if Reset_n = '0' then
            Counter := 0;
            ClockEnable <= '0';
        elsif rising_edge(Clock) then
            if Counter = (CLOCK_FREQUENCY / 20) then
                Counter := 0;
                ClockEnable <= '1';
            else
                Counter := Counter + 1;
                ClockEnable <= '0';
            end if;
        end if;
    end process;

    MainProcess : process (Reset_n, Clock)
        variable BlinkCounter   : unsigned(2 downto 0);
        variable Flash1Counter  : unsigned(4 downto 0);
        variable Flash2Counter  : unsigned(4 downto 0);
        variable Flash3Counter  : unsigned(5 downto 0);
        variable Flash4Counter  : unsigned(5 downto 0);
    begin
        if Reset_n = '0' then
            BlinkCounter := (others => '0');
            Blink <= '0';
            Flicker <= '0';
            Flash1Counter := (others => '0');
            Enable1Flash <= '0';
            Flash2Counter := (others => '0');
            Enable2Flash <= '0';
            Flash3Counter := (others => '0');
            Enable3Flash <= '0';
            Flash4Counter := (others => '0');
            Enable4Flash <= '0';
        elsif rising_edge(Clock) then
            if ClockEnable = '1' then
                BlinkCounter := BlinkCounter + 1;
                Blink <= BlinkCounter(2);
                Flicker <= not Flicker;
                if Flash1Counter = 23 then
                    Flash1Counter := (others => '0');
                else
                    Flash1Counter := Flash1Counter + 1;
                end if;
                if Flash1Counter < 8 then
                    Enable1Flash <= '1';
                else
                    Enable1Flash <= '0';
                end if;
                if Flash2Counter = 31 then
                    Flash2Counter := (others => '0');
                else
                    Flash2Counter := Flash2Counter + 1;
                end if;
                if Flash2Counter < 16 then
                    Enable2Flash <= '1';
                else
                    Enable2Flash <= '0';
                end if;
                if Flash3Counter = 39 then
                    Flash3Counter := (others => '0');
                else
                    Flash3Counter := Flash3Counter + 1;
                end if;
                if Flash3Counter < 24 then
                    Enable3Flash <= '1';
                else
                    Enable3Flash <= '0';
                end if;
                if Flash4Counter = 47 then
                    Flash4Counter := (others => '0');
                else
                    Flash4Counter := Flash4Counter + 1;
                end if;
                if Flash4Counter < 32 then
                    Enable4Flash <= '1';
                else
                    Enable4Flash <= '0';
                end if;
            end if;
        end if;
    end process;
end Behavioral;