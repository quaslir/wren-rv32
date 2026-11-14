library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calculator is
    port(
        clk: in std_logic;
        instr: in std_logic_vector(31 downto 0);
        result: out std_logic_vector(31 downto 0)
    );
end entity calculator;


architecture synth of calculator is
    signal reg_write: std_logic := '0';
    signal alu_control: std_logic_vector(3 downto 0);
    signal alu_src: std_logic := '0';

    signal alu_result: std_logic_vector(31 downto 0) := (others => '0');
    signal zero:std_logic := '0';

    signal rd1: std_logic_vector(31 downto 0) := (others => '0');
    signal rd2: std_logic_vector(31 downto 0) := (others => '0');

    signal imm_ext: std_logic_vector(31 downto 0) := (others => '0');

    signal src_b : std_logic_vector(31 downto 0) := (others => '0');

    alias rs2: std_logic_vector(4 downto 0) is instr(24 downto 20);
    alias rs1: std_logic_vector(4 downto 0) is instr(19 downto 15);
    alias rd: std_logic_vector(4 downto 0) is instr(11 downto 7);
    
begin
    control_unit_inst : entity work.control_unit
        port map(
            instr     => instr,
            reg_write => reg_write,
            alu_op    => alu_control,
            alu_src   => alu_src
        );

    alu_inst : entity work.alu
        port map(
            a           => rd1,
            b           => src_b,
            alu_control => alu_control,
            result      => alu_result,
            zero        => zero
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
                imm_ext => imm_ext
            );

        mux2_inst : entity work.mux2
            generic map(
                WIDTH => 32
            )
            port map(
                d0  => rd2,
                d1  => imm_ext,
                sel => alu_src,
                y   => src_b
            );
        
        
    
result <= alu_result;
end architecture synth;
