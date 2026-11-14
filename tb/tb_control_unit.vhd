library ieee;
use ieee.std_logic_1164.all;

entity tb_control_unit is
end entity tb_control_unit;

architecture sim of tb_control_unit is
    signal instr       : std_logic_vector(31 downto 0);
    signal reg_write   : std_logic;
    signal alu_src     : std_logic;
    signal alu_control : std_logic_vector(3 downto 0);
begin

    dut : entity work.control_unit
        port map (
            instr       => instr,
            reg_write   => reg_write,
            alu_src     => alu_src,
            alu_op => alu_control
        );

    stim : process
        variable errors : natural := 0;

        procedure check (ins     : std_logic_vector(31 downto 0);
                         exp_rw  : std_logic;
                         exp_src : std_logic;
                         exp_alu : std_logic_vector(3 downto 0);
                         msg     : string) is
        begin
            instr <= ins;
            wait for 10 ns;
            if reg_write /= exp_rw or alu_src /= exp_src or alu_control /= exp_alu then
                errors := errors + 1;
                report msg & " (" & to_hstring(ins) & "): expected reg_write=" &
                       std_logic'image(exp_rw) & " alu_src=" & std_logic'image(exp_src) &
                       " alu_control=" & to_string(exp_alu) &
                       ", got reg_write=" & std_logic'image(reg_write) &
                       " alu_src=" & std_logic'image(alu_src) &
                       " alu_control=" & to_string(alu_control) severity error;
            end if;
        end procedure;

    begin
        check(x"002081B3", '1', '0', "0000", "add x3, x1, x2");
        check(x"40208233", '1', '0', "1000", "sub x4, x1, x2");
        check(x"0020F2B3", '1', '0', "0111", "and x5, x1, x2");
        check(x"0020E333", '1', '0', "0110", "or x6, x1, x2");
        check(x"0020C533", '1', '0', "0100", "xor x10, x1, x2");
        check(x"002095B3", '1', '0', "0001", "sll x11, x1, x2");
        check(x"0020D633", '1', '0', "0101", "srl x12, x1, x2");
        check(x"4020D6B3", '1', '0', "1101", "sra x13, x1, x2");
        check(x"0020A733", '1', '0', "0010", "slt x14, x1, x2");
        check(x"0020B7B3", '1', '0', "0011", "sltu x15, x1, x2");

        check(x"00500093", '1', '1', "0000", "addi x1, x0, 5");
        check(x"FFF00393", '1', '1', "0000", "addi x7, x0, -1 (bit30=1, must not be SUB)");
        check(x"40000093", '1', '1', "0000", "addi x1, x0, 1024 (bit30=1, positive)");
        check(x"80008093", '1', '1', "0000", "addi x1, x1, -2048");

        check(x"00002083", '0', '0', "0000", "lw x1, 0(x0) (not supported yet)");
        check(x"00102023", '0', '0', "0000", "sw x1, 0(x0) (not supported yet)");
        check(x"00000063", '0', '0', "0000", "beq x0, x0, 0 (not supported yet)");
        check(x"00000000", '0', '0', "0000", "all zeros");

        report "Test finished, errors: " & integer'image(errors);
        wait;
    end process;

end architecture sim;