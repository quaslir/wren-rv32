library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu is
    generic (
        INIT_FILE: string := "sw/main.hex"
        );
    port(
        clk : in std_logic;
        rst : in std_logic;
        result: out std_logic_vector(31 downto 0)
    );
end entity cpu;


architecture synth of cpu is
    signal reg_write: std_logic := '0';
    signal alu_op: std_logic_vector(3 downto 0);
    signal alu_src : std_logic := '0';
    signal illegal: std_logic := '0';
    signal imm_src: std_logic_vector(1 downto 0) := (others => '0');
    signal branch: std_logic := '0';
    signal pc: std_logic_vector(31 downto 0);


    signal rd1: std_logic_vector(31 downto 0) := (others => '0');
    signal rd2: std_logic_vector(31 downto 0) := (others => '0');
    signal mux_y : std_logic_vector(31 downto 0) := (others => '0');

    signal zero: std_logic := '0';
    signal imm_ext: std_logic_vector(31 downto 0) := (others => '0');

    signal alu_result: std_logic_vector(31 downto 0) := (others => '0');
    signal instr: std_logic_vector(31 downto 0) := (others => '0');
    alias rs2: std_logic_vector(4 downto 0) is instr(24 downto 20);
    alias rs1: std_logic_vector(4 downto 0) is instr(19 downto 15);
    alias rd: std_logic_vector(4 downto 0) is instr(11 downto 7);
    signal pc_plus4 : std_logic_vector(31 downto 0) := (others => '0');
    constant PC_STEP : std_logic_vector(31 downto 0) := x"00000004";
    constant WIDTH: positive := 32;
begin
    control_unit_inst : entity work.control_unit
        port map(
            instr     => instr,
            reg_write => reg_write,
            alu_op    => alu_op,
            alu_src   => alu_src,
            illegal   => illegal,
            imm_src   => imm_src,
            branch    => branch
        );

        adder_inst : entity work.adder
            generic map(
                WIDTH => WIDTH
            )
            port map(
                a => pc,
                b => PC_STEP ,
                y => pc_plus4
            );
        

        pc_reg_inst : entity work.pc_reg
            generic map(
                WIDTH => 32
            )
            port map(
                clk     => clk,
                rst     => rst,
                next_pc => pc_plus4,
                pc      => pc
            );

            mux2_inst : entity work.mux2
                generic map(
                    WIDTH => 32
                )
                port map(
                    d0  => rd2,
                    d1  => imm_ext,
                    sel => alu_src,
                    y   => mux_y
                );
            

            regfile_inst : entity work.regfile
                port map(
                    clk => clk,
                    we  => reg_write,
                    ra1 => rs1,
                    ra2 => rs2,
                    wa  => rd,
                    wd  => alu_result,
                    rd1 => rd1,
                    rd2 => rd2
                );
            

            extend_inst : entity work.extend
                port map(
                    instr   => instr,
                    imm_src => imm_src,
                    imm_ext => imm_ext
                );
            

        alu_inst : entity work.alu
            port map(
                a           => rd1,
                b           => mux_y,
                alu_control => alu_op,
                result      => alu_result,
                zero        => zero
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
