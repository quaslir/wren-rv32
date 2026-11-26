library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux4 is
    generic(
        WIDTH: positive := 32
        );
    port(
       d0: in std_logic_vector(WIDTH -1 downto 0);
        d1: in std_logic_vector(WIDTH - 1 downto 0);
         d2: in std_logic_vector(WIDTH -1 downto 0);
        d3: in std_logic_vector(WIDTH - 1 downto 0);

        sel: in std_logic_vector(1 downto 0);
        y: out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity mux4;


architecture synth of mux4 is
    
begin
    y <= d0 when sel = "00" else  -- pick one of 4 inputs by sel
    d1 when sel = "01" else
    d2 when sel = "10" else
    d3;
end architecture synth;
