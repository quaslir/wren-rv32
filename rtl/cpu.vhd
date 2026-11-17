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
    signal instr : std_logic_vector(31 downto 0) := (others => '0');
    signal illegal: std_logic := '0';
    signal alu_result: std_logic_vector(31 downto 0) := (others => '0');
    signal pc: std_logic_vector(31 downto 0) := (others => '0');

begin

    core_inst : entity work.core
        port map(
            clk        => clk,
            rst        => rst,
            instr      => instr,
            illegal    => illegal,
            alu_result => alu_result,
            pc         => pc
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
