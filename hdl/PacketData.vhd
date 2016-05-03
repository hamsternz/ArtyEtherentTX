----------------------------------------------------------------------------------
-- PacketData - the data to be sent out over the LAN
--
-- Written by Mike Field (hamster@snap.net.nz)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PacketData is
    Port ( Addr           : in  STD_LOGIC_VECTOR (7 downto 0);
           IPsource       : in  STD_LOGIC_VECTOR (31 downto 0);
           IPdestination  : in  STD_LOGIC_VECTOR (31 downto 0);
           phyDestination : in  STD_LOGIC_VECTOR (47 downto 0);
           phySource      : in  STD_LOGIC_VECTOR (47 downto 0);
           data           : out STD_LOGIC_VECTOR (7 downto 0);
           dataValid      : out STD_LOGIC);
end PacketData;

architecture Behavioral of PacketData is
   SIGNAL IPsource_1      : unsigned(7 downto 0);
   SIGNAL IPsource_2      : unsigned(7 downto 0);
   SIGNAL IPsource_3      : unsigned(7 downto 0);
   SIGNAL IPsource_4      : unsigned(7 downto 0);

   SIGNAL IPdestination_1 : unsigned(7 downto 0);
   SIGNAL IPdestination_2 : unsigned(7 downto 0);
   SIGNAL IPdestination_3 : unsigned(7 downto 0);
   SIGNAL IPdestination_4 : unsigned(7 downto 0);

   SIGNAL IPchecksum1     : unsigned(31 downto 0);
   SIGNAL IPchecksum2     : unsigned(31 downto 0);
   SIGNAL IPchecksum3     : unsigned(31 downto 0); 
begin
   IPsource_1 <= unsigned(IPsource(31 downto 24));
   IPsource_2 <= unsigned(IPsource(23 downto 16));
   IPsource_3 <= unsigned(IPsource(15 downto  8));
   IPsource_4 <= unsigned(IPsource( 7 downto  0));

   IPdestination_1 <= unsigned(IPdestination(31 downto 24));
   IPdestination_2 <= unsigned(IPdestination(23 downto 16));
   IPdestination_3 <= unsigned(IPdestination(15 downto  8));
   IPdestination_4 <= unsigned(IPdestination( 7 downto  0));

   IPchecksum1 <= x"0000C53F" 
       + (IPsource_1 & x"00") + IPsource_2
       + (IPsource_3 & x"00") + IPsource_4
       + (IPdestination_1 & x"00") + IPdestination_2  
       + (IPdestination_3 & x"00") + IPdestination_4;

   IPchecksum2 <=      (x"0000" & IPchecksum1(31 downto 16)) + (x"0000" & IPchecksum1(15 downto 0));   
   IPchecksum3 <= NOT ((x"0000" & IPchecksum2(31 downto 16)) + (x"0000" & IPchecksum2(15 downto 0)));


   process (addr)
   begin
      dataValid <= '1';
      case addr is
         --a Ethernet header
         when x"00"  => data <= PhyDestination(47 downto 40);
         when x"01"  => data <= PhyDestination(39 downto 32);
         when x"02"  => data <= PhyDestination(31 downto 24);
         when x"03"  => data <= PhyDestination(23 downto 16);
         when x"04"  => data <= PhyDestination(15 downto  8);
         when x"05"  => data <= PhyDestination( 7 downto  0);   
         when x"06"  => data <= PhySource(47 downto 40);
         when x"07"  => data <= PhySource(39 downto 32);
         when x"08"  => data <= PhySource(31 downto 24);
         when x"09"  => data <= PhySource(23 downto 16);
         when x"0A"  => data <= PhySource(15 downto  8);
         when x"0B"  => data <= PhySource( 7 downto  0);
         -- Ethernet type         
         when x"0C"  => data <= x"08";
         when x"0D"  => data <= x"00";
         
         --a IP header
         when x"0E"  => data <= x"45";
         when x"0F"  => data <= x"00";
         when x"10"  => data <= x"00";
         when x"11"  => data <= x"2E";
         when x"12"  => data <= x"00";
         when x"13"  => data <= x"00";
         when x"14"  => data <= x"00";
         when x"15"  => data <= x"00";
         when x"16"  => data <= x"80";
         when x"17"  => data <= x"11";
         when x"18"  => data <= std_logic_vector(IPchecksum3(15 downto 8));
         when x"19"  => data <= std_logic_vector(IPchecksum3(7 downto 0));
         when x"1A"  => data <= std_logic_vector(IPsource_1);
         when x"1B"  => data <= std_logic_vector(IPsource_2);
         when x"1C"  => data <= std_logic_vector(IPsource_3);
         when x"1D"  => data <= std_logic_vector(IPsource_4);
         when x"1E"  => data <= std_logic_vector(IPdestination_1);
         when x"1F"  => data <= std_logic_vector(IPdestination_2);
         when x"20"  => data <= std_logic_vector(IPdestination_3);
         when x"21"  => data <= std_logic_vector(IPdestination_4);
         
         --a UDP header
         when x"22"  => data <= x"04";
         when x"23"  => data <= x"00";
         when x"24"  => data <= x"04";
         when x"25"  => data <= x"00";
         when x"26"  => data <= x"00";
         when x"27"  => data <= x"1A";
         when x"28"  => data <= x"00";
         when x"29"  => data <= x"00";
         
         --   the payload
         when x"2A"  => data <= x"00"; -- put the data that you want to send here
         when x"2B"  => data <= x"01"; -- put the data that you want to send here
         when x"2C"  => data <= x"02"; -- put the data that you want to send here
         when x"2D"  => data <= x"03"; -- put the data that you want to send here
         when x"2E"  => data <= x"04"; -- put the data that you want to send here
         when x"2F"  => data <= x"05"; -- put the data that you want to send here
         when x"30"  => data <= x"06"; -- put the data that you want to send here
         when x"31"  => data <= x"07"; -- put the data that you want to send here
         when x"32"  => data <= x"08"; -- put the data that you want to send here
         when x"33"  => data <= x"09"; -- put the data that you want to send here
         when x"34"  => data <= x"0A"; -- put the data that you want to send here
         when x"35"  => data <= x"0B"; -- put the data that you want to send here
         when x"36"  => data <= x"0C"; -- put the data that you want to send here
         when x"37"  => data <= x"0D"; -- put the data that you want to send here
         when x"38"  => data <= x"0E"; -- put the data that you want to send here
         when x"39"  => data <= x"0F"; -- put the data that you want to send here
         when x"3A"  => data <= x"10"; -- put the data that you want to send here
         when x"3B"  => data <= x"11"; -- put the data that you want to send here
         when others => data <= x"00";
                        dataValid <= '0';
      end case;
   end process;
end Behavioral;