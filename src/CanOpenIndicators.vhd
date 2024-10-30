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
        Status      : in CanOpen.Status;
        Indicators  : out CanOpen.Indicators
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
    
    signal Blink,
           Flicker,
           Flash1Enable,
           Flash2Enable,
           Flash3Enable,
           Flash4Enable,
           ErrorControlEventInterrupt,
           ErrorControlEventInterruptEnable,
           SyncErrorInterrupt,
           SyncErrorInterruptEnable,
           EventTimerErrorInterrupt,
           EventTimerErrorInterruptEnable : std_logic;
           
    signal ErrState,
           RunState : IndicatorState;
begin

    ErrState <= INDICATOR_ON        when CanBus."="(Status.CanStatus.State, CanBus.STATE_RESET) or CanBus."="(Status.CanStatus.State, CanBus.STATE_BUS_OFF) else
                INDICATOR_FLICKER   when Status.AutoBitrateOrLss = '1' else
                INDICATOR_BLINK     when Status.InvalidConfiguration = '1' else
                INDICATOR_1FLASH    when Status.CanStatus.ErrorWarning = '1' else
                INDICATOR_2FLASH    when ErrorControlEventInterrupt = '1' else
                INDICATOR_3FLASH    when SyncErrorInterrupt = '1' else
                INDICATOR_4FLASH    when EventTimerErrorInterrupt = '1' else
                INDICATOR_OFF;
                
    RunState <= INDICATOR_FLICKER   when Status.AutoBitrateOrLss = '1' else
                INDICATOR_BLINK     when Status.NmtState = CanOpen.NMT_STATE_PREOPERATIONAL else
                INDICATOR_1FLASH    when Status.NmtState = CanOpen.NMT_STATE_STOPPED else
                INDICATOR_3FLASH    when Status.ProgramDownload = '1' else
                INDICATOR_ON        when Status.NmtState = CanOpen.NMT_STATE_OPERATIONAL else
                INDICATOR_OFF;

    -- RunIndicator and ErrIndicator must be out of phase
    process (RunState, Flash1Enable, Flash2Enable, Flash3Enable, Flash4Enable, Blink, Flicker)
    begin
        case RunState is
            when INDICATOR_ON =>        Indicators.Run <= '1';
            when INDICATOR_OFF =>       Indicators.Run <= '0';
            when INDICATOR_FLICKER =>   Indicators.Run <= Flicker;
            when INDICATOR_BLINK =>     Indicators.Run <= Blink;
            when INDICATOR_1FLASH =>    Indicators.Run <= Flash1Enable and Blink;
            when INDICATOR_2FLASH =>    Indicators.Run <= Flash2Enable and Blink;
            when INDICATOR_3FLASH =>    Indicators.Run <= Flash3Enable and Blink;
            when INDICATOR_4FLASH =>    Indicators.Run <= Flash4Enable and Blink;
            when others =>              Indicators.Run <= '0';
        end case;
    end process;
    
    process (ErrState, Flash1Enable, Flash2Enable, Flash3Enable, Flash4Enable, Blink, Flicker)
    begin
        case ErrState is
            when INDICATOR_ON =>        Indicators.Err <= '1';
            when INDICATOR_OFF =>       Indicators.Err <= '0';
            when INDICATOR_FLICKER =>   Indicators.Err <= not Flicker;
            when INDICATOR_BLINK =>     Indicators.Err <= not Blink;
            when INDICATOR_1FLASH =>    Indicators.Err <= Flash1Enable and not Blink;
            when INDICATOR_2FLASH =>    Indicators.Err <= Flash2Enable and not Blink;
            when INDICATOR_3FLASH =>    Indicators.Err <= Flash3Enable and not Blink;
            when INDICATOR_4FLASH =>    Indicators.Err <= Flash4Enable and not Blink;
            when others =>              Indicators.Err <= '1';
        end case;
    end process;

    process (Reset_n, Clock)
        constant CLOCK_PRESCALER    : natural := CLOCK_FREQUENCY / 20 - 1; -- 20 Hz
        variable ClockCounter       : natural range 0 to CLOCK_PRESCALER;
    
        constant FLASH_OFF_COUNT    : natural := 15; -- (15 + 1) / 20 Hz = 1000 ms
    
        constant BLINK_COUNT    : natural := 3; -- (3 + 1) / 20 Hz = 200 ms
        variable BlinkCounter   : natural range 0 to BLINK_COUNT;
        
        constant FLASH1_ENABLE_COUNT : natural := 8; -- 8 / 20 Hz = 400 ms
        constant FLASH1_COUNT   : natural := FLASH1_ENABLE_COUNT + FLASH_OFF_COUNT;
        variable Flash1Counter  : natural range 0 to FLASH1_COUNT;
        
        constant FLASH2_ENABLE_COUNT : natural := FLASH1_ENABLE_COUNT * 2;
        constant FLASH2_COUNT   : natural := FLASH2_ENABLE_COUNT + FLASH_OFF_COUNT;
        variable Flash2Counter  : natural range 0 to FLASH2_COUNT;
        
        constant FLASH3_ENABLE_COUNT : natural := FLASH1_ENABLE_COUNT * 3;
        constant FLASH3_COUNT   : natural := FLASH3_ENABLE_COUNT + FLASH_OFF_COUNT;
        variable Flash3Counter  : natural range 0 to FLASH3_COUNT;
        
        constant FLASH4_ENABLE_COUNT : natural := FLASH1_ENABLE_COUNT * 4; 
        constant FLASH4_COUNT   : natural := FLASH4_ENABLE_COUNT + FLASH_OFF_COUNT;
        variable Flash4Counter  : natural range 0 to FLASH4_COUNT;
    begin
        if Reset_n = '0' then
            BlinkCounter := 0;
            Blink <= '0';
            Flicker <= '0';
            Flash1Counter := 0;
            Flash1Enable <= '0';
            Flash2Counter := 0;
            Flash2Enable <= '0';
            Flash3Counter := 0;
            Flash3Enable <= '0';
            Flash4Counter := 0;
            Flash4Enable <= '0';
            ErrorControlEventInterrupt <= '0';
            ErrorControlEventInterruptEnable <= '0';
            SyncErrorInterrupt <= '0';
            SyncErrorInterruptEnable <= '0';
            EventTimerErrorInterrupt <= '0';
            EventTimerErrorInterruptEnable <= '0';
        elsif rising_edge(Clock) then
            if ClockCounter < CLOCK_PRESCALER then
                ClockCounter := ClockCounter + 1;
            else
                ClockCounter := 0;
                Flicker <= not Flicker;
                if BlinkCounter < BLINK_COUNT then
                    BlinkCounter := BlinkCounter + 1;
                else
                    BlinkCounter := 0;
                    Blink <= not Blink;
                end if;
                if Flash1Counter < FLASH1_COUNT then
                    Flash1Counter := Flash1Counter + 1;
                else
                    Flash1Counter := 0;
                end if;
                if Flash1Counter < FLASH1_ENABLE_COUNT then
                    Flash1Enable <= '1';
                else
                    Flash1Enable <= '0';
                end if;
                if Flash2Counter < FLASH2_COUNT then
                    Flash2Counter := Flash2Counter + 1;
                else
                    Flash2Counter := 0;
                    if ErrorControlEventInterruptEnable = '1' then
                        ErrorControlEventInterrupt <= '1';
                    elsif ErrState = INDICATOR_2FLASH then
                        ErrorControlEventInterrupt <= '0';
                    end if;
                end if;
                if Flash2Counter < FLASH2_ENABLE_COUNT then
                    Flash2Enable <= '1';
                else
                    Flash2Enable <= '0';
                end if;
                if Flash3Counter < FLASH3_COUNT then
                    Flash3Counter := Flash3Counter + 1;
                else
                    Flash3Counter := 0;
                    if SyncErrorInterruptEnable = '1' then
                        SyncErrorInterrupt <= '1';
                    elsif ErrState = INDICATOR_3FLASH then
                        SyncErrorInterrupt <= '0';
                    end if;
                end if;
                if Flash3Counter < FLASH3_ENABLE_COUNT then
                    Flash3Enable <= '1';
                else
                    Flash3Enable <= '0';
                end if;
                if Flash4Counter < FLASH4_COUNT then
                    Flash4Counter := Flash4Counter + 1;
                else
                    Flash4Counter := 0;
                    if EventTimerErrorInterruptEnable = '1' then
                        EventTimerErrorInterrupt <= '1';
                    elsif ErrState = INDICATOR_4FLASH then
                        EventTimerErrorInterrupt <= '0';
                    end if;
                end if;
                if Flash4Counter < FLASH4_ENABLE_COUNT then
                    Flash4Enable <= '1';
                else
                    Flash4Enable <= '0';
                end if;
            end if;
            if Status.ErrorControlEvent = '1' then
                ErrorControlEventInterruptEnable <= '1';
            elsif ErrorControlEventInterrupt = '1' then
                ErrorControlEventInterruptEnable <= '0';
            end if;
            if Status.SyncError = '1' then
                SyncErrorInterruptEnable <= '1';
            elsif SyncErrorInterrupt = '1' then
                SyncErrorInterruptEnable <= '0';
            end if;
            if Status.EventTimerError = '1' then
                EventTimerErrorInterruptEnable <= '1';
            elsif EventTimerErrorInterrupt = '1' then
                EventTimerErrorInterruptEnable <= '0';
            end if;
        end if;
    end process;
end Behavioral;