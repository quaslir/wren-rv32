library ieee;
use ieee.std_logic_1164.all;
entity cpu is
    generic(
        INIT_FILE : string := "sw/main.hex"
    );
    port(
        clk    : in  std_logic;
        rst    : in  std_logic;
        result : out std_logic_vector(31 downto 0)
    );
end entity cpu;

architecture synth of cpu is
    signal reg_write : std_logic                    := '0';
    signal alu_op    : std_logic_vector(3 downto 0);
    signal alu_src   : std_logic                    := '0';
    signal illegal   : std_logic                    := '0';
    signal imm_src   : std_logic_vector(1 downto 0) := (others => '0');
    signal pc_src    : std_logic                    := '0';
    signal pc        : std_logic_vector(31 downto 0);

    signal zero : std_logic := '0';

    signal instr : std_logic_vector(31 downto 0) := (others => '0');

    signal alu_result: std_logic_vector(31 downto 0) := (others => '0');
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
            imm_src   => imm_src
        );

    datapath_inst : entity work.datapath
        port map(
            clk       => clk,
            rst       => rst,
            pc_src    => pc_src,
            alu_src   => alu_src,
            reg_write => reg_write,
            imm_src   => imm_src,
            alu_op    => alu_op,
            instr     => instr,
            result    => alu_result,
            zero      => zero,
            pc        => pc
        );

    instr_mem_inst : entity work.instr_mem
        generic map(
            INIT_FILE => INIT_FILE,
            DEPTH     => 64
        )
        port map(
            addr  => pc,
            instr => instr
        );

    result <= alu_result;
end architecture synth;
