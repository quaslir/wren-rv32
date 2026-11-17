library ieee;
use ieee.std_logic_1164.all;

entity core is
    port(
        clk : in std_logic;
        rst : in std_logic;
        instr: in std_logic_vector(31 downto 0);
        read_data: in std_logic_vector(31 downto 0);
        illegal: out std_logic;
        alu_result: out std_logic_vector(31 downto 0);
        pc: out std_logic_vector(31 downto 0);
        mem_write: out std_logic;
        write_data: out std_logic_vector(31 downto 0)
    );
end entity core;


architecture synth of core is
    signal reg_write : std_logic      := '0';              
    signal alu_op    : std_logic_vector(3 downto 0);
    signal alu_src   : std_logic         :='0';         
    signal imm_src   : std_logic_vector(2 downto 0) := (others => '0');
    signal pc_src    : std_logic  := '0';              
    signal result_src: std_logic_vector(1 downto 0) := (others => '0');
    signal zero : std_logic := '0';

begin
controller_inst : entity work.controller
    port map(
        instr     => instr,
        zero      => zero,
        reg_write => reg_write,
        alu_src   => alu_src,
        illegal   => illegal,
        pc_src    => pc_src,
        alu_op    => alu_op,
        imm_src   => imm_src,
        mem_write => mem_write,
        result_src => result_src
    );

    datapath_inst : entity work.datapath
        port map(
            clk        => clk,
            rst        => rst,
            pc_src     => pc_src,
            alu_src    => alu_src,
            reg_write  => reg_write,
            imm_src    => imm_src,
            alu_op     => alu_op,
            instr      => instr,
            alu_result => alu_result,
            zero       => zero,
            pc         => pc,
            result_src => result_src,
            read_data  => read_data,
            write_data => write_data
        );
    
end architecture synth;
