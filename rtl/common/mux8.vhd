library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux8 is
    generic(
        WIDTH: positive := 32
        );
    port(
       d0: in std_logic_vector(WIDTH -1 downto 0);
        d1: in std_logic_vector(WIDTH - 1 downto 0);
         d2: in std_logic_vector(WIDTH -1 downto 0);
        d3: in std_logic_vector(WIDTH - 1 downto 0);

        d4: in std_logic_vector(WIDTH -1 downto 0);
        d5: in std_logic_vector(WIDTH - 1 downto 0);
         d6: in std_logic_vector(WIDTH -1 downto 0);
        d7: in std_logic_vector(WIDTH - 1 downto 0);

        sel: in std_logic_vector(2 downto 0);
        y: out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity mux8;


architecture synth of mux8 is
    
begin
    y <= d0 when sel = "000" else 
    d1 when sel = "001" else
    d2 when sel = "010" else
    d3 when sel = "011" else 
    d4 when sel = "100" else
    d5 when sel = "101" else
    d6 when sel = "110" else
    d7;
end architecture synth;
