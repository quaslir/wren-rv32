library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_mux8 is
end entity tb_mux8;

architecture sim of tb_mux8 is
    constant W : positive := 32;
    type data_arr is array (0 to 7) of std_logic_vector(W - 1 downto 0);
    signal d   : data_arr := (others => (others => '0'));
    signal sel : std_logic_vector(2 downto 0) := "000";
    signal y   : std_logic_vector(W - 1 downto 0);
    signal y8  : std_logic_vector(7 downto 0);
    signal d8  : std_logic_vector(7 downto 0) := (others => '0');
begin
    dut: entity work.mux8
        generic map(WIDTH => W)
        port map(d0 => d(0), d1 => d(1), d2 => d(2), d3 => d(3),
                 d4 => d(4), d5 => d(5), d6 => d(6), d7 => d(7), sel => sel, y => y);

    dut1: entity work.mux8
        generic map(WIDTH => 1)
        port map(d0 => d8(0 downto 0), d1 => d8(1 downto 1), d2 => d8(2 downto 2), d3 => d8(3 downto 3),
                 d4 => d8(4 downto 4), d5 => d8(5 downto 5), d6 => d8(6 downto 6), d7 => d8(7 downto 7),
                 sel => sel, y => y8(0 downto 0));

    stim: process
        variable errors, checks : natural := 0;
        variable s1, s2 : positive := 3;
        variable r : real;
        variable v : data_arr;
        variable k : natural;

        impure function rnd_slv(n : positive) return std_logic_vector is
            variable x : std_logic_vector(n - 1 downto 0);
        begin
            for i in x'range loop
                uniform(s1, s2, r);
                if r < 0.5 then x(i) := '0'; else x(i) := '1'; end if;
            end loop;
            return x;
        end function;

        procedure chk(ok : boolean; what : string) is
        begin
            checks := checks + 1;
            if not ok then
                errors := errors + 1;
                if errors <= 20 then
                    report what severity error;
                end if;
            end if;
        end procedure;
    begin
        for s in 0 to 7 loop
            for i in 0 to 7 loop
                v(i) := std_logic_vector(to_unsigned(16#11111111# * i, W));
            end loop;
            d <= v;
            sel <= std_logic_vector(to_unsigned(s, 3));
            wait for 1 ns;
            chk(y = v(s), "sel=" & integer'image(s) & " y=" & to_hstring(y) & " exp " & to_hstring(v(s)));
        end loop;

        for s in 0 to 7 loop
            for i in 0 to 7 loop
                v := (others => (others => '0'));
                v(i) := (others => '1');
                d <= v;
                sel <= std_logic_vector(to_unsigned(s, 3));
                wait for 1 ns;
                if i = s then
                    chk(y = v(i), "one-hot: sel=" & integer'image(s) & " input " & integer'image(i) & " not passed");
                else
                    chk(y = (y'range => '0'), "one-hot: sel=" & integer'image(s) & " leaks input " & integer'image(i));
                end if;
            end loop;
        end loop;

        for s in 0 to 7 loop
            for pattern in 0 to 255 loop
                d8 <= std_logic_vector(to_unsigned(pattern, 8));
                sel <= std_logic_vector(to_unsigned(s, 3));
                wait for 1 ns;
                chk(y8(0) = d8(s), "WIDTH=1 sel=" & integer'image(s) & " pattern=" & integer'image(pattern));
            end loop;
        end loop;

        for n in 1 to 20000 loop
            for i in 0 to 7 loop
                v(i) := rnd_slv(W);
            end loop;
            k := to_integer(unsigned(rnd_slv(3)));
            d <= v;
            sel <= std_logic_vector(to_unsigned(k, 3));
            wait for 1 ns;
            chk(y = v(k), "random sel=" & integer'image(k) & " y=" & to_hstring(y) & " exp " & to_hstring(v(k)));
        end loop;

        if errors = 0 then
            report "tb_mux8: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_mux8: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & ")" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;