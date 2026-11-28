library ieee;
use ieee.std_logic_1164.all;

entity controller is
    port(
        clk                                     : in  std_logic;
        rst                                     : in  std_logic;
        instr                                   : in  std_logic_vector(31 downto 0);
        zero                                    : in  std_logic; -- ALU zero flag
        addr_lo                                 : in  std_logic_vector(1 downto 0); -- low 2 bits of memory address
        take_irq                                : in  std_logic; -- interrupt taken this cycle
        flush_e: in std_logic;
        valid_d: in std_logic;
        reg_write, alu_src, illegal, misaligned : out std_logic;
        reg_write_m : out std_logic;
        pc_src                                  : out std_logic_vector(1 downto 0);
        alu_op                                  : out std_logic_vector(3 downto 0);
        imm_src                                 : out std_logic_vector(2 downto 0);
        mem_write                               : out std_logic;
        result_src                              : out std_logic_vector(2 downto 0);
        jalr                                    : out std_logic;
        alu_src_a                               : out std_logic;
        csr_we                                  : out std_logic;
        mret                                    : out std_logic;
        load_e: out std_logic;
        funct3_m: out std_logic_vector(2 downto 0);
        result_src_m: out std_logic_vector(2 downto 0)
    );
end entity controller;

architecture synth of controller is

    signal csr_we_raw : std_logic := '0';
    signal mret_raw   : std_logic := '0';
    signal mis        : std_logic := '0';
    signal taken      : std_logic := '0';
    alias  funct3     : std_logic_vector(2 downto 0) is instr(14 downto 12); -- instr bits 14:12

    signal reg_write_d  : std_logic                    := '0';
    signal alu_op_d     : std_logic_vector(3 downto 0) := (others => '0');
    signal alu_src_d    : std_logic                    := '0';
    signal illegal_d    : std_logic                    := '0';
    signal branch_d     : std_logic                    := '0';
    signal mem_write_d  : std_logic                    := '0';
    signal result_src_d : std_logic_vector(2 downto 0) := (others => '0');
    signal mem_access_d : std_logic                    := '0';
    signal jump_d       : std_logic                    := '0';
    signal jalr_d       : std_logic                    := '0';
    signal alu_src_a_d  : std_logic                    := '0';

    signal reg_write_e  : std_logic                    := '0';
    signal alu_op_e     : std_logic_vector(3 downto 0) := (others => '0');
    signal alu_src_e    : std_logic                    := '0';
    signal illegal_e    : std_logic                    := '0';
    signal branch_e     : std_logic                    := '0';
    signal mem_write_e  : std_logic                    := '0';
    signal result_src_e : std_logic_vector(2 downto 0) := (others => '0');
    signal mem_access_e : std_logic                    := '0';
    signal jump_e       : std_logic                    := '0';
    signal jalr_e       : std_logic                    := '0';
    signal alu_src_a_e  : std_logic                    := '0';
    signal funct3_e     : std_logic_vector(2 downto 0) := (others => '0');

    signal mem_write_m  : std_logic                    := '0';

    signal reg_write_w : std_logic := '0';


    signal valid_e: std_logic := '0';


    alias size : std_logic_vector(1 downto 0) is funct3_e(1 downto 0); -- access size: 00=byte, 01=half, 10=word
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or flush_e = '1' then
                reg_write_e  <= '0';
                alu_op_e     <= (others => '0');
                alu_src_e    <= '0';
                illegal_e    <= '0';
                branch_e     <= '0';
                mem_write_e  <= '0';
                result_src_e <= (others => '0');
                mem_access_e <= '0';
                jump_e       <= '0';
                jalr_e       <= '0';
                alu_src_a_e  <= '0';
                funct3_e     <= (others => '0');
                valid_e <= '0';
            else
                reg_write_e  <= reg_write_d;
                alu_op_e     <= alu_op_d;
                alu_src_e    <= alu_src_d;
                illegal_e    <= illegal_d;
                branch_e     <= branch_d;
                mem_write_e  <= mem_write_d;
                result_src_e <= result_src_d;
                mem_access_e <= mem_access_d;
                jump_e       <= jump_d;
                jalr_e       <= jalr_d;
                alu_src_a_e  <= alu_src_a_d;
                funct3_e     <= funct3;
                valid_e <= valid_d;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_write_m  <= '0';
                mem_write_m  <= '0';
                funct3_m <= (others => '0');
                result_src_m <= (others => '0');
            else
                reg_write_m  <= reg_write_e and not mis;
                mem_write_m  <= mem_write_e and not mis;
                funct3_m <= funct3_e;
                result_src_m <= result_src_e;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                reg_write_w <= '0';
            else
                reg_write_w <= reg_write_m;
            end if;
        end if;
    end process;

    control_unit_inst : entity work.control_unit -- main decoder
        port map(
            instr      => instr,
            reg_write  => reg_write_d,
            alu_op     => alu_op_d,
            alu_src    => alu_src_d,
            illegal    => illegal_d,
            imm_src    => imm_src,
            branch     => branch_d,
            mem_write  => mem_write_d,
            result_src => result_src_d,
            mem_access => mem_access_d,
            jump       => jump_d,
            jalr       => jalr_d,
            alu_src_a  => alu_src_a_d,
            csr_we     => csr_we_raw,
            mret       => mret_raw
        );

    mis <= '1' when mem_access_e = '1' and size = "01" and addr_lo(0) = '1' else -- halfword at odd address
           '1' when mem_access_e = '1' and size = "10" and (addr_lo(0) = '1' or addr_lo(1) = '1') else -- word not 4-byte aligned
           '0';
    reg_write  <= reg_write_w and not take_irq; -- block reg write on misalign/irq
    mem_write  <= mem_write_m  and not take_irq; -- block mem write on misalign/irq
    csr_we     <= csr_we_raw and not take_irq; -- irq cancels CSR write
    mret       <= mret_raw and not take_irq; -- irq has priority over mret
    illegal    <= illegal_e and valid_e and not take_irq; -- hide illegal on irq
    misaligned <= mis and not take_irq; -- report misalign only without irq
    taken      <= (branch_e and (funct3_e(2) xor zero xor funct3_e(0))) or jump_e; -- branch condition from zero flag + funct3, or any jump
    pc_src     <= "10" when take_irq = '1' else -- irq -> mtvec
                  "11" when mret_raw = '1' else -- mret -> mepc
                  "01" when taken = '1' else -- branch/jump -> target
                  "00";                 -- pc + 4

    alu_op     <= alu_op_e;
    alu_src    <= alu_src_e;
    alu_src_a  <= alu_src_a_e;
    jalr       <= jalr_e;
    result_src <= result_src_e;
        load_e <= '1' when result_src_e = "001" else '0';
end architecture synth;

