library ieee;
use ieee.std_logic_1164.all;

entity core is
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        instr      : in  std_logic_vector(31 downto 0);
        read_data  : in  std_logic_vector(31 downto 0);
        irq        : in  std_logic;
        illegal    : out std_logic;
        alu_result : out std_logic_vector(31 downto 0);
        pc         : out std_logic_vector(31 downto 0);
        mem_write  : out std_logic;
        write_data : out std_logic_vector(31 downto 0);
        be         : out std_logic_vector(3 downto 0);
        misaligned : out std_logic
    );
end entity core;

architecture synth of core is

    signal reg_write      : std_logic                     := '0';
    signal alu_op         : std_logic_vector(3 downto 0);
    signal alu_src        : std_logic                     := '0';
    signal instr_d        : std_logic_vector(31 downto 0) := (others => '0');
    signal imm_src        : std_logic_vector(2 downto 0)  := (others => '0');
    signal pc_src         : std_logic_vector(1 downto 0)  := (others => '0');
    signal result_src     : std_logic_vector(2 downto 0)  := (others => '0');
    signal zero           : std_logic                     := '0';
    signal alu_result_int : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data_raw : std_logic_vector(31 downto 0) := (others => '0');
    signal load_data      : std_logic_vector(31 downto 0) := (others => '0');
    signal jalr           : std_logic                     := '0';
    signal alu_src_a      : std_logic                     := '0';
    signal take_irq       : std_logic                     := '0';
    signal csr_we         : std_logic                     := '0';
    signal mret           : std_logic                     := '0';
    signal funct3_m       : std_logic_vector(2 downto 0)  := (others => '0');
    signal alu_result_e   : std_logic_vector(31 downto 0) := (others => '0');
    signal result_src_m   : std_logic_vector(2 downto 0)  := (others => '0');
    signal forward_a_e    : std_logic_vector(1 downto 0)  := (others => '0');
    signal forward_b_e    : std_logic_vector(1 downto 0)  := (others => '0');
    signal stall_f        : std_logic                     := '0';
    signal stall_d        : std_logic                     := '0';
    signal flush_d        : std_logic                     := '0';
    signal flush_e        : std_logic                     := '0';
    signal rs1_e          : std_logic_vector(4 downto 0)  := (others => '0');
    signal rs2_e          : std_logic_vector(4 downto 0)  := (others => '0');
    signal rd_e: std_logic_vector(4 downto 0) := (others => '0');
    signal rd_m : std_logic_vector(4 downto 0) := (others => '0');
    signal rd_w: std_logic_vector(4 downto 0) := (others => '0');
    signal rs1_d          : std_logic_vector(4 downto 0)  := (others => '0');
    signal rs2_d          : std_logic_vector(4 downto 0)  := (others => '0');
    signal load_e: std_logic := '0';
    signal valid_d: std_logic  := '0';
    signal reg_write_m : std_logic := '0';
begin

    controller_inst : entity work.controller
        port map(
            clk          => clk,
            rst          => rst,
            instr        => instr_d,
            zero         => zero,
            addr_lo      => alu_result_e(1 downto 0),
            take_irq     => take_irq,
            flush_e => flush_e,
            valid_d => valid_d,
            reg_write    => reg_write,
            alu_src      => alu_src,
            illegal      => illegal,
            misaligned   => misaligned,
            reg_write_m => reg_write_m,
            pc_src       => pc_src,
            alu_op       => alu_op,
            imm_src      => imm_src,
            mem_write    => mem_write,
            result_src   => result_src,
            jalr         => jalr,
            alu_src_a    => alu_src_a,
            csr_we       => csr_we,
            mret         => mret,
            funct3_m     => funct3_m,
            result_src_m => result_src_m,
            load_e => load_e
        );

    datapath_inst : entity work.datapath
        port map(
            clk          => clk,
            rst          => rst,
            pc_src       => pc_src,
            alu_src      => alu_src,
            reg_write    => reg_write,
            imm_src      => imm_src,
            alu_op       => alu_op,
            instr_f      => instr,
            result_src   => result_src,
            read_data    => load_data,
            jalr         => jalr,
            alu_src_a    => alu_src_a,
            csr_we       => csr_we,
            mret         => mret,
            irq          => irq,
            forward_a_e  => forward_a_e,
            forward_b_e  => forward_b_e,
            stall_f      => stall_f,
            stall_d      => stall_d,
            flush_d      => flush_d,
            result_src_m => result_src_m,
            alu_result   => alu_result_int,
            alu_result_e => alu_result_e,
            instr_d      => instr_d,
            zero         => zero,
            pc           => pc,
            write_data   => write_data_raw,
            take_irq     => take_irq,
            rs1_d        => rs1_d,
            rs2_d        => rs2_d,
            rs1_e        => rs1_e,
            rs2_e        => rs2_e,
            rd_e         => rd_e,
            rd_m         => rd_m,
            rd_w         => rd_w,
            valid_d      => valid_d
        );

    hazard_unit_inst : entity work.hazard_unit
        port map(
            rs1_e       => rs1_e,
            rs2_e       => rs2_e,
            rd_m        => rd_m,
            reg_write_m => reg_write_m,
            rd_w        => rd_w,
            reg_write_w => reg_write,
            rs1_d       => rs1_d,
            rs2_d       => rs2_d,
            rd_e        => rd_e,
            load_e      => load_e,
            pc_src_e    => pc_src,
            forward_a_e => forward_a_e,
            forward_b_e => forward_b_e,
            stall_f     => stall_f,
            stall_d     => stall_d,
            flush_d     => flush_d,
            flush_e     => flush_e
        );

    store_align_inst : entity work.store_align -- puts store data in the right byte lanes
        port map(
            size    => funct3_m(1 downto 0), -- store size from funct3
            addr_lo => alu_result_int(1 downto 0),
            wd      => write_data_raw,
            wd_out  => write_data,
            be      => be
        );

    load_ext_inst : entity work.load_ext -- extracts and extends loaded data
        port map(
            funct3    => funct3_m,
            addr_lo   => alu_result_int(1 downto 0),
            rd        => read_data,
            read_data => load_data
        );

    alu_result <= alu_result_int;       -- memory address / ALU result
end architecture synth;

