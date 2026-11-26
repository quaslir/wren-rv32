library ieee;
use ieee.std_logic_1164.all;

entity controller is
    port(

       instr: in std_logic_vector(31 downto 0);
       zero: in std_logic;  -- ALU zero flag
       addr_lo: in std_logic_vector(1 downto 0);  -- low 2 bits of memory address
       take_irq: in std_logic;  -- interrupt taken this cycle
       reg_write, alu_src, illegal, misaligned: out std_logic;
       pc_src: out std_logic_vector(1 downto 0);
       alu_op: out std_logic_vector(3 downto 0);
       imm_src: out std_logic_vector(2 downto 0);
       mem_write: out std_logic;
       result_src: out std_logic_vector(2 downto 0);
       jalr:  out std_logic;
       alu_src_a : out std_logic;
       csr_we: out std_logic;
       mret: out std_logic
    );
end entity controller;


architecture synth of controller is

signal branch: std_logic := '0';
signal reg_write_raw: std_logic := '0';
signal csr_we_raw: std_logic := '0';
signal mret_raw: std_logic := '0';
signal illegal_raw: std_logic := '0';
signal mem_write_raw: std_logic := '0';
signal mem_access: std_logic := '0';
signal mis: std_logic := '0';
signal jump : std_logic := '0';
signal taken: std_logic := '0';
alias funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);  -- instr bits 14:12
alias size: std_logic_vector(1 downto 0) is funct3(1 downto 0);  -- access size: 00=byte, 01=half, 10=word
begin
    control_unit_inst : entity work.control_unit  -- main decoder
        port map(
            instr     => instr,
            reg_write => reg_write_raw,
            alu_op    => alu_op,
            alu_src   => alu_src,
            illegal   => illegal_raw,
            imm_src   => imm_src,
            branch    => branch,
            mem_write => mem_write_raw,
            result_src => result_src,
            mem_access => mem_access,
            jump =>  jump,
            jalr =>  jalr,
            alu_src_a => alu_src_a,
            csr_we => csr_we_raw,
            mret => mret_raw
        );       
        mis <= '1' when mem_access = '1' and size = "01" and addr_lo(0) = '1' else  -- halfword at odd address
            '1' when mem_access = '1' and size = "10" and (addr_lo(0) = '1' or addr_lo(1) = '1') else  -- word not 4-byte aligned
            '0';
        reg_write <= reg_write_raw and not mis and not take_irq;  -- block reg write on misalign/irq
        mem_write <= mem_write_raw and not mis and not take_irq;  -- block mem write on misalign/irq
        csr_we <= csr_we_raw and not take_irq;  -- irq cancels CSR write
        mret <= mret_raw and not take_irq;  -- irq has priority over mret
        illegal <= illegal_raw and not take_irq;  -- hide illegal on irq
        misaligned <= mis and not take_irq;  -- report misalign only without irq
            taken <= (branch and (funct3(2) xor zero xor funct3(0))) or jump;  -- branch condition from zero flag + funct3, or any jump
        pc_src <= "10" when take_irq = '1' else  -- irq -> mtvec
            "11" when mret_raw = '1' else  -- mret -> mepc
            "01" when taken = '1' else  -- branch/jump -> target
            "00";  -- pc + 4
end architecture synth;

