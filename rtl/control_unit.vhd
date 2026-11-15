library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port(
        instr     : in  std_logic_vector(31 downto 0);
        reg_write : out std_logic;
        alu_op    : out std_logic_vector(3 downto 0);
        alu_src   : out std_logic;
        illegal   : out std_logic;
        imm_src   : out std_logic_vector(1 downto 0);
        branch    : out std_logic
    );
end entity control_unit;

architecture synth of control_unit is
    alias opcode : std_logic_vector(6 downto 0) is instr(6 downto 0);
    alias funct3 : std_logic_vector(2 downto 0) is instr(14 downto 12);
    alias funct7 : std_logic_vector(6 downto 0) is instr(31 downto 25);

begin

    process(opcode, funct3, funct7)
    begin
        reg_write <= '0';
        alu_src   <= '0';
        alu_op    <= "0000";
        illegal   <= '0';
        imm_src   <= "00";
        branch    <= '0';
        case opcode is
            when "0110011" =>
                if funct7 = "0000000" then
                    reg_write <= '1';
                    alu_src   <= '0';
                    alu_op    <= funct7(5) & funct3;
                elsif funct7 = "0100000" and (funct3 = "000" or funct3 = "101") then
                    reg_write <= '1';
                    alu_op    <= funct7(5) & funct3;
                else
                    illegal <= '1';
                end if;

            when "0010011" =>
                case funct3 is
                    when "000" |
             "010" | "011" | "100" | "110"
            | "111" =>
                        alu_op    <= '0' & funct3;
                        imm_src   <= "00";
                        reg_write <= '1';
                        alu_src   <= '1';

                    when "001" =>
                        if funct7 = "0000000" then
                            alu_op    <= '0' & funct3;
                            imm_src   <= "00";
                            reg_write <= '1';
                            alu_src   <= '1';

                        else
                            illegal <= '1';
                        end if;
                    when "101" =>
                        if funct7 = "0000000" or funct7 = "0100000" then
                            imm_src   <= "00";
                            reg_write <= '1';
                            alu_src   <= '1';
                            alu_op    <= instr(30) & funct3;
                        else
                            illegal <= '1';
                        end if;
                    when others =>
                        illegal <= '1';
                end case;

            when "1100011" =>
                if funct3 = "000" then
                    imm_src <= "10";
                    branch  <= '1';
                    alu_op  <= "1000";
                else
                    illegal <= '1';
                end if;
            when others =>
                illegal <= '1';
        end case;

    end process;

end architecture synth;
