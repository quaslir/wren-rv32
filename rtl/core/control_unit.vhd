library ieee;
use ieee.std_logic_1164.all;

entity control_unit is
    port(
        instr     : in  std_logic_vector(31 downto 0);
        reg_write : out std_logic;
        alu_op    : out std_logic_vector(3 downto 0);
        alu_src   : out std_logic;
        illegal   : out std_logic;
        imm_src   : out std_logic_vector(2 downto 0);
        branch    : out std_logic;
        mem_write: out std_logic;
        result_src: out std_logic_vector(2 downto 0);
        mem_access: out std_logic;
        alu_src_a: out std_logic;
        jump : out std_logic;
        jalr: out std_logic;
        csr_we: out std_logic;
        mret: out std_logic
    );
end entity control_unit;

architecture synth of control_unit is
    alias opcode : std_logic_vector(6 downto 0) is instr(6 downto 0);  -- instr bits 6:0
    alias funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);  -- instr bits 14:12
    alias funct7 : std_logic_vector(6 downto 0) is instr(31 downto 25);  -- instr bits 31:25

begin

    process(opcode, instr)  -- combinational decoder
    begin
        reg_write <= '0';  -- defaults: everything off
        alu_src   <= '0';
        alu_op    <= "0000";
        illegal   <= '0';
        imm_src   <= "000";
        branch    <= '0';
        mem_write <= '0';
        result_src <= "000";
        mem_access <= '0';
        jalr <= '0';
        jump <= '0';
        alu_src_a <= '0';
        csr_we <= '0';
        mret <= '0';
        case opcode is
            when "0110011" =>  -- R-type (add, sub, sll, ...)
                if funct7 = "0000000" then  -- normal R-type ops
                    reg_write <= '1';
                    alu_op    <= funct7(5) & funct3;
                elsif funct7 = "0100000" and (funct3 = "000" or funct3 = "101") then  -- sub / sra
                    reg_write <= '1';
                    alu_op    <= funct7(5) & funct3;
                else  -- unknown R-type
                    illegal <= '1';
                end if;

            when "0010011" =>  -- I-type ALU ops (addi, slti, ...)
                case funct3 is
                    when "000" |
             "010" | "011" | "100" | "110"
            | "111" =>
                        alu_op    <= '0' & funct3;  -- ALU op = funct3
                        imm_src   <= "000";  -- I-type immediate
                        reg_write <= '1';
                        alu_src   <= '1';  -- ALU B = immediate

                    when "001" =>  -- slli
                        if funct7 = "0000000" then
                            alu_op    <= '0' & funct3;
                            imm_src   <= "000";
                            reg_write <= '1';
                            alu_src   <= '1';

                        else
                            illegal <= '1';
                        end if;
                    when "101" =>  -- srli / srai
                        if funct7 = "0000000" or funct7 = "0100000" then
                            imm_src   <= "000";
                            reg_write <= '1';
                            alu_src   <= '1';
                            alu_op    <= instr(30) & funct3;  -- bit 30 selects srai
                        else
                            illegal <= '1';
                        end if;
                    when others =>
                        illegal <= '1';
                end case;

            when "1100011" =>  -- branches

                case funct3 is
                    when "000" | "001" =>  -- beq/bne: compare by subtract
                    imm_src <= "010";
                    branch  <= '1';
                    alu_op  <= "1000";
                    when "100" | "101" =>  -- blt/bge: signed compare
                    imm_src <= "010";
                    branch <= '1';
                    alu_op <= "0010";
                    when "110" | "111" =>  -- bltu/bgeu: unsigned compare
                    imm_src <= "010";
                    branch <= '1';
                    alu_op <= "0011";
                    when others => illegal <= '1';
                end case;
            when "0000011" =>  -- loads
                case funct3 is
                        when "000" | "001" | "010" |  -- lb, lh, lw, lbu, lhu
                         "100" | "101" => 
                        reg_write <= '1';
                        alu_src <= '1';
                        imm_src <= "000";
                        result_src <= "001";  -- rd = memory data
                        alu_op <= "0000";  -- address = rs1 + imm
                        mem_access <= '1';  -- memory access (for misalign check)
                    when others => illegal <= '1';
                end case;
            when "0100011" =>  -- stores
                case funct3 is
                    when "000" | "001" | "010" =>  -- sb, sh, sw
                    imm_src <= "001";  -- S-type immediate
                    alu_src <= '1';
                    mem_write <='1';
                    alu_op <= "0000";
                    mem_access <='1';
                    when others => illegal <= '1';
                end case;
            when "1101111" => -- jal
                imm_src <= "011";  -- J-type immediate
                result_src <= "010";  -- rd = pc + 4
                jump <= '1';
                reg_write <= '1';
            when "1100111" => -- jalr
                if funct3 = "000" then  -- only funct3=000 is valid
                jalr <= '1';  -- target = rs1 + imm
                jump <= '1';
                result_src <= "010";  -- rd = pc + 4
                alu_src <= '1';
                reg_write <= '1';
                else 
                    illegal <= '1';
                end if;
            when "0110111" => -- lui
                reg_write <= '1';
                imm_src <= "100";  -- U-type immediate
                result_src <= "011";  -- rd = immediate
            when "0010111" => -- auipc
                reg_write <= '1';
                imm_src <= "100";
                alu_src <= '1';
                alu_src_a <= '1';  -- ALU A = pc (pc + imm)
            when "1110011" => -- interrupts
                case funct3 is
                when "001" | "010" | "011" | "101" | "110" | "111" =>  -- csrrw/s/c and immediate forms
                    reg_write <= '1';
                    result_src <= "100";  -- rd = old CSR value

                    if funct3(1 downto 0) = "01" or instr(19 downto 15) /= "00000"  then  -- write CSR unless csrrs/c with rs1/uimm = 0
                        csr_we <= '1';
                    end if;
                    
                    when "000" =>  -- ecall / ebreak / mret
                     case instr is
                        when x"30200073" => mret <= '1';  -- mret
                        when others => illegal <= '1';  -- ecall/ebreak not supported
                     end case;
                     

                    when others => illegal <= '1';
                end case;
                
            when others =>  -- unknown opcode
                illegal <= '1';
        end case;

    end process;

end architecture synth;
