-- Segmented SDO interface adapter for XPM Simple Dual Port RAM

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.ceil;
    use ieee.math_real.log2;

library xpm;
    use xpm.vcomponents.all;
    
entity SegmentedSdoXpmSdpRam is
    generic (
        WRITE_WIDTH : natural; -- in bits
        WRITE_DEPTH   : natural
    );
    port (
        Clock           : in std_logic;
        Reset_n         : in std_logic;
        WriteData       : in std_logic_vector(WRITE_WIDTH - 1 downto 0);
        WriteEnable     : in std_logic;
        ReadEnable      : in std_logic; -- Prevents writing
        ReadDataEnable  : in std_logic; -- Hold high until ReadValid goes high
        ReadData        : out std_logic_vector(55 downto 0);
        ReadValid       : out std_logic;
        WriteBusy       : out std_logic
    );
end entity SegmentedSdoXpmSdpRam;

architecture Behavioral of SegmentedSdoXpmSdpRam is

    constant WRITE_BYTES    : natural := integer(ceil(real(WRITE_WIDTH) / 8.0));
    constant WRITE_BYTE_WIDTH : natural := integer(ceil(log2(real(WRITE_BYTES))));
    constant MEMORY_SIZE    : natural := WRITE_WIDTH * WRITE_DEPTH;
    constant ADDR_WIDTH     : natural := integer(ceil(log2(real(MEMORY_SIZE) / 8.0)));
    
    signal Reset            : std_logic;
    signal ReadAddress      : unsigned(ADDR_WIDTH - 1 downto 0);
    signal WriteAddress     : unsigned(ADDR_WIDTH - 1 downto 0);
    signal ReadDataByte,
           WriteDataByte    : std_logic_vector(7 downto 0);
    signal WriteData_q      : std_logic_vector(WRITE_BYTES * 8 - 1 downto 0);
    signal WriteEnable_q    : std_logic;
    signal ReadByteCount,
           WriteByteCount   : unsigned(31 downto 0);
    signal ReadData_d       : std_logic_vector(55 downto 0);

begin

    Reset <= not Reset_n;
    ReadData <= ReadData_d;-- when ReadEnable = '1' else std_logic_vector(resize(WriteByteCount, ReadData'length));

    xpm_memory_sdpram_inst : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => ADDR_WIDTH,
            ADDR_WIDTH_B => ADDR_WIDTH,
            BYTE_WRITE_WIDTH_A => 8,
            MEMORY_SIZE => MEMORY_SIZE,
            READ_DATA_WIDTH_B => 8,
            READ_LATENCY_B => 1,
            SIM_ASSERT_CHK => 1,
            WRITE_DATA_WIDTH_A => 8
        )
        port map (
            addra => std_logic_vector(WriteAddress),
            addrb => std_logic_vector(ReadAddress),
            clka => Clock,
            clkb => Clock,
            dbiterrb => open,
            dina => WriteDataByte,
            doutb => ReadDataByte,
            ena => WriteEnable_q,
            enb => ReadDataEnable,
            injectdbiterra => '0',
            injectsbiterra => '0',
            regceb => '1',
            rstb => Reset,
            sbiterrb => open,
            sleep => '0',
            wea => b"1"
        );
        
    process (Clock, Reset_n)
        variable ReadCounter    : natural range 0 to 8;
        variable ReadAddressCounter : natural range 0 to WRITE_BYTES;
        variable ReadValid_ob   : std_logic;
        variable WriteCounter   : natural range 0 to WRITE_BYTES;
    begin
        if Reset_n = '0' then
            WriteCounter := 0;
            ReadAddressCounter := 0;
            ReadAddress <= (others => '0');
            WriteAddress <= (others => '0');
            ReadByteCount <= (others => '0');
            WriteByteCount <= (others => '0');
            WriteData_q <= (others => '0');
            WriteDataByte <= (others => '0');
            WriteEnable_q <= '0';
            ReadData_d <= (others => '0');
            ReadValid <= '0';
            ReadValid_ob := '0';
            WriteBusy <= '0';
        elsif rising_edge(Clock) then
            WriteBusy <= WriteEnable_q or WriteEnable;
            if ReadEnable = '0' then
                if WriteEnable = '1' and WriteEnable_q = '0' then
                    WriteCounter := 0;
                    WriteData_q <= WriteData;
                    WriteDataByte <= WriteData(7 downto 0);
                    WriteEnable_q <= '1';
                elsif WriteEnable_q = '1' then
                    WriteCounter := WriteCounter + 1;
                    WriteAddress <= WriteAddress + 1;
                    if WriteCounter = WRITE_BYTES then
                        WriteEnable_q <= '0';
                        if WriteByteCount + WRITE_BYTES < MEMORY_SIZE / 8 then
                            WriteByteCount <= WriteByteCount + WRITE_BYTES;
                        end if;
                    else
                        WriteDataByte <= WriteData_q(to_integer(shift_left(to_unsigned(WriteCounter, WRITE_WIDTH), 3)) + 7 downto to_integer(shift_left(to_unsigned(WriteCounter, WRITE_WIDTH), 3)));
                    end if;
                end if;
            elsif ReadByteCount = WriteByteCount then -- Successful reading
                WriteEnable_q <= '0';
                WriteByteCount <= (others => '0');
            elsif WriteEnable_q = '1' then -- Write interrupted by read
                WriteByteCount <= WriteByteCount - WriteCounter;
                WriteAddress <= WriteAddress - WriteCounter;
                WriteEnable_q <= '0';
            end if;
            if ReadDataEnable = '1' then
                if ReadCounter < 8 then
                    ReadCounter := ReadCounter + 1;
                end if;
            else
                ReadCounter := 0;
            end if;
            if ReadEnable = '0' then
                ReadAddressCounter := 0;
                ReadByteCount <= (others => '0');
                ReadAddress <= WriteAddress - WRITE_BYTES; -- Start at LSB
                ReadData_d <= x"000000" & std_logic_vector(WriteByteCount);
                ReadValid_ob := '0';
            elsif ReadDataEnable = '1' then
                if ReadValid_ob = '0' then
                    ReadData_d <= ReadDataByte & ReadData_d(55 downto 8);
                    if ReadCounter < 8 then
                        ReadByteCount <= ReadByteCount + 1;
                        ReadAddressCounter := ReadAddressCounter + 1;
                        if ReadAddressCounter = WRITE_BYTES then
                            ReadAddressCounter := 0;
                            ReadAddress <= ReadAddress - 2 * WRITE_BYTES + 1; -- Rewind to LSB of previous word
                        else
                            ReadAddress <= ReadAddress + 1;
                        end if;
                    end if;
                end if;
                if ReadCounter = 8 then
                    ReadValid_ob := '1';
                else
                    ReadValid_ob := '0';
                end if;
            else
                ReadData_d <= x"000000" & std_logic_vector(WriteByteCount);
                ReadValid_ob := '0';
            end if;
            ReadValid <= ReadValid_ob;
        end if;
    end process;
end architecture Behavioral;