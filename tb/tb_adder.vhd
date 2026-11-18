library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_adder is
end entity tb_adder;

architecture sim of tb_adder is
    signal a_w, b_w, y_w : std_logic_vector(31 downto 0);
    signal a_n, b_n, y_n : std_logic_vector(5 downto 0);
begin
    dut_w : entity work.adder
        generic map(WIDTH => 32)
        port map(a => a_w, b => b_w, y => y_w);

    dut_n : entity work.adder
        generic map(WIDTH => 6)
        port map(a => a_n, b => b_n, y => y_n);

    stim : process
        type word_arr_t is array (natural range <>) of std_logic_vector(31 downto 0);
        constant EDGE : word_arr_t := (
            x"00000000", x"00000001", x"00000004", x"7FFFFFFF", x"80000000", x"80000001",
            x"FFFFFFFF", x"FFFFFFFC", x"0000FFFF", x"FFFF0000", x"55555555", x"AAAAAAAA"
        );
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 21;
        variable s2     : positive := 34;
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

        function ripple(p, q : std_logic_vector(31 downto 0)) return std_logic_vector is
            variable s : std_logic_vector(31 downto 0);
            variable c : std_logic := '0';
        begin
            for i in 0 to 31 loop
                s(i) := p(i) xor q(i) xor c;
                c    := (p(i) and q(i)) or (c and (p(i) xor q(i)));
            end loop;
            return s;
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report msg severity error;
            end if;
        end procedure;

        procedure check_w(p, q : std_logic_vector(31 downto 0)) is
        begin
            a_w <= p;
            b_w <= q;
            wait for 1 ns;
            checks := checks + 1;
            if y_w /= ripple(p, q) then
                fail("WIDTH=32 0x" & to_hstring(p) & " + 0x" & to_hstring(q) & " got=0x" & to_hstring(y_w) &
                     " expected=0x" & to_hstring(ripple(p, q)));
            end if;
        end procedure;
    begin
        for i in EDGE'range loop
            for j in EDGE'range loop
                check_w(EDGE(i), EDGE(j));
            end loop;
        end loop;
        for i in 0 to 31 loop
            check_w(std_logic_vector(shift_left(to_unsigned(1, 32), i)), std_logic_vector(shift_left(to_unsigned(1, 32), i)));
            check_w(x"FFFFFFFF", std_logic_vector(shift_left(to_unsigned(1, 32), i)));
        end loop;
        for n in 1 to 5000 loop
            x := rnd_word;
            y := rnd_word;
            check_w(x, y);
        end loop;

        for p in 0 to 63 loop
            for q in 0 to 63 loop
                a_n <= std_logic_vector(to_unsigned(p, 6));
                b_n <= std_logic_vector(to_unsigned(q, 6));
                wait for 1 ns;
                checks := checks + 1;
                if to_integer(unsigned(y_n)) /= (p + q) mod 64 then
                    fail("WIDTH=6 " & integer'image(p) & " + " & integer'image(q) & " got=" & to_string(y_n));
                end if;
            end loop;
        end loop;

        report "tb_adder: " & integer'image(checks) & " checks, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_adder FAILED" severity failure;
        report "tb_adder PASSED";
        std.env.finish;
    end process;
end architecture sim;