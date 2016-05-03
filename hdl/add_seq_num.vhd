----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- 
-- Module Name: add_seq_num - Behavioral
--
-- Description: Add a two-byte sequence at the start of the user data 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity add_seq_num is
    Port ( clk             : in  STD_LOGIC;
           data_in         : in  STD_LOGIC_VECTOR (3 downto 0);
           user_data_in    : in  STD_LOGIC;
           data_enable_in  : in  STD_LOGIC;
           data_out        : out STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
           user_data_out   : out STD_LOGIC;
           data_enable_out : out STD_LOGIC                     := '0');
end add_seq_num;

architecture Behavioral of add_seq_num is
    signal user_data_counter   : unsigned(2 downto 0)          := (others => '0');
    signal sequence_num        : unsigned(15 downto 0)         := (others => '0');
    signal crc                 : std_logic_vector(31 downto 0) := (others => '1');
    signal trailer_left        : std_logic_vector(7 downto 0)  := (others => '0');
    signal data_enable_in_last : std_logic                     := '0';
begin

add_crc_proc: process(clk)
    begin
        if rising_edge(clk) then
            data_enable_out     <= data_enable_in;
            data_enable_in_last <= data_enable_in;
            if data_enable_in = '1' then
                user_data_out       <= user_data_in;
                data_out            <= data_in;

                --------------------------------------------------------
                -- Add the sequence number in, and shorten the user data
                --------------------------------------------------------
                if user_data_in= '1' then
                    case user_data_counter is
                        when  "000" => data_out <= std_logic_vector(sequence_num( 3 downto  0)); user_data_out <= '0';  
                        when  "001" => data_out <= std_logic_vector(sequence_num( 7 downto  4)); user_data_out <= '0';  
                        when  "010" => data_out <= std_logic_vector(sequence_num(11 downto  8)); user_data_out <= '0';  
                        when  "011" => data_out <= std_logic_vector(sequence_num(15 downto 12)); user_data_out <= '0';
                        when others => NULL;  
                    end case;
                    if user_data_counter /= "100" then
                        user_data_counter <= user_data_counter + 1;
                    end if;
                end if;
            end if;
            -----------------------------------------------------
            -- Increment the sequence number at the end of packet 
            -----------------------------------------------------
            if data_enable_in_last = '1' and data_enable_in = '0' then
                sequence_num      <= sequence_num+1;
                user_data_counter <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
