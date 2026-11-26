library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux2 is
    generic(
        WIDTH: positive := 32
        );
    port(
        d0: in std_logic_vector(WIDTH -1 downto 0);
        d1: in std_logic_vector(WIDTH - 1 downto 0);
        sel: in std_logic;
        y: out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity mux2;


architecture synth of mux2 is
    
begin
    y <= d0 when sel = '0' else d1;
end architecture synth;
