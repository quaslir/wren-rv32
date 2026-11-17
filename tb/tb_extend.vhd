library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_extend is
end entity tb_extend;

architecture sim of tb_extend is
    signal instr   : std_logic_vector(31 downto 0) := (others => '0');
    signal imm_src : std_logic_vector(1 downto 0) := "00";
    signal imm_ext : std_logic_vector(31 downto 0);

    function enc_i(imm : integer; other : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable v : std_logic_vector(31 downto 0) := other;
        variable u : std_logic_vector(11 downto 0) := std_logic_vector(to_signed(imm, 12));
    begin
        v(31 downto 20) := u;
        return v;
    end function;

    function enc_b(imm : integer; other : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable v : std_logic_vector(31 downto 0) := other;
        variable u : std_logic_vector(12 downto 0) := std_logic_vector(to_signed(imm, 13));
    begin
        v(31)           := u(12);
        v(30 downto 25) := u(10 downto 5);
        v(11 downto 8)  := u(4 downto 1);
        v(7)            := u(11);
        return v;
    end function;
begin
    dut : entity work.extend
        port map(
            instr   => instr,
            imm_src => imm_src,
            imm_ext => imm_ext
        );

    stim : process
        variable err   : natural := 0;
        variable cnt   : natural := 0;
        variable s1    : positive := 42;
        variable s2    : positive := 7;
        variable r     : real;
        variable other : std_logic_vector(31 downto 0);

        impure function rand_word return std_logic_vector is
            variable w : std_logic_vector(31 downto 0);
        begin
            for b in 0 to 31 loop
                uniform(s1, s2, r);
                if r < 0.5 then
                    w(b) := '0';
                else
                    w(b) := '1';
                end if;
            end loop;
            return w;
        end function;

        procedure check(name : string; i : std_logic_vector(31 downto 0); src : std_logic_vector(1 downto 0); expected : integer) is
            variable exp : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(expected, 32));
        begin
            instr   <= i;
            imm_src <= src;
            wait for 1 ns;
            cnt := cnt + 1;
            if imm_ext /= exp then
                if err < 20 then
                    report "FAIL " & name & " instr=0x" & to_hstring(i) & " src=" & to_string(src)
                        & " got=0x" & to_hstring(imm_ext) & " expected=0x" & to_hstring(exp)
                        & " (" & integer'image(expected) & ")" severity error;
                end if;
                err := err + 1;
            end if;
        end procedure;
    begin
        check("I addi 5",       x"00500093", "00", 5);
        check("I addi -1",      x"FFF00393", "00", -1);
        check("I max",          x"7FF00093", "00", 2047);
        check("I min",          x"80000093", "00", -2048);
        check("B beq +8",       x"00208463", "10", 8);
        check("B beq -8",       x"FE000CE3", "10", -8);
        check("B beq +4094",    x"7E000FE3", "10", 4094);
        check("B beq -4096",    x"80000063", "10", -4096);

        for imm in -2048 to 2047 loop
            check("I all zero",  enc_i(imm, x"00000000"), "00", imm);
            check("I all ones",  enc_i(imm, x"FFFFFFFF"), "00", imm);
            other := rand_word;
            check("I random",    enc_i(imm, other), "00", imm);
        end loop;

        for k in -2048 to 2047 loop
            check("B all zero",  enc_b(2 * k, x"00000000"), "10", 2 * k);
            check("B all ones",  enc_b(2 * k, x"FFFFFFFF"), "10", 2 * k);
            other := rand_word;
            check("B random",    enc_b(2 * k, other), "10", 2 * k);
        end loop;

        for n in 1 to 200 loop
            check("src 11",      rand_word, "11", 0);
        end loop;

        if err = 0 then
            report "tb_extend: ALL " & integer'image(cnt) & " TESTS PASSED" severity note;
        else
            report "tb_extend: " & integer'image(err) & " / " & integer'image(cnt) & " FAILED" severity failure;
        end if;
        std.env.finish;
    end process;
end architecture sim;