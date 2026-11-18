library ieee;
use ieee.std_logic_1164.all;

entity controller is
    port(

       instr: in std_logic_vector(31 downto 0);
       zero: in std_logic;
       addr_lo: in std_logic_vector(1 downto 0);
       reg_write, alu_src, illegal, pc_src, misaligned: out std_logic;
       alu_op: out std_logic_vector(3 downto 0);
       imm_src: out std_logic_vector(2 downto 0);
       mem_write: out std_logic;
       result_src: out std_logic_vector(1 downto 0)

    );
end entity controller;


architecture synth of controller is

signal branch: std_logic := '0';
signal reg_write_raw: std_logic := '0';
signal mem_write_raw: std_logic := '0';
signal mem_access: std_logic := '0';
signal mis: std_logic := '0';
alias funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);
alias size: std_logic_vector(1 downto 0) is funct3(1 downto 0);
begin
    control_unit_inst : entity work.control_unit
        port map(
            instr     => instr,
            reg_write => reg_write_raw,
            alu_op    => alu_op,
            alu_src   => alu_src,
            illegal   => illegal,
            imm_src   => imm_src,
            branch    => branch,
            mem_write => mem_write_raw,
            result_src => result_src,
            mem_access => mem_access
        );       
        mis <= '1' when mem_access = '1' and size = "01" and addr_lo(0) = '1' else
            '1' when mem_access = '1' and size = "10" and (addr_lo(0) = '1' or addr_lo(1) = '1') else
            '0';
        reg_write <= reg_write_raw and not mis;
        mem_write <= mem_write_raw and not mis;
        misaligned <= mis;
        pc_src <= branch and (funct3(2) xor zero xor funct3(0));
end architecture synth;

