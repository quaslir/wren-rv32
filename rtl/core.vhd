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
        write_data: out std_logic_vector(31 downto 0);
        be : out std_logic_vector(3 downto 0);
        misaligned: out std_logic
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
    signal alu_result_int : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data_raw: std_logic_vector(31 downto 0) := (others => '0');
    signal load_data: std_logic_vector(31 downto 0) := (others => '0');
begin
controller_inst : entity work.controller
    port map(
        instr      => instr,
        zero       => zero,
        addr_lo    => alu_result_int(1 downto 0),
        reg_write  => reg_write,
        alu_src    => alu_src,
        illegal    => illegal,
        pc_src     => pc_src,
        misaligned => misaligned,
        alu_op     => alu_op,
        imm_src    => imm_src,
        mem_write  => mem_write,
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
            alu_result => alu_result_int,
            zero       => zero,
            pc         => pc,
            result_src => result_src,
            read_data  => load_data,
            write_data => write_data_raw
        );
store_align_inst : entity work.store_align
    port map(
        size    => instr(13 downto 12),
        addr_lo => alu_result_int(1 downto 0),
        wd      => write_data_raw,
        wd_out  => write_data,
        be      => be
    );

    load_ext_inst : entity work.load_ext
        port map(
            funct3    => instr(14 downto 12),
            addr_lo   => alu_result_int(1 downto 0),
            rd        => read_data,
            read_data => load_data
        );
    
    alu_result <= alu_result_int;
end architecture synth;



