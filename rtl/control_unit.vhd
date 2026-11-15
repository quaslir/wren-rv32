library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
    port(
        instr: in std_logic_vector(31 downto 0);
        reg_write: out std_logic;
        alu_op: out std_logic_vector(3 downto 0);
        alu_src: out std_logic;
        illegal: out std_logic
    );
end entity control_unit;


architecture synth of control_unit is
alias opcode: std_logic_vector(6 downto 0) is instr(6 downto 0);
alias funct3: std_logic_vector(2 downto 0) is instr(14 downto 12);
alias funct7: std_logic_vector(6 downto 0) is instr(31 downto 25);

begin

process(opcode, funct3, funct7) 
begin
reg_write <= '0';
alu_src   <= '0';
alu_op    <= "0000";
illegal   <= '0';
case opcode is
    when "0110011" => 
        if funct7 = "0000000" then
        reg_write <= '1';
        alu_src <= '0';
        alu_op <= funct7(5) & funct3;
        elsif funct7 = "0100000" and (funct3 = "000" or funct3 = "101") then
        reg_write <= '1';
        alu_op <= funct7(5) & funct3;
        else 
            illegal <= '1';
        end if;

    when "0010011" =>
        reg_write <= '1';
        alu_src <= '1';
    when others => 
        illegal <= '1';
end case;

end process;


    end architecture synth;
