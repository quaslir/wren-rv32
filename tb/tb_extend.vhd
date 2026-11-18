library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_extend is
    generic(
        FILLS             : positive := 4;
        CHECK_UNUSED_ZERO : boolean  := true
    );
end entity tb_extend;

architecture sim of tb_extend is
    signal instr   : std_logic_vector(31 downto 0) := (others => '0');
    signal imm_src : std_logic_vector(2 downto 0)  := (others => '0');
    signal imm_ext : std_logic_vector(31 downto 0);
begin
    dut : entity work.extend
        port map(
            instr   => instr,
            imm_src => imm_src,
            imm_ext => imm_ext
        );

    stim : process
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 55;
        variable s2     : positive := 66;
        variable r      : real;
        variable fill   : std_logic_vector(31 downto 0);
        variable v      : std_logic_vector(31 downto 0);
        variable u12    : std_logic_vector(11 downto 0);
        variable u13    : std_logic_vector(12 downto 0);
        variable exp    : std_logic_vector(31 downto 0);

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

        procedure check(fmt : string; src : std_logic_vector(2 downto 0); iv, ev : std_logic_vector(31 downto 0); imm : integer) is
        begin
            instr   <= iv;
            imm_src <= src;
            wait for 1 ns;
            checks := checks + 1;
            if imm_ext /= ev then
                fail(fmt & " imm=" & integer'image(imm) & " instr=0x" & to_hstring(iv) & " got=0x" & to_hstring(imm_ext) &
                     " expected=0x" & to_hstring(ev));
            end if;
        end procedure;

        function fill_pattern(k : natural; rw : std_logic_vector(31 downto 0)) return std_logic_vector is
        begin
            case k is
                when 0      => return x"00000000";
                when 1      => return x"FFFFFFFF";
                when others => return rw;
            end case;
        end function;
    begin
        for k in 0 to FILLS + 1 loop
            for imm in -2048 to 2047 loop
                fill := fill_pattern(k, rnd_word);
                u12  := std_logic_vector(to_signed(imm, 12));
                exp  := std_logic_vector(to_signed(imm, 32));

                v := u12 & fill(19 downto 0);
                check("I", "000", v, exp, imm);

                v := u12(11 downto 5) & fill(24 downto 12) & u12(4 downto 0) & fill(6 downto 0);
                check("S", "001", v, exp, imm);

                u13 := std_logic_vector(to_signed(2 * imm, 13));
                exp := std_logic_vector(to_signed(2 * imm, 32));
                v := u13(12) & u13(10 downto 5) & fill(24 downto 12) & u13(4 downto 1) & u13(11) & fill(6 downto 0);
                check("B", "010", v, exp, 2 * imm);
            end loop;
        end loop;

        check("I", "000", x"80000013", x"FFFFF800", -2048);
        check("I", "000", x"7FF00013", x"000007FF", 2047);
        check("I", "000", x"FFF00013", x"FFFFFFFF", -1);
        check("S", "001", x"FE000FA3", x"FFFFFFFF", -1);
        check("S", "001", x"7E000FA3", x"000007FF", 2047);
        check("S", "001", x"80000023", x"FFFFF800", -2048);
        check("B", "010", x"FE000FE3", x"FFFFFFFE", -2);
        check("B", "010", x"7E000FE3", x"00000FFE", 4094);
        check("B", "010", x"80000063", x"FFFFF000", -4096);
        check("B", "010", x"000000E3", x"00000800", 2048);
        check("B", "010", x"00000463", x"00000008", 8);

        if CHECK_UNUSED_ZERO then
            for src in 3 to 7 loop
                for n in 1 to 2000 loop
                    v := rnd_word;
                    if n = 1 then
                        v := x"FFFFFFFF";
                    end if;
                    check("unused " & integer'image(src), std_logic_vector(to_unsigned(src, 3)), v, x"00000000", 0);
                end loop;
            end loop;
        else
            for src in 3 to 7 loop
                for n in 1 to 100 loop
                    instr   <= rnd_word;
                    imm_src <= std_logic_vector(to_unsigned(src, 3));
                    wait for 1 ns;
                    checks := checks + 1;
                    if is_x(imm_ext) then
                        fail("undefined imm_ext for imm_src=" & integer'image(src));
                    end if;
                end loop;
            end loop;
        end if;

        report "tb_extend: " & integer'image(checks) & " checks, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_extend FAILED" severity failure;
        report "tb_extend PASSED";
        std.env.finish;
    end process;
end architecture sim;