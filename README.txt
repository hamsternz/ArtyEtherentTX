ArtyEthernetTX
--------------
Transmit UDP packets via the Arty's Ethernet PHY.

Author: Mike Field <hamster@snap.net.nz>

The switches configure how often the packets are sent. 
"0000" => 1 packet per second
"0001" => 2 packet per second
"0010" => 10 packets per second 
"0011" => 20 packet per second
"0100" => 50 packets per second 
"0101" => 100 packets per second
"0110" => 200 packets per second 
"0111" => 500 packets per second 
"1000" => 1000 packets per second 
"1001" => 2000 packets per second 
"1010" => 5000 packets per second 
"1011" => 10,000 packests per second 
"1100" => 20,000 packets per second
"1101" => 50,000 packets per second 
"1110" => 100,000 packets per second
"1111" => as fast as possible

Of course, with long packets you can't send hundreds of thousands!

The packets
===========
The packet data is for UDP from port 4096 to port 4096 on the target address.
Currently they have 1040 bytes of user data, the first four of which are filled with
a 16-bit sequence number.

To adjust the length, in nibble_data.vhd change this:
    constant data_bytes        : integer := 16+1024;

And then change these line's constants, adjusting by twice as much
              ...
              when x"875" => data_valid <= '0'; user_data <= '0';
              when x"876" => NULL;
              when x"877" => NULL;
              when x"878" => NULL;
              when x"879" => NULL;
              when x"87A" => NULL;
              when x"87B" => NULL;
              when x"87C" => NULL;
              ....
              when x"8A3" => counter <= (others => '0'); busy  <= '0';


Configuring
===========
Make sure you edit these generics to set the source and destination addresses.

data: nibble_data generic map (
      -- Details for the ARTY's IP settings 
      eth_src_mac => x"DEADBEEF0123", -- A completely 'random' MAC :)
      ip_src_addr => x"0A0A0A0A",     -- 10.10.10.10
      -- details of the destination (broadcast)
      eth_dst_mac => x"A0B3CC4CF9EF", -- My laptop's MAC address
      ip_dst_addr => x"0A0A0A01"      -- 10.10.10.1
  ) port map (
