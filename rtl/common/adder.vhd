library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is
    generic (
        WIDTH: positive := 32
        );
    port(
        a: in std_logic_vector(WIDTH - 1 downto 0);
        b: in std_logic_vector(WIDTH - 1 downto 0);
        y: out std_logic_vector(WIDTH - 1 downto 0)

    );
end entity adder;


architecture synth of adder
is
    
begin
    y <= std_logic_vector(unsigned(a) + unsigned(b));
end architecture synth;
