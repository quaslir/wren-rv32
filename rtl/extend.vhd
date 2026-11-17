library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity extend is
    port(
        instr: in std_logic_vector(31 downto 0);
        imm_src: in std_logic_vector(2 downto 0);
        imm_ext: out std_logic_vector(31 downto 0)
    );
end entity extend;


architecture synth of extend is
begin

      with imm_src select
        imm_ext <=
            (31 downto 12  => instr(31)) & instr(31 downto 20) when "000",
            (31 downto 12 => instr(31)) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0' when "010",
            (31 downto 12 => instr(31)) & instr(31 downto 25) & instr(11 downto 7) when "001",
            (others => '0') when others;
    
end architecture synth;
