-- TestBench for PR --

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity TestBench is
end TestBench;

architecture Stimulus of TestBench is
component PR is
    generic (N: integer);
    port(
        CLK, RESET : in std_logic;
        PRin : in std_logic_vector(N-1 downto 0);
        PROut : out std_logic_vector(N-1 downto 0)
    );
end component;

constant N : integer := 128;
signal CLK, RESET : std_logic;
signal PRin, PRout : std_logic_vector(N-1 downto 0);

begin

    DUT: PR generic map(N) port map (CLK, RESET, PRin, PRout);

    CLK <= '0',
           '1' after 40 ns,
           '0' after 80 ns,
           '1' after 120 ns,
           '0' after 160 ns,
           '1' after 200 ns,
           '0' after 240 ns;

    RESET <= '0',
             '1' after 20 ns; 

    PRin <= X"00000000000000000000000000000000",
            X"12345678123456781234567812345678" after 100 ns,
            X"87654321876543218765432187654321" after 180 ns;

end Stimulus;
