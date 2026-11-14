library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_adder is
end entity tb_adder;

architecture sim of tb_adder is
    signal a_32, b_32, y_32 : std_logic_vector(31 downto 0);
    signal a_4, b_4, y_4    : std_logic_vector(3 downto 0);
begin

    dut32 : entity work.adder
        generic map (WIDTH => 32)
        port map (a => a_32, b => b_32, y => y_32);

    dut4 : entity work.adder
        generic map (WIDTH => 4)
        port map (a => a_4, b => b_4, y => y_4);

    stim : process
        variable errors   : natural := 0;
        variable expected : std_logic_vector(3 downto 0);

        procedure check32 (va, vb, exp : std_logic_vector(31 downto 0);
                           msg         : string) is
        begin
            a_32 <= va;
            b_32 <= vb;
            wait for 10 ns;
            if y_32 /= exp then
                errors := errors + 1;
                report msg & ": " & to_hstring(va) & " + " & to_hstring(vb) &
                       " expected " & to_hstring(exp) &
                       ", got " & to_hstring(y_32) severity error;
            end if;
        end procedure;

    begin
        check32(x"00000000", x"00000004", x"00000004", "0 + 4");
        check32(x"00000008", x"00000004", x"0000000C", "8 + 4");
        check32(x"0000FFFC", x"00000004", x"00010000", "carry into upper half");
        check32(x"FFFFFFFC", x"00000004", x"00000000", "wrap-around");
        check32(x"12345678", x"87654321", x"99999999", "arbitrary");
        check32(x"00000010", x"FFFFFFF8", x"00000008", "16 + (-8)");

        for i in 0 to 15 loop
            for j in 0 to 15 loop
                a_4 <= std_logic_vector(to_unsigned(i, 4));
                b_4 <= std_logic_vector(to_unsigned(j, 4));
                wait for 10 ns;

                expected := std_logic_vector(to_unsigned((i + j) mod 16, 4));

                if y_4 /= expected then
                    errors := errors + 1;
                    report "4-bit " & integer'image(i) & " + " & integer'image(j) &
                           " expected " & to_string(expected) &
                           ", got " & to_string(y_4) severity error;
                end if;
            end loop;
        end loop;

        report "Test finished, errors: " & integer'image(errors);
        wait;
    end process;

end architecture sim;