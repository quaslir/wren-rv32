library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity datapath is
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        pc_src    : in  std_logic;
        alu_src   : in  std_logic;
        reg_write : in  std_logic;
        imm_src   : in  std_logic_vector(2 downto 0);
        alu_op    : in  std_logic_vector(3 downto 0);
        instr     : in  std_logic_vector(31 downto 0);
                result_src: in std_logic_vector(1 downto 0);
        read_data: in std_logic_vector(31 downto 0);
        jalr: in std_logic;
        alu_result    : out std_logic_vector(31 downto 0);
        zero      : out std_logic;
        pc        : out std_logic_vector(31 downto 0);

        write_data : out std_logic_vector(31 downto 0)

    );
end entity datapath;

architecture synth of datapath is
    constant PC_STEP   : std_logic_vector(31 downto 0) := x"00000004";
    signal   pc_target : std_logic_vector(31 downto 0) := (others => '0');
    signal   pc_plus4  : std_logic_vector(31 downto 0) := (others => '0');
    signal   pc_next   : std_logic_vector(31 downto 0) := (others => '0');
    signal   imm_ext   : std_logic_vector(31 downto 0) := (others => '0');

    signal rd1   : std_logic_vector(31 downto 0) := (others => '0');
    signal rd2   : std_logic_vector(31 downto 0) := (others => '0');
    signal mux_y : std_logic_vector(31 downto 0) := (others => '0');

    alias rs2 : std_logic_vector(4 downto 0) is instr(24 downto 20);
    alias rs1 : std_logic_vector(4 downto 0) is instr(19 downto 15);
    alias rd  : std_logic_vector(4 downto 0) is instr(11 downto 7);

    signal result: std_logic_vector(31 downto 0) := (others => '0');

    signal pc_int: std_logic_vector(31 downto 0) := (others => '0');
    signal alu_result_int: std_logic_vector(31 downto 0) := (others => '0');
    signal target_base: std_logic_vector(31 downto 0) := (others => '0');
    signal target_sum: std_logic_vector(31 downto 0) := (others => '0');
begin
    alu_inst : entity work.alu
        port map(
            a           => rd1,
            b           => mux_y,
            alu_control => alu_op,
            result      => alu_result_int,
            zero        => zero
        );

    adder_inst : entity work.adder
        generic map(
            WIDTH => 32
        )
        port map(
            a => pc_int,
            b => PC_STEP,
            y => pc_plus4
        );

    pc_reg_inst : entity work.pc_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            next_pc => pc_next,
            pc      => pc_int
        );
    target_base_mux : entity work.mux2
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => pc_int,
            d1  => rd1,
            sel => jalr,
            y   => target_base
        );
    
    PCTarget : entity work.adder
        generic map(
            WIDTH => 32
        )
        port map(
            a => target_base,
            b => imm_ext,
            y => target_sum
        );
    PCMux : entity work.mux2
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => pc_plus4,
            d1  => pc_target,
            sel => pc_src,
            y   => pc_next
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
            wd  => result,
            rd1 => rd1,
            rd2 => rd2
        );

    extend_inst : entity work.extend
        port map(
            instr   => instr,
            imm_src => imm_src,
            imm_ext => imm_ext
        );


        ResultMux : entity work.mux4
            generic map(
                WIDTH => 32
            )
            port map(
                d0  => alu_result_int,
                d1  => read_data,
                d2  => pc_plus4,
                d3  => imm_ext,
                sel => result_src,
                y   => result
            );
        

        
write_data <= rd2;
pc <= pc_int;
alu_result <= alu_result_int;
pc_target <= target_sum (31 downto 1) & '0';
end architecture synth;
