library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    
use work.CanBus;
use work.CanOpen;

entity CanOpenIndicators_tb is
end CanOpenIndicators_tb;

architecture Behavioral of CanOpenIndicators_tb is
    constant CLOCK_FREQUENCY : positive := 24000000;
    
    signal Clock,
           Reset_n : std_logic;
           
    signal Status : CanOpen.Status;
    
    signal Indicators : CanOpen.Indicators;
    
    component CanOpenIndicators is
        generic (
            CLOCK_FREQUENCY : positive -- Clock frequency in Hz
        );
        port (
            Clock       : in  std_logic; -- Clock
            Reset_n     : in  std_logic; -- Active-low reset
            Status      : in CanOpen.Status;
            Indicators  : out CanOpen.Indicators
        );
    end component CanOpenIndicators;
begin

    uut : CanOpenIndicators
        generic map (
            CLOCK_FREQUENCY => CLOCK_FREQUENCY
        )
        port map (
            Clock => Clock,
            Reset_n => Reset_n,
            Status => Status,
            Indicators => Indicators
        );
        
    process
    begin
        Clock <= '0';
        wait for 1 sec / CLOCK_FREQUENCY / 2;
        Clock <= '1';
        wait for 1 sec / CLOCK_FREQUENCY / 2;
    end process;
    
    process
    begin
        Reset_n <= '0';
        Status <= (
            CanStatus => (
                State => CanBus.STATE_BUS_OFF,
                ErrorWarning => '1',
                Overflow => '0'
            ),
            NmtState => CanOpen.NMT_STATE_PREOPERATIONAL,
            AutoBitrateOrLss => '1',
            InvalidConfiguration => '1',
            ErrorControlEvent => '1',
            SyncError => '1',
            EventTimerError => '1',
            ProgramDownload => '0'
        );
        wait for 1 us;
        Reset_n <= '1';
        -- Err should be on
        -- Run should be flickering
        wait for 200 ms;
        Status.CanStatus.State <= CanBus.STATE_ERROR_ACTIVE;
        -- Err should be flickering
        -- Run should be flickering
        wait for 400 ms;
        Status.AutoBitrateOrLss <= '0';
        -- Err should be blinking
        -- Run should be blinking
        wait for 600 ms;
        Status.InvalidConfiguration <= '0';
        Status.NmtState <= CanOpen.NMT_STATE_STOPPED;
        -- Err should be 1-flashing
        -- Run should be 1-flashing
        wait for 1600 ms;
        Status.CanStatus.ErrorWarning <= '0';
        Status.NmtState <= CanOpen.NMT_STATE_OPERATIONAL;
        -- Err should be 2-flashing
        -- Run should be on
        wait for 2000 ms;
        Status.ErrorControlEvent <= '0';
        Status.ProgramDownload <= '1';
        -- Err should be 3-flashing
        -- Run should be 3-flashing
        wait for 2600 ms;
        Status.SyncError <= '0';
        Status.ProgramDownload <= '0';
        -- Err should be 4-flashing
        -- Run should be on
        wait for 3200 ms;
        Status.EventTimerError <= '0';
        Status.NmtState <= CanOpen.NMT_STATE_INITIALISATION;
        -- Err should be off
        -- Run should be off
        wait; -- Run simulation for 13 seconds
    end process;

end Behavioral;
