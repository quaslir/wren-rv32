library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_mux2 is
end entity tb_mux2;

architecture sim of tb_mux2 is
    signal d0_w, d1_w, y_w : std_logic_vector(31 downto 0);
    signal sel_w           : std_logic := '0';
    signal d0_n, d1_n, y_n : std_logic_vector(3 downto 0);
    signal sel_n           : std_logic := '0';
    signal d0_1, d1_1, y_1 : std_logic_vector(0 downto 0);
    signal sel_1           : std_logic := '0';
begin
    dut_w : entity work.mux2
        generic map(WIDTH => 32)
        port map(d0 => d0_w, d1 => d1_w, sel => sel_w, y => y_w);

    dut_n : entity work.mux2
        generic map(WIDTH => 4)
        port map(d0 => d0_n, d1 => d1_n, sel => sel_n, y => y_n);

    dut_1 : entity work.mux2
        generic map(WIDTH => 1)
        port map(d0 => d0_1, d1 => d1_1, sel => sel_1, y => y_1);

    stim : process
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 3;
        variable s2     : positive := 5;
        variable r      : real;
        variable x, y   : std_logic_vector(31 downto 0);

        impure function rnd_word return std_logic_vector is
            variable w : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 3 loop
                uniform(s1, s2, r);
                w(8 * i + 7 downto 8 * i) := std_logic_vector(to_unsigned(integer(trunc(r * 256.0)) mod 256, 8));
            end loop;
            return w;
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report msg severity error;
            end if;
        end procedure;

        procedure check_w(a0, a1 : std_logic_vector(31 downto 0)) is
        begin
            d0_w <= a0;
            d1_w <= a1;
            for s in 0 to 1 loop
                if s = 0 then
                    sel_w <= '0';
                else
                    sel_w <= '1';
                end if;
                wait for 1 ns;
                checks := checks + 1;
                if (s = 0 and y_w /= a0) or (s = 1 and y_w /= a1) then
                    fail("WIDTH=32 sel=" & integer'image(s) & " d0=0x" & to_hstring(a0) & " d1=0x" & to_hstring(a1) &
                         " y=0x" & to_hstring(y_w));
                end if;
            end loop;
        end procedure;
    begin
        check_w(x"00000000", x"FFFFFFFF");
        check_w(x"FFFFFFFF", x"00000000");
        check_w(x"55555555", x"AAAAAAAA");
        check_w(x"80000001", x"7FFFFFFE");
        for i in 0 to 31 loop
            check_w(std_logic_vector(shift_left(to_unsigned(1, 32), i)), x"00000000");
            check_w(x"00000000", std_logic_vector(shift_left(to_unsigned(1, 32), i)));
        end loop;
        for n in 1 to 2000 loop
            x := rnd_word;
            y := rnd_word;
            check_w(x, y);
        end loop;

        for a0 in 0 to 15 loop
            for a1 in 0 to 15 loop
                for s in 0 to 1 loop
                    d0_n <= std_logic_vector(to_unsigned(a0, 4));
                    d1_n <= std_logic_vector(to_unsigned(a1, 4));
                    if s = 0 then
                        sel_n <= '0';
                    else
                        sel_n <= '1';
                    end if;
                    wait for 1 ns;
                    checks := checks + 1;
                    if (s = 0 and to_integer(unsigned(y_n)) /= a0) or (s = 1 and to_integer(unsigned(y_n)) /= a1) then
                        fail("WIDTH=4 d0=" & integer'image(a0) & " d1=" & integer'image(a1) & " sel=" & integer'image(s) &
                             " y=" & to_string(y_n));
                    end if;
                end loop;
            end loop;
        end loop;

        for a0 in 0 to 1 loop
            for a1 in 0 to 1 loop
                for s in 0 to 1 loop
                    d0_1 <= std_logic_vector(to_unsigned(a0, 1));
                    d1_1 <= std_logic_vector(to_unsigned(a1, 1));
                    if s = 0 then
                        sel_1 <= '0';
                    else
                        sel_1 <= '1';
                    end if;
                    wait for 1 ns;
                    checks := checks + 1;
                    if (s = 0 and to_integer(unsigned(y_1)) /= a0) or (s = 1 and to_integer(unsigned(y_1)) /= a1) then
                        fail("WIDTH=1 d0=" & integer'image(a0) & " d1=" & integer'image(a1) & " sel=" & integer'image(s));
                    end if;
                end loop;
            end loop;
        end loop;

        report "tb_mux2: " & integer'image(checks) & " checks, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_mux2 FAILED" severity failure;
        report "tb_mux2 PASSED";
        std.env.finish;
    end process;
end architecture sim;