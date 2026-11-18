library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_data_mem is
    generic(
        DEPTH : positive := 64
    );
end entity tb_data_mem;

architecture sim of tb_data_mem is
    constant T : time := 10 ns;

    signal clk  : std_logic := '0';
    signal we   : std_logic := '0';
    signal addr : std_logic_vector(31 downto 0) := (others => '0');
    signal wd   : std_logic_vector(31 downto 0) := (others => '0');
    signal be   : std_logic_vector(3 downto 0)  := (others => '0');
    signal rd   : std_logic_vector(31 downto 0);
    signal done : boolean := false;

    type mem_t is array (0 to DEPTH - 1) of std_logic_vector(31 downto 0);

    function merge(old_w : std_logic_vector(31 downto 0);
                   new_w : std_logic_vector(31 downto 0);
                   mask  : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(31 downto 0) := old_w;
    begin
        for i in 0 to 3 loop
            if mask(i) = '1' then
                r(8 * i + 7 downto 8 * i) := new_w(8 * i + 7 downto 8 * i);
            end if;
        end loop;
        return r;
    end function;

    function word_index(a : std_logic_vector(31 downto 0)) return natural is
    begin
        return to_integer(unsigned(a(31 downto 2)));
    end function;

    function in_range(a : std_logic_vector(31 downto 0)) return boolean is
    begin
        return unsigned(a(31 downto 2)) < DEPTH;
    end function;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut : entity work.data_mem
        generic map(
            DEPTH => DEPTH
        )
        port map(
            clk  => clk,
            we   => we,
            addr => addr,
            wd   => wd,
            be   => be,
            rd   => rd
        );

    stim : process
        variable model  : mem_t := (others => (others => '0'));
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable seed1  : positive := 3;
        variable seed2  : positive := 77;
        variable r      : real;
        variable w      : std_logic_vector(31 downto 0);
        variable a      : std_logic_vector(31 downto 0);
        variable m      : std_logic_vector(3 downto 0);
        variable e      : std_logic;

        impure function rand_int(lo, hi : integer) return integer is
        begin
            uniform(seed1, seed2, r);
            return lo + integer(floor(r * real(hi - lo + 1))) mod (hi - lo + 1);
        end function;

        impure function rand_word return std_logic_vector is
            variable v : std_logic_vector(31 downto 0);
        begin
            for b in 0 to 3 loop
                v(8 * b + 7 downto 8 * b) := std_logic_vector(to_unsigned(rand_int(0, 255), 8));
            end loop;
            return v;
        end function;

        procedure expect(a_in : std_logic_vector(31 downto 0); exp : std_logic_vector(31 downto 0); tag : string) is
        begin
            checks := checks + 1;
            if rd /= exp then
                errors := errors + 1;
                report tag & ": addr=0x" & to_hstring(a_in) & " got=0x" & to_hstring(rd) &
                       " expected=0x" & to_hstring(exp) severity error;
            end if;
        end procedure;

        procedure read_check(a_in : std_logic_vector(31 downto 0); tag : string) is
        begin
            we   <= '0';
            addr <= a_in;
            wait for 1 ns;
            if in_range(a_in) then
                expect(a_in, model(word_index(a_in)), tag);
            else
                expect(a_in, x"00000000", tag);
            end if;
        end procedure;

        procedure write_op(a_in  : std_logic_vector(31 downto 0);
                           d_in  : std_logic_vector(31 downto 0);
                           m_in  : std_logic_vector(3 downto 0);
                           we_in : std_logic;
                           tag   : string) is
            variable before : std_logic_vector(31 downto 0);
        begin
            wait until falling_edge(clk);
            addr <= a_in;
            wd   <= d_in;
            be   <= m_in;
            we   <= we_in;
            wait for 1 ns;
            if in_range(a_in) then
                before := model(word_index(a_in));
            else
                before := x"00000000";
            end if;
            expect(a_in, before, tag & " before edge");
            wait until rising_edge(clk);
            wait for 1 ns;
            if we_in = '1' and in_range(a_in) then
                model(word_index(a_in)) := merge(model(word_index(a_in)), d_in, m_in);
            end if;
            if in_range(a_in) then
                expect(a_in, model(word_index(a_in)), tag & " after edge");
            else
                expect(a_in, x"00000000", tag & " after edge");
            end if;
            we <= '0';
        end procedure;

        procedure full_scan(tag : string) is
        begin
            for i in 0 to DEPTH - 1 loop
                read_check(std_logic_vector(to_unsigned(4 * i, 32)), tag);
            end loop;
        end procedure;
    begin
        wait for 1 ns;
        full_scan("initial zero");

        for i in 0 to DEPTH - 1 loop
            write_op(std_logic_vector(to_unsigned(4 * i, 32)),
                     std_logic_vector(to_unsigned(i, 8)) & x"A5" & std_logic_vector(to_unsigned(255 - i, 8)) & x"3C",
                     "1111", '1', "fill");
        end loop;
        full_scan("after fill");

        for k in 0 to 15 loop
            a := std_logic_vector(to_unsigned(4 * (k mod DEPTH), 32));
            write_op(a, x"8040_20FF", "1111", '1', "mask base");
            write_op(a, x"ABCD_EF12", std_logic_vector(to_unsigned(k, 4)), '1', "mask " & integer'image(k));
        end loop;
        full_scan("after masks");

        write_op(x"00000004", x"8040_20FF", "1111", '1', "directed base");
        write_op(x"00000004", x"ABAB_ABAB", "0010", '1', "directed sb lane1");
        read_check(x"00000004", "directed sb lane1 result");
        checks := checks + 1;
        if model(1) /= x"8040_ABFF" then
            errors := errors + 1;
            report "model self-check failed" severity error;
        end if;
        write_op(x"00000004", x"56AB_56AB", "1100", '1', "directed sh upper");
        write_op(x"00000004", x"1234_56AB", "1111", '1', "directed sw");
        write_op(x"00000004", x"FFFF_FFFF", "0000", '1', "directed be=0000");

        for k in 0 to 15 loop
            write_op(x"00000008", rand_word, std_logic_vector(to_unsigned(k, 4)), '0', "we=0 mask " & integer'image(k));
        end loop;

        write_op(x"0000000D", x"CAFE_BABE", "1111", '1', "unaligned addr low bits ignored");
        read_check(x"0000000C", "unaligned check word 3");

        write_op(std_logic_vector(to_unsigned(4 * DEPTH, 32)), x"DEAD_BEEF", "1111", '1', "write at DEPTH");
        write_op(std_logic_vector(to_unsigned(4 * DEPTH + 4, 32)), x"DEAD_BEEF", "1111", '1', "write past DEPTH");
        write_op(x"80000000", x"DEAD_BEEF", "1111", '1', "write 0x80000000");
        write_op(x"FFFFFFFC", x"DEAD_BEEF", "1111", '1', "write 0xFFFFFFFC");
        write_op(std_logic_vector(to_unsigned(4 * DEPTH * 2, 32)), x"DEAD_BEEF", "1111", '1', "write 2*DEPTH alias");
        full_scan("no aliasing");
        read_check(std_logic_vector(to_unsigned(4 * DEPTH, 32)), "read at DEPTH");
        read_check(x"80000000", "read 0x80000000");
        read_check(x"FFFFFFFC", "read 0xFFFFFFFC");

        for n in 1 to 5000 loop
            if rand_int(0, 9) = 0 then
                a := std_logic_vector(to_unsigned(rand_int(DEPTH, DEPTH + 64), 30)) & "00";
            else
                a := std_logic_vector(to_unsigned(rand_int(0, DEPTH - 1), 30)) &
                     std_logic_vector(to_unsigned(rand_int(0, 3), 2));
            end if;
            m := std_logic_vector(to_unsigned(rand_int(0, 15), 4));
            if rand_int(0, 3) = 0 then
                e := '0';
            else
                e := '1';
            end if;
            write_op(a, rand_word, m, e, "random");
            if n mod 500 = 0 then
                full_scan("random scan");
            end if;
        end loop;
        full_scan("final");

        report "tb_data_mem: " & integer'image(checks) & " checks, " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_data_mem FAILED" severity failure;
        report "tb_data_mem PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;