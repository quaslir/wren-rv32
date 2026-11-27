library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity datapath is
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        pc_src     : in  std_logic_vector(1 downto 0);
        alu_src    : in  std_logic;
        reg_write  : in  std_logic;
        imm_src    : in  std_logic_vector(2 downto 0);
        alu_op     : in  std_logic_vector(3 downto 0);
        instr_f    : in  std_logic_vector(31 downto 0);
        result_src : in  std_logic_vector(2 downto 0);
        read_data  : in  std_logic_vector(31 downto 0);
        jalr       : in  std_logic;
        alu_src_a  : in  std_logic;
        csr_we     : in  std_logic;
        mret       : in  std_logic;
        irq        : in  std_logic;
        result_src_m: in std_logic_vector(2 downto 0);
        alu_result : out std_logic_vector(31 downto 0);
        alu_result_e: out std_logic_vector(31 downto 0);
        instr_d    : out std_logic_vector(31 downto 0);
        zero       : out std_logic;
        pc         : out std_logic_vector(31 downto 0);
        write_data : out std_logic_vector(31 downto 0);
        take_irq   : out std_logic
    );
end entity datapath;

architecture synth of datapath is
    constant PC_STEP     : std_logic_vector(31 downto 0) := x"00000004"; -- PC increment
    signal   pc_target   : std_logic_vector(31 downto 0) := (others => '0');
    signal   pc_plus4    : std_logic_vector(31 downto 0) := (others => '0');
    signal   pc_next     : std_logic_vector(31 downto 0) := (others => '0');
    signal   imm_ext     : std_logic_vector(31 downto 0) := (others => '0');
    signal   instr_d_int : std_logic_vector(31 downto 0) := (others => '0');

    signal rd1   : std_logic_vector(31 downto 0) := (others => '0');
    signal rd2   : std_logic_vector(31 downto 0) := (others => '0');
    signal mux_y : std_logic_vector(31 downto 0) := (others => '0');

    alias  rs2    : std_logic_vector(4 downto 0) is instr_d_int(24 downto 20); -- source register 2
    alias  rs1    : std_logic_vector(4 downto 0) is instr_d_int(19 downto 15); -- source register 1s
    alias  rd_d   : std_logic_vector(4 downto 0) is instr_d_int(11 downto 7);
    signal result : std_logic_vector(31 downto 0) := (others => '0'); -- value written back to rd

    signal pc_int         : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_result_int : std_logic_vector(31 downto 0) := (others => '0');
    signal target_base    : std_logic_vector(31 downto 0) := (others => '0'); -- base for branch/jump target
    signal target_sum     : std_logic_vector(31 downto 0) := (others => '0');
    signal src_a          : std_logic_vector(31 downto 0) := (others => '0');

    signal rdata   : std_logic_vector(31 downto 0) := (others => '0'); -- CSR read data
    signal mtvec   : std_logic_vector(31 downto 0) := (others => '0');
    signal mepc    : std_logic_vector(31 downto 0) := (others => '0');
    signal uimm    : std_logic_vector(31 downto 0) := (others => '0'); -- zero-extended 5-bit CSR immediate
    signal csr_src : std_logic_vector(31 downto 0) := (others => '0'); -- CSR operand: rs1 or uimm

    signal pc_int_d   : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus4_d : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_d    : std_logic_vector(0 downto 0)  := (others => '0');

    signal rd1_e : std_logic_vector(31 downto 0) := (others => '0');
    signal rd2_e : std_logic_vector(31 downto 0) := (others => '0');

    signal pc_e       : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus4_e : std_logic_vector(31 downto 0) := (others => '0');

    signal imm_e : std_logic_vector(31 downto 0) := (others => '0');

    signal rs1_e : std_logic_vector(4 downto 0) := (others => '0');
    signal rs2_e : std_logic_vector(4 downto 0) := (others => '0');

    signal rd_e : std_logic_vector(4 downto 0) := (others => '0');

    signal ex_result_e: std_logic_vector(31 downto 0) := (others => '0');

    signal alu_result_m: std_logic_vector(31 downto 0) := (others => '0');
    signal write_data_m: std_logic_vector(31 downto 0) := (others => '0');
    signal rd_m: std_logic_vector(4 downto 0) := (others => '0');
    signal ex_result_m: std_logic_vector(31 downto 0) := (others => '0');
    signal load_m: std_logic := '0';

    signal result_w: std_logic_vector(31 downto 0) := (others => '0');
    signal rd_w: std_logic_vector(4 downto 0) := (others => '0');

    signal result_m: std_logic_vector(31 downto 0) := (others => '0');

