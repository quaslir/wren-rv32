library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_store_align is
end entity tb_store_align;

architecture sim of tb_store_align is
    signal size    : std_logic_vector(1 downto 0)  := (others => '0');
    signal addr_lo : std_logic_vector(1 downto 0)  := (others => '0');
    signal wd      : std_logic_vector(31 downto 0) := (others => '0');
    signal wd_out  : std_logic_vector(31 downto 0);
    signal be      : std_logic_vector(3 downto 0);

    type word_array is array (natural range <>) of std_logic_vector(31 downto 0);
    constant DIRECTED : word_array := (
        x"00000000", x"FFFFFFFF", x"123456AB", x"80000000",
        x"0000007F", x"00000080", x"000000FF", x"00007FFF",
        x"00008000", x"0000FFFF", x"7FFFFFFF", x"A5A5A5A5",
        x"5A5A5A5A", x"DEADBEEF", x"01020304", x"FF00FF00"
    );
    constant RANDOM_PER_CASE : natural := 500;

    function ref_be(s : std_logic_vector(1 downto 0); a : std_logic_vector(1 downto 0))
        return std_logic_vector is
        variable r : std_logic_vector(3 downto 0) := "0000";
        variable i : natural;
    begin
        i := to_integer(unsigned(a));
        case s is
            when "00" =>
                r(i) := '1';
            when "01" =>
                if a(1) = '0' then
                    r := "0011";
                else
                    r := "1100";
                end if;
            when "10" =>
                r := "1111";
            when others =>
                r := "0000";
        end case;
        return r;
    end function;

    function ref_wd(s : std_logic_vector(1 downto 0); d : std_logic_vector(31 downto 0))
        return std_logic_vector is
    begin
        case s is
            when "00"   => return d(7 downto 0) & d(7 downto 0) & d(7 downto 0) & d(7 downto 0);
            when "01"   => return d(15 downto 0) & d(15 downto 0);
            when others => return d;
        end case;
    end function;
begin
    dut : entity work.store_align
        port map(
            size    => size,
            addr_lo => addr_lo,
            wd      => wd,
            wd_out  => wd_out,
            be      => be
        );

    stim : process
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable seed1  : positive := 42;
        variable seed2  : positive := 7;
        variable r      : real;
        variable rnd    : std_logic_vector(31 downto 0);

        procedure check(s : std_logic_vector(1 downto 0);
                        a : std_logic_vector(1 downto 0);
                        d : std_logic_vector(31 downto 0)) is
            variable exp_be : std_logic_vector(3 downto 0);
            variable exp_wd : std_logic_vector(31 downto 0);
        begin
            size    <= s;
            addr_lo <= a;
            wd      <= d;
            wait for 1 ns;
            exp_be := ref_be(s, a);
            exp_wd := ref_wd(s, d);
            checks := checks + 1;
            if be /= exp_be then
                errors := errors + 1;
                report "be mismatch: size=" & to_string(s) & " addr_lo=" & to_string(a) &
                       " wd=0x" & to_hstring(d) & " got=" & to_string(be) &
                       " expected=" & to_string(exp_be) severity error;
            end if;
            if s /= "11" and wd_out /= exp_wd then
                errors := errors + 1;
                report "wd_out mismatch: size=" & to_string(s) & " addr_lo=" & to_string(a) &
                       " wd=0x" & to_hstring(d) & " got=0x" & to_hstring(wd_out) &
                       " expected=0x" & to_hstring(exp_wd) severity error;
            end if;
            if s = "11" and is_x(wd_out) then
                errors := errors + 1;
                report "wd_out undefined for size=11: addr_lo=" & to_string(a) &
                       " got=0x" & to_hstring(wd_out) severity error;
            end if;
        end procedure;

        procedure check_case(s : std_logic_vector(1 downto 0);
                             a : std_logic_vector(1 downto 0);
                             d : std_logic_vector(31 downto 0);
                             exp_be : std_logic_vector(3 downto 0);
                             exp_wd : std_logic_vector(31 downto 0)) is
        begin
            size    <= s;
            addr_lo <= a;
            wd      <= d;
            wait for 1 ns;
            checks := checks + 1;
            if be /= exp_be or wd_out /= exp_wd then
                errors := errors + 1;
                report "directed: size=" & to_string(s) & " addr_lo=" & to_string(a) &
                       " wd=0x" & to_hstring(d) &
                       " got be=" & to_string(be) & " wd_out=0x" & to_hstring(wd_out) &
                       " expected be=" & to_string(exp_be) & " wd_out=0x" & to_hstring(exp_wd)
                       severity error;
            end if;
        end procedure;
    begin
        check_case("00", "00", x"123456AB", "0001", x"ABABABAB");
        check_case("00", "01", x"123456AB", "0010", x"ABABABAB");
        check_case("00", "10", x"123456AB", "0100", x"ABABABAB");
        check_case("00", "11", x"123456AB", "1000", x"ABABABAB");
        check_case("01", "00", x"123456AB", "0011", x"56AB56AB");
        check_case("01", "01", x"123456AB", "0011", x"56AB56AB");
        check_case("01", "10", x"123456AB", "1100", x"56AB56AB");
        check_case("01", "11", x"123456AB", "1100", x"56AB56AB");
        check_case("10", "00", x"123456AB", "1111", x"123456AB");
        check_case("10", "01", x"123456AB", "1111", x"123456AB");
        check_case("10", "10", x"123456AB", "1111", x"123456AB");
        check_case("10", "11", x"123456AB", "1111", x"123456AB");

        for s in 0 to 3 loop
            for a in 0 to 3 loop
                for k in DIRECTED'range loop
                    check(std_logic_vector(to_unsigned(s, 2)),
                          std_logic_vector(to_unsigned(a, 2)),
                          DIRECTED(k));
                end loop;
                for k in 1 to RANDOM_PER_CASE loop
                    for b in 0 to 3 loop
                        uniform(seed1, seed2, r);
                        rnd(8 * b + 7 downto 8 * b) :=
                            std_logic_vector(to_unsigned(integer(floor(r * 256.0)) mod 256, 8));
                    end loop;
                    check(std_logic_vector(to_unsigned(s, 2)),
                          std_logic_vector(to_unsigned(a, 2)),
                          rnd);
                end loop;
            end loop;
        end loop;

        report "tb_store_align: " & integer'image(checks) & " checks, " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_store_align FAILED" severity failure;
        report "tb_store_align PASSED";
        std.env.finish;
    end process;
end architecture sim;