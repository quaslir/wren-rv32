library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity extend is
    port(
        instr: in std_logic_vector(31 downto 0);
        imm_ext: out std_logic_vector(31 downto 0)
    );
end entity extend;


architecture synth of extend is
    signal imm : std_logic_vector(11 downto 0);
begin
    imm <= instr(31 downto 20);
    imm_ext <= (31 downto 12 => imm(11)) & imm;
end architecture synth;
