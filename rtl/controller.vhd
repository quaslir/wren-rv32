library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity controller is
    port(

       instr: in std_logic_vector(31 downto 0);
       zero: in std_logic;
       reg_write, alu_src, illegal, pc_src: out std_logic;
       alu_op: out std_logic_vector(3 downto 0);
       imm_src: out std_logic_vector(1 downto 0);
       mem_write: out std_logic;
       result_src: out std_logic
    );
end entity controller;


architecture synth of controller is

signal branch: std_logic := '0';

alias funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);
begin
    control_unit_inst : entity work.control_unit
        port map(
            instr     => instr,
            reg_write => reg_write,
            alu_op    => alu_op,
            alu_src   => alu_src,
            illegal   => illegal,
            imm_src   => imm_src,
            branch    => branch,
            mem_write => mem_write,
            result_src => result_src
        );       
        pc_src <= branch and (funct3(2) xor zero xor funct3(0));
end architecture synth;

