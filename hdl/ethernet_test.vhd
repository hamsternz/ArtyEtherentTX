----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- 
-- Module Name: ethernet_test - Behavioral
--
-- Description: Sending UDP packets over Arty's Ethernet PHY 
-- 
-- Datasheet is available from http://www.ti.com.cn/cn/lit/ds/symlink/dp83848j.pdf
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity ethernet_test is
    Port ( CLK100MHZ   : in    STD_LOGIC;
           -- Switches
           switches    : in  STD_LOGIC_VECTOR(3 downto 0);
             
           -- control channel
           eth_mdio    : inout STD_LOGIC := '0';
           eth_mdc     : out   STD_LOGIC := '0';
           eth_rstn    : out   STD_LOGIC := '1';
           -- tx channel
           eth_tx_d    : out STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
           eth_tx_en   : out STD_LOGIC  := '0';
           eth_tx_clk  : in  STD_LOGIC;
           -- rx channel
           eth_rx_d    : in  STD_LOGIC_VECTOR(3 downto 0);
           eth_rx_err  : in  STD_LOGIC;
           eth_rx_dv   : in  STD_LOGIC;
           eth_rx_clk  : in  STD_LOGIC; 
           -- link status
           eth_col     : in  STD_LOGIC;
           eth_crs     : in  STD_LOGIC;
           -- reference clock
           eth_ref_clk : out STD_LOGIC);
end ethernet_test;

architecture Behavioral of ethernet_test is
    signal reset_counter : unsigned(24 downto 0)         := (others => '0');
    signal debug         : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
    signal phy_ready     : std_logic                     := '0';
    signal tx_ready_meta : std_logic                     := '0';
    signal tx_ready      : std_logic                     := '0';
    signal ok_to_send    : std_logic                     := '0';
    signal user_data     : std_logic                     := '0';
    signal start_sending : std_logic                     := '0';
    signal count         : unsigned(24 downto 0)         := (others => '0');
    signal max_count     : unsigned(24 downto 0)         := (others => '0');
    component nibble_data is
        generic (
            eth_src_mac       : std_logic_vector(47 downto 0);
            eth_dst_mac       : std_logic_vector(47 downto 0);
            ip_src_addr       : std_logic_vector(31 downto 0);
            ip_dst_addr       : std_logic_vector(31 downto 0));
        Port ( clk        : in STD_LOGIC;
               start      : in  STD_LOGIC;
               busy       : out STD_LOGIC;
               data       : out STD_LOGIC_VECTOR (3 downto 0);
               user_data  : out STD_LOGIC;
               data_valid : out STD_LOGIC);
    end component;

    signal nibble           : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
    signal nibble_user_data : std_logic                     := '0';
    signal nibble_valid     : std_logic                     := '0';

    component add_seq_num is
    Port ( clk             : in  STD_LOGIC;
           data_in         : in  STD_LOGIC_VECTOR (3 downto 0);
           user_data_in    : in  STD_LOGIC;
           data_enable_in  : in  STD_LOGIC;
           data_out        : out STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
           user_data_out   : out STD_LOGIC;
           data_enable_out : out STD_LOGIC                     := '0');
    end component;

    signal with_seq            : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
    signal with_seq_user_data  : std_logic                     := '0';
    signal with_seq_valid      : std_logic                     := '0';

    component add_crc32 is
        Port ( clk             : in  STD_LOGIC;
               data_in         : in  STD_LOGIC_VECTOR (3 downto 0);
               data_enable_in  : in  STD_LOGIC;
               data_out        : out STD_LOGIC_VECTOR (3 downto 0);
               data_enable_out : out STD_LOGIC);
    end component;

    signal with_crc        : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
    signal with_crc_valid  : std_logic                     := '0';
    
    component add_preamble is
        Port ( clk             : in  STD_LOGIC;
               data_in         : in  STD_LOGIC_VECTOR (3 downto 0);
               data_enable_in  : in  STD_LOGIC;
               data_out        : out STD_LOGIC_VECTOR (3 downto 0);
               data_enable_out : out STD_LOGIC);
    end component;

    signal fully_framed        : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
    signal fully_framed_valid  : std_logic                     := '0';

    --------------------------------
    -- Clocking signals 
    -------------------------------- 
    signal clk50MHz : std_logic;
    signal clk25MHz : std_logic;
    signal clkfb    : std_logic;
    signal CLK100MHz_buffered : std_logic;
