library ieee;
use ieee.std_logic_1164.all;
entity cpu is
    generic(
        INIT_FILE : string := "sw/main.hex";
        IMEM_DEPTH: positive := 64;
        DMEM_DEPTH: positive := 32
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


    
core_inst : entity work.core
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

    instr_mem_inst : entity work.instr_mem
        generic map(
            INIT_FILE => INIT_FILE,
            DEPTH     => IMEM_DEPTH
        )
        port map(
            addr  => pc,
            instr => instr
        );

        data_mem_inst : entity work.data_mem
            generic map(
                DEPTH => DMEM_DEPTH
            )
            port map(
                clk  => clk,
                we   => mem_write,
                addr => alu_result,
                wd   => write_data,
                rd   => read_data,
                be => be
            );
        

result <= alu_result;
        
end architecture synth;