begin

    if_id_instr : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => instr_f,
            q   => instr_d_int
        );

    if_id_pc : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => pc_int,
            q   => pc_int_d
        );

    if_id_pc4 : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => pc_plus4,
            q   => pc_plus4_d
        );

    if_id_valid : entity work.pipe_reg
        generic map(
            WIDTH => 1
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => "1",
            q   => valid_d
        );

    id_ex_rd1 : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => rd1,
            q   => rd1_e
        );

    id_ex_rd2 : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => rd2,
            q   => rd2_e
        );

    id_ex_pc : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => pc_int_d,
            q   => pc_e
        );

    id_ex_pc4 : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => pc_plus4_d,
            q   => pc_plus4_e
        );

    id_ex_imm : entity work.pipe_reg
        generic map(
            WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => imm_ext,
            q   => imm_e
        );

    id_ex_rs1 : entity work.pipe_reg
        generic map(
            WIDTH => 5
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => rs1,
            q   => rs1_e
        );

    id_ex_rs2 : entity work.pipe_reg
        generic map(
            WIDTH => 5
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => rs2,
            q   => rs2_e
        );

    id_ex_rd : entity work.pipe_reg
        generic map(
            WIDTH => 5
        )
        port map(
            clk => clk,
            rst => rst,
            en  => '1',
            clr => '0',
            d   => rd_d,
            q   => rd_e
        );

        ex_mem_alu : entity work.pipe_reg
            generic map(
                WIDTH => 32
            )
            port map(
                clk => clk,
                rst => rst,
                en  => '1',
                clr => '0',
                d   => alu_result_int,
                q   => alu_result_m
            );
        ex_mem_write_data: entity work.pipe_reg
            generic map(
                WIDTH => 32
            )
            port map(
                clk => clk,
                rst => rst,
                en  => '1',
                clr => '0',
                d   => rd2_e,
                q   => write_data_m
            );

            ex_mem_rd: entity work.pipe_reg
                generic map(
                    WIDTH => 5
                )
                port map(
                    clk => clk,
                    rst => rst,
                    en  => '1',
                    clr => '0',
                    d   => rd_e,
                    q   => rd_m
                );


                ex_mem_res : entity work.pipe_reg
                    generic map(
                        WIDTH => 32
                    )
                    port map(
                        clk => clk,
                        rst => rst,
                        en  => '1',
                        clr => '0',
                        d   => ex_result_e,
                        q   => ex_result_m
                    );



                    result_m_mux2 : entity work.mux2
                        generic map(
                            WIDTH => 32
                        )
                        port map(
                            d0  => ex_result_m,
                            d1  => read_data,
                            sel => load_m,
                            y   => result_m
                        );
                    




                mem_wb_res: entity work.pipe_reg
                    generic map(
                        WIDTH => 32
                    )
                    port map(
                        clk => clk,
                        rst => rst,
                        en  => '1',
                        clr => '0',
                        d   => result_m,
                        q   => result_w
                    );


                mem_wb_rd: entity work.pipe_reg
                    generic map(
                        WIDTH => 5
                    )
                    port map(
                        clk => clk,
                        rst => rst,
                        en  => '1',
                        clr => '0',
                        d   => rd_m,
                        q   => rd_w
                    );
                
                


                
    alu_inst : entity work.alu          -- main ALU
        port map(
            a           => src_a,
            b           => mux_y,
            alu_control => alu_op,
            result      => alu_result_int,
            zero        => zero
        );

    adder_inst : entity work.adder      -- pc + 4
        generic map(
            WIDTH => 32
        )
        port map(
            a => pc_int,
            b => PC_STEP,
            y => pc_plus4
        );

    pc_reg_inst : entity work.pc_reg    -- program counter register
        generic map(
            WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            next_pc => pc_next,
            pc      => pc_int
        );
    target_base_mux : entity work.mux2  -- pc for branch/jal, rs1 for jalr
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => pc_e,
            d1  => rd1_e,
            sel => jalr,
            y   => target_base
        );

    PCTarget : entity work.adder        -- target = base + imm
        generic map(
            WIDTH => 32
        )
        port map(
            a => target_base,
            b => imm_e,
            y => target_sum
        );
    PCMux : entity work.mux4            -- next pc: pc+4 / target / mtvec / mepc
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => pc_plus4,
            d1  => pc_target,
            d2  => mtvec,
            d3  => mepc,
            sel => pc_src,
            y   => pc_next
        );

    mux2_inst : entity work.mux2        -- ALU B: rs2 or immediate
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => rd2_e,
            d1  => imm_e,
            sel => alu_src,
            y   => mux_y
        );

    regfile_inst : entity work.regfile  -- 32 x 32-bit registers
        port map(
            clk => clk,
            we  => reg_write,
            ra1 => rs1,
            ra2 => rs2,
            wa  => rd_w,
            wd  => result_w,
            rd1 => rd1,
            rd2 => rd2
        );

    extend_inst : entity work.extend    -- immediate generator
        port map(
            instr   => instr_d_int,
            imm_src => imm_src,
            imm_ext => imm_ext
        );

    ResultMux : entity work.mux8        -- writeback: alu / mem / pc+4 / imm / csr
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => alu_result_int,
            d1  => (others => '0'),
            d2  => pc_plus4_e,
            d3  => imm_e,
            d4  => rdata,
            d5  => (others => '0'),
            d6  => (others => '0'),
            d7  => (others => '0'),
            sel => result_src,
            y   => ex_result_e
        );

    srca_mux : entity work.mux2         -- ALU A: rs1 or pc (auipc)
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => rd1_e,
            d1  => pc_e,
            sel => alu_src_a,
            y   => src_a
        );

    csr_src_mux2 : entity work.mux2     -- funct3 bit 2 selects immediate form
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => rd1_e,
            d1  => uimm,
            sel => instr_f(14),
            y   => csr_src
        );

    csr_inst : entity work.csr          -- machine CSRs and interrupt logic
        port map(
            clk      => clk,
            rst      => rst,
            we       => csr_we,
            addr     => instr_f(31 downto 20),
            op       => instr_f(13 downto 12),
            src      => csr_src,
            irq      => irq,
            mret     => mret,
            pc       => pc_int,
            rdata    => rdata,
            mtvec    => mtvec,
            mepc     => mepc,
            take_irq => take_irq
        );

    instr_d    <= instr_d_int;
    uimm       <= (31 downto 5 => '0') & instr_f(19 downto 15); -- uimm from rs1 field
    write_data <= write_data_m;                -- store data = rs2
    pc         <= pc_int;
    alu_result <= alu_result_m;
    pc_target  <= target_sum(31 downto 1) & '0'; -- clear bit 0 (jalr rule)
    alu_result_e <= alu_result_int;
    load_m <= '1' when result_src_m = "001" else '0';
end architecture synth;