begin
   ---------------------------------------------------
   -- Strapping signals
   ----------------------------------------------------
   -- No pullups/pulldowns added

   ----------------------------------------------------
   -- Scheduling when packets are sent
   ----------------------------------------------------
 when_to_send: process(eth_tx_clk) 
    begin  
        if rising_edge(eth_tx_clk) then
            case switches is
                when "0000" => max_count <= to_unsigned(24_999_999,25);  -- 1 packet per second
                when "0001" => max_count <= to_unsigned(12_499_999,25);  -- 2 packet per second
                when "0010" => max_count <= to_unsigned( 2_499_999,25);  -- 10 packets per second 
                when "0011" => max_count <= to_unsigned( 1_249_999,25);  -- 20 packet per second
                when "0100" => max_count <= to_unsigned(   499_999,25);  -- 50 packets per second 
                when "0101" => max_count <= to_unsigned(   249_999,25);  -- 100 packets per second
                when "0110" => max_count <= to_unsigned(   124_999,25);  -- 200 packets per second 
                when "0111" => max_count <= to_unsigned(    49_999,25);  -- 500 packets per second 
                when "1000" => max_count <= to_unsigned(    24_999,25);  -- 1000 packets per second 
                when "1001" => max_count <= to_unsigned(    12_499,25);  -- 2000 packets per second 
                when "1010" => max_count <= to_unsigned(     4_999,25);  -- 5000 packets per second 
                when "1011" => max_count <= to_unsigned(     2_499,25);  -- 10,000 packests per second 
                when "1100" => max_count <= to_unsigned(       999,25);  -- 20,000 packets per second
                when "1101" => max_count <= to_unsigned(       499,25);  -- 50,000 packets per second 
                when "1110" => max_count <= to_unsigned(       249,25);  -- 100,000 packets per second
                when others => max_count <= to_unsigned(         0,25);  -- as fast as possible 152,439 packets
            end case;

            if count = max_count then
                count <= (others => '0');
                start_sending <= '1';
            else
                count <= count + 1;
                start_sending <= '0';
            end if;
        end if;
    end process;
   ----------------------------------------------------
   -- Data for the packet packet 
   ----------------------------------------------------
data: nibble_data generic map (
      -- Details for the ARTY's IP settings 
      eth_src_mac => x"DEADBEEF0123", -- A completely 'random' MAC :)
      ip_src_addr => x"0A0A0A0A",     -- 10.10.10.10
      -- details of the destination (broadcast)
      eth_dst_mac => x"A0B3CC4CF9EF", -- My laptop's MAC address
      ip_dst_addr => x"0A0A0A01"      -- 10.10.10.1
  ) port map (
      clk        => eth_tx_clk,
      start      => start_sending,
      busy       => open,
      data       => nibble,
      user_data  => nibble_user_data,
      Data_valid => nibble_valid);

i_add_seq_num : add_seq_num port map(
      clk             => eth_tx_clk,
      data_in         => nibble,
      user_data_in    => nibble_user_data,
      data_enable_in  => nibble_valid,
      data_out        => with_seq,
      user_data_out   => with_seq_user_data,
      data_enable_out => with_seq_valid);

i_add_crc32: add_crc32 port map (
      clk             => eth_tx_clk,
      data_in         => with_seq,
      data_enable_in  => with_seq_valid,
      data_out        => with_crc,
      data_enable_out => with_crc_valid);

