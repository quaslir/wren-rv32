library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_mux4 is
end entity tb_mux4;

architecture sim of tb_mux4 is
    signal d0_w, d1_w, d2_w, d3_w, y_w : std_logic_vector(31 downto 0);
    signal sel_w                       : std_logic_vector(1 downto 0) := "00";
    signal d0_n, d1_n, d2_n, d3_n, y_n : std_logic_vector(2 downto 0);
    signal sel_n                       : std_logic_vector(1 downto 0) := "00";
begin
    dut_w : entity work.mux4
        generic map(WIDTH => 32)
        port map(d0 => d0_w, d1 => d1_w, d2 => d2_w, d3 => d3_w, sel => sel_w, y => y_w);

    dut_n : entity work.mux4
        generic map(WIDTH => 3)
        port map(d0 => d0_n, d1 => d1_n, d2 => d2_n, d3 => d3_n, sel => sel_n, y => y_n);

    stim : process
        type w4_t is array (0 to 3) of std_logic_vector(31 downto 0);
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 9;
        variable s2     : positive := 13;
        variable r      : real;
        variable d      : w4_t;

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

        procedure check_w(v : w4_t) is
        begin
            d0_w <= v(0);
            d1_w <= v(1);
            d2_w <= v(2);
            d3_w <= v(3);
            for s in 0 to 3 loop
                sel_w <= std_logic_vector(to_unsigned(s, 2));
                wait for 1 ns;
                checks := checks + 1;
                if y_w /= v(s) then
                    fail("WIDTH=32 sel=" & integer'image(s) & " y=0x" & to_hstring(y_w) & " expected=0x" & to_hstring(v(s)));
                end if;
            end loop;
        end procedure;
    begin
        check_w((x"00000000", x"FFFFFFFF", x"55555555", x"AAAAAAAA"));
        check_w((x"FFFFFFFF", x"00000000", x"AAAAAAAA", x"55555555"));
        check_w((x"11111111", x"22222222", x"44444444", x"88888888"));
        for i in 0 to 31 loop
            for k in 0 to 3 loop
                d := (others => (others => '0'));
                d(k) := std_logic_vector(shift_left(to_unsigned(1, 32), i));
                check_w(d);
                d := (others => (others => '1'));
                d(k)(i) := '0';
                check_w(d);
            end loop;
        end loop;
        for n in 1 to 2000 loop
            for k in 0 to 3 loop
                d(k) := rnd_word;
            end loop;
            check_w(d);
        end loop;

        for a0 in 0 to 7 loop
            for a1 in 0 to 7 loop
                for a2 in 0 to 7 loop
                    for a3 in 0 to 7 loop
                        d0_n <= std_logic_vector(to_unsigned(a0, 3));
                        d1_n <= std_logic_vector(to_unsigned(a1, 3));
                        d2_n <= std_logic_vector(to_unsigned(a2, 3));
                        d3_n <= std_logic_vector(to_unsigned(a3, 3));
                        for s in 0 to 3 loop
                            sel_n <= std_logic_vector(to_unsigned(s, 2));
                            wait for 1 ns;
                            checks := checks + 1;
                            if (s = 0 and to_integer(unsigned(y_n)) /= a0) or (s = 1 and to_integer(unsigned(y_n)) /= a1) or
                               (s = 2 and to_integer(unsigned(y_n)) /= a2) or (s = 3 and to_integer(unsigned(y_n)) /= a3) then
                                fail("WIDTH=3 sel=" & integer'image(s) & " y=" & to_string(y_n));
                            end if;
                        end loop;
                    end loop;
                end loop;
            end loop;
        end loop;

        report "tb_mux4: " & integer'image(checks) & " checks, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_mux4 FAILED" severity failure;
        report "tb_mux4 PASSED";
        std.env.finish;
    end process;
end architecture sim;