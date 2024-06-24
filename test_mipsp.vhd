-- TestBench for MIPSp --

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity TestBench is
end TestBench;

architecture Stimulus of TestBench is
component MIPSp is
    port(
        CLK, RESET : in std_logic;
        PCOut : out std_logic_vector(7 downto 0)
    );
end component;

constant CLK_PERIOD : time := 80 ns;  -- Clock 12.5MHz
constant SETUP_TIME : time := 10 ns;
signal CLK, RESET : std_logic;
signal PCOut : std_logic_vector(7 downto 0);

begin

    DUT: MIPSp port map (CLK, RESET, PCout);

    CLOCK: process
    begin
        CLK <= '0';
        wait for SETUP_TIME;
        CLK <= '1';
        wait for CLK_PERIOD/2;
        CLK <= '0';
        wait for CLK_PERIOD/2-SETUP_TIME;
    end process CLOCK;	

    RESET <= '0',
             '1' after 20 ns; 

end Stimulus;