i_add_preamble: add_preamble port map (
      clk             => eth_tx_clk,
      data_in         => with_crc,
      data_enable_in  => with_crc_valid,
      data_out        => fully_framed,
      data_enable_out => fully_framed_valid);
      
   ----------------------------------------------------
   -- Send the data out to the ethernet PHY
   -- But only when it is OK to send after the
   -- PHY has been out of reset for long enough 
   ----------------------------------------------------
send_data_out: process(eth_tx_clk)
    begin
       if falling_edge(eth_tx_clk) then
           eth_tx_d    <= fully_framed;
           eth_tx_en   <= fully_framed_valid and ok_to_send;
       end if;
    end process;
    
monitor_reset_state: process(eth_tx_clk)
    begin
       if rising_edge(eth_tx_clk) then
          tx_ready      <= tx_ready_meta;
          tx_ready_meta <= phy_ready;
          if tx_ready = '1' and fully_framed_valid = '0' then
             ok_to_send    <= '1';
          end if;
       end if;
    end process;

    ----------------------------------------
    -- Control reseting the PHY
    ----------------------------------------
control_reset: process(clk25MHz)
    begin
       if rising_edge(clk25MHz) then           
          if reset_counter(reset_counter'high) = '0' then
              reset_counter <= reset_counter + 1;
          end if; 
          eth_rstn  <= reset_counter(reset_counter'high) or reset_counter(reset_counter'high-1);
          phy_ready <= reset_counter(reset_counter'high);
       end if;
    end process;
    
   ----------------------------------------------------
   -- Correctly forward the clock out,so rising edge 
   -- will be in the middle of the valid data 
   ----------------------------------------------------
clock_fwd_ddr : ODDR
   generic map(
      DDR_CLK_EDGE => "SAME_EDGE", 
      INIT         => '0',
      SRTYPE       => "SYNC")
   port map (
      Q  => eth_ref_clk,
      C  => clk25MHz,
      CE => '1', R  => '0', S  => '0',
      D1 => '0', D2 => '1'
   );

   -------------------------------------------------------
   -- Generate a 25MHz and 50Mhz clocks from the 100MHz 
   -- system clock 
   -------------------------------------------------------
i_bufg: bufg port map (i => CLK100MHz, o => CLK100MHz_buffered);
clocking : PLLE2_BASE
   generic map (
      BANDWIDTH          => "OPTIMIZED",
      CLKFBOUT_MULT      => 8,
      CLKFBOUT_PHASE     => 0.0,
      CLKIN1_PERIOD      => 10.0,

      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for each CLKOUT (1-128)
      CLKOUT0_DIVIDE     => 32,  CLKOUT1_DIVIDE     => 16, CLKOUT2_DIVIDE      => 16, 
      CLKOUT3_DIVIDE     => 16,  CLKOUT4_DIVIDE     => 16, CLKOUT5_DIVIDE      => 16,

      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
      CLKOUT0_DUTY_CYCLE => 0.5, CLKOUT1_DUTY_CYCLE => 0.5, CLKOUT2_DUTY_CYCLE => 0.5,
      CLKOUT3_DUTY_CYCLE => 0.5, CLKOUT4_DUTY_CYCLE => 0.5, CLKOUT5_DUTY_CYCLE => 0.5,

      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
      CLKOUT0_PHASE      => 0.0, CLKOUT1_PHASE      => 0.0, CLKOUT2_PHASE      => 0.0,
      CLKOUT3_PHASE      => 0.0, CLKOUT4_PHASE      => 0.0, CLKOUT5_PHASE      => 0.0,

      DIVCLK_DIVIDE      => 1,
      REF_JITTER1        => 0.0,
      STARTUP_WAIT       => "FALSE"
   )
   port map (
      CLKIN1   => CLK100MHz_buffered,
      CLKOUT0 => CLK25MHz, CLKOUT1 => CLK50Mhz, 
      CLKOUT2 => open,     CLKOUT3  => open,
      CLKOUT4 => open,     CLKOUT5 => open,
      LOCKED   => open,
      PWRDWN   => '0', 
      RST      => '0',
      CLKFBOUT => clkfb,
      CLKFBIN  => clkfb
   );
end Behavioral;