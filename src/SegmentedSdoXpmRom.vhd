-- SegmentedSdo interface adapter for XPM Single Port ROM

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.ceil;
    use ieee.math_real.log2;

library xpm;
    use xpm.vcomponents.all;

entity SegmentedSdoXpmRom is
    generic (
        MEM_FILE        : string;
        BYTES           : natural
    );
    port (
        Clock           : in    std_logic;
        Reset_n         : in    std_logic;
        ReadEnable      : in    std_logic;
        ReadDataEnable  : in    std_logic;
        ReadData        : out   std_logic_vector(55 downto 0);
        ReadValid       : out   std_logic
    );
end entity SegmentedSdoXpmRom;

architecture Behavioral of SegmentedSdoXpmRom is

    constant SEGMENTS       : integer := integer(ceil(real(BYTES) / 7.0));
    constant MEMORY_SIZE    : integer := SEGMENTS * 56;
    constant ADDR_WIDTH     : integer := integer(ceil(log2(real(SEGMENTS - 1))));
    
    signal Address      : unsigned(ADDR_WIDTH - 1 downto 0);
    signal Reset        : std_logic;
    signal ReadData_d       : std_logic_vector(55 downto 0);
begin

    Reset <= not Reset_n;
    
     StoreEdsMemory : xpm_memory_sprom
        generic map (
            ADDR_WIDTH_A => ADDR_WIDTH,
            MEMORY_INIT_FILE => MEM_FILE,
            MEMORY_SIZE => SEGMENTS * 56,
            READ_DATA_WIDTH_A => 56,
            READ_LATENCY_A => 1
        )
        port map (
            dbiterra => open,
            douta => ReadData_d,
            sbiterra => open,
            addra => std_logic_vector(Address),
            clka => Clock,
            ena => ReadEnable,
            injectdbiterra => '0',
            injectsbiterra => '0',
            regcea => '1',
            rsta => Reset,
            sleep => '0'
        );

    process (Clock, Reset_n)
        variable ReadValid_ob   : std_logic;
        variable EndOfMemory    : boolean;
    begin
        if Reset_n = '0' then
            Address <= (others => '0');
            ReadData <= std_logic_vector(to_unsigned(BYTES, ReadData'length));
            ReadValid <= '0';
            ReadValid_ob := '0';
            EndOfMemory := false;
        elsif rising_edge(Clock) then
            if ReadEnable = '0' then
                Address <= (others => '0');
                ReadData <= std_logic_vector(to_unsigned(BYTES, ReadData'length));
                ReadValid_ob := '0';
                EndOfMemory := false;
            elsif ReadDataEnable = '1' and ReadValid_ob = '0' and not EndOfMemory then
                if Address = SEGMENTS - 1 then
                    EndOfMemory := true;
                else
                    Address <= Address + 1;
                end if;
                ReadData <= ReadData_d;
                ReadValid_ob := '1';
            else
                ReadValid_ob := '0';
            end if;
        end if;
        ReadValid <= ReadValid_ob;
    end process;
end architecture Behavioral;