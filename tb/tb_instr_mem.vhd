library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_instr_mem is
    generic(
        DEPTH : positive := 64
    );
end entity tb_instr_mem;

architecture sim of tb_instr_mem is
    signal addr       : std_logic_vector(31 downto 0) := (others => '0');
    signal instr_test : std_logic_vector(31 downto 0);
    signal instr_gaps : std_logic_vector(31 downto 0);
    signal instr_long : std_logic_vector(31 downto 0);
    signal instr_shrt : std_logic_vector(31 downto 0);

    function gen(i : natural) return std_logic_vector is
        variable p : unsigned(63 downto 0);
    begin
        p := to_unsigned(i, 32) * unsigned'(x"9E3779B1");
        return std_logic_vector(p(31 downto 0) + unsigned'(x"7F4A7C15"));
    end function;

    type word_arr_t is array (natural range <>) of std_logic_vector(31 downto 0);
    constant TEST_HEX : word_arr_t := (x"00500093", x"00300113", x"002081B3");
begin
    dut_test : entity work.instr_mem
        generic map(INIT_FILE => "sw/test.hex", DEPTH => DEPTH)
        port map(addr => addr, instr => instr_test);

    dut_gaps : entity work.instr_mem
        generic map(INIT_FILE => "tb/data/imem_gaps.hex", DEPTH => DEPTH)
        port map(addr => addr, instr => instr_gaps);

    dut_long : entity work.instr_mem
        generic map(INIT_FILE => "tb/data/imem_long.hex", DEPTH => DEPTH)
        port map(addr => addr, instr => instr_long);

    dut_shrt : entity work.instr_mem
        generic map(INIT_FILE => "tb/data/imem_short.hex", DEPTH => DEPTH)
        port map(addr => addr, instr => instr_shrt);

    stim : process
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 12;
        variable s2     : positive := 34;
        variable r      : real;
        variable a      : std_logic_vector(31 downto 0);
        variable idx    : natural;
        variable e_test, e_gaps, e_long, e_shrt : std_logic_vector(31 downto 0);

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "addr=0x" & to_hstring(addr) & ": " & msg severity error;
            end if;
        end procedure;

        procedure cmp(name : string; got, exp : std_logic_vector(31 downto 0)) is
        begin
            checks := checks + 1;
            if got /= exp then
                fail(name & " got=0x" & to_hstring(got) & " expected=0x" & to_hstring(exp));
            end if;
        end procedure;

        procedure check_addr(av : std_logic_vector(31 downto 0)) is
            variable in_range : boolean;
        begin
            addr <= av;
            wait for 1 ns;
            in_range := unsigned(av(31 downto 2)) < DEPTH;
            if in_range then
                idx := to_integer(unsigned(av(31 downto 2)));
                if idx < TEST_HEX'length then
                    e_test := TEST_HEX(idx);
                else
                    e_test := x"00000000";
                end if;
                e_gaps := gen(idx);
                e_long := gen(1000 + idx);
                if idx < 5 then
                    e_shrt := gen(500 + idx);
                else
                    e_shrt := x"00000000";
                end if;
            else
                e_test := x"00000000";
                e_gaps := x"00000000";
                e_long := x"00000000";
                e_shrt := x"00000000";
            end if;
            cmp("sw/test.hex", instr_test, e_test);
            cmp("imem_gaps.hex", instr_gaps, e_gaps);
            cmp("imem_long.hex", instr_long, e_long);
            cmp("imem_short.hex", instr_shrt, e_shrt);
        end procedure;
    begin
        for i in 0 to DEPTH - 1 loop
            for lo in 0 to 3 loop
                check_addr(std_logic_vector(to_unsigned(4 * i + lo, 32)));
            end loop;
        end loop;
        for i in DEPTH to DEPTH + 40 loop
            check_addr(std_logic_vector(to_unsigned(4 * i, 32)));
        end loop;
        check_addr(std_logic_vector(to_unsigned(4 * DEPTH, 32)));
        check_addr(std_logic_vector(to_unsigned(4 * DEPTH - 1, 32)));
        check_addr(x"00000100");
        check_addr(x"00010000");
        check_addr(x"7FFFFFFC");
        check_addr(x"80000000");
        check_addr(x"FFFFFFFC");
        check_addr(x"FFFFFFFF");
        for n in 1 to 3000 loop
            if rnd(4) = 0 then
                a := std_logic_vector(to_unsigned(rnd(65536), 16)) & std_logic_vector(to_unsigned(rnd(65536), 16));
            else
                a := std_logic_vector(to_unsigned(rnd(4 * DEPTH), 32));
            end if;
            check_addr(a);
        end loop;
        for i in 0 to DEPTH - 1 loop
            check_addr(std_logic_vector(to_unsigned(4 * (DEPTH - 1 - i), 32)));
        end loop;

        report "tb_instr_mem: " & integer'image(checks) & " checks, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_instr_mem FAILED" severity failure;
        report "tb_instr_mem PASSED";
        std.env.finish;
    end process;
end architecture sim;