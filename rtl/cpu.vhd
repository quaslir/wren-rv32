library ieee;
use ieee.std_logic_1164.all;
entity cpu is
    generic(
        INIT_FILE : string := "sw/main.hex";
        MEM_DEPTH: positive := 64
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
    signal mem_write: std_logic := '0';
    signal write_data: std_logic_vector(31 downto 0) := (others => '0');
    signal read_data: std_logic_vector(31 downto 0) := (others => '0');
    signal be : std_logic_vector(3 downto 0) := (others => '0');
    signal out_open: std_logic := '0';
begin


    
CORE : entity work.core
    port map(
        clk        => clk,
        rst        => rst,
        instr      => instr,
        read_data  => read_data,
        illegal    => illegal,
        alu_result => alu_result,
        pc         => pc,
        mem_write  => mem_write,
        write_data => write_data,
        be => be,
        misaligned => out_open
    );

    
    MEM : entity work.ram
        generic map(
            DEPTH     => MEM_DEPTH,
            INIT_FILE => INIT_FILE
        )
        port map(
            clk    => clk,
            we     => mem_write,
            addr   => alu_result,
            addr_a => pc,
            wd     => write_data,
            be     => be,
            rd     => read_data,
            rd_a   => instr
        );
    

result <= alu_result;
        
end architecture synth;
