library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_extend is
end entity tb_extend;

architecture sim of tb_extend is
    signal instr   : std_logic_vector(31 downto 0);
    signal imm_ext : std_logic_vector(31 downto 0);
begin

    dut : entity work.extend
        port map (
            instr   => instr,
            imm_ext => imm_ext
        );

    stim : process
        variable errors   : natural := 0;
        variable value    : integer;
        variable expected : std_logic_vector(31 downto 0);

        procedure check (ins, exp : std_logic_vector(31 downto 0);
                         msg      : string) is
        begin
            instr <= ins;
            wait for 10 ns;
            if imm_ext /= exp then
                errors := errors + 1;
                report msg & ": instr=" & to_hstring(ins) &
                       " expected " & to_hstring(exp) &
                       ", got " & to_hstring(imm_ext) severity error;
            end if;
        end procedure;

    begin
        check(x"00500093", x"00000005", "addi x1, x0, 5");
        check(x"00300113", x"00000003", "addi x2, x0, 3");
        check(x"FFF00393", x"FFFFFFFF", "addi x7, x0, -1");
        check(x"7FF00093", x"000007FF", "max positive 2047");
        check(x"80000093", x"FFFFF800", "min negative -2048");
        check(x"00000013", x"00000000", "zero");
        check(x"ABC00093", x"FFFFFABC", "negative 0xABC");
        check(x"123FFFFF", x"00000123", "lower 20 bits ignored");
        check(x"FFF00000", x"FFFFFFFF", "lower 20 bits zero");

        for i in 0 to 4095 loop
            if i >= 2048 then
                value := i - 4096;
            else
                value := i;
            end if;
            expected := std_logic_vector(to_signed(value, 32));
            check(std_logic_vector(to_unsigned(i, 12)) & x"A5A5A",
                  expected, "exhaustive imm=" & integer'image(value));
        end loop;

        report "Test finished, errors: " & integer'image(errors);
        wait;
    end process;

end architecture sim;