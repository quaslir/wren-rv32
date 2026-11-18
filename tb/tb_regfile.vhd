library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_regfile is
    generic(
        N_RANDOM : natural := 5000
    );
end entity tb_regfile;

architecture sim of tb_regfile is
    constant T : time := 10 ns;

    signal clk  : std_logic := '0';
    signal we   : std_logic := '0';
    signal ra1  : std_logic_vector(4 downto 0) := (others => '0');
    signal ra2  : std_logic_vector(4 downto 0) := (others => '0');
    signal wa   : std_logic_vector(4 downto 0) := (others => '0');
    signal wd   : std_logic_vector(31 downto 0) := (others => '0');
    signal rd1  : std_logic_vector(31 downto 0);
    signal rd2  : std_logic_vector(31 downto 0);
    signal done : boolean := false;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut : entity work.regfile
        port map(
            clk => clk,
            we  => we,
            ra1 => ra1,
            ra2 => ra2,
            wa  => wa,
            wd  => wd,
            rd1 => rd1,
            rd2 => rd2
        );

    stim : process
        type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
        type valid_t is array (0 to 31) of boolean;
        variable model  : regs_t := (others => (others => '0'));
        variable valid  : valid_t := (0 => true, others => false);
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 31;
        variable s2     : positive := 41;
        variable r      : real;
        variable n_x0   : natural := 0;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        impure function rnd_word return std_logic_vector is
            variable v : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 3 loop
                v(8 * i + 7 downto 8 * i) := std_logic_vector(to_unsigned(rnd(256), 8));
            end loop;
            return v;
        end function;

        function a5(i : natural) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(i, 5));
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "@" & time'image(now) & ": " & msg severity error;
            end if;
        end procedure;

        procedure expect_reads(tag : string) is
            variable i1, i2 : natural;
        begin
            i1 := to_integer(unsigned(ra1));
            i2 := to_integer(unsigned(ra2));
            checks := checks + 2;
            if valid(i1) and rd1 /= model(i1) then
                fail(tag & ": rd1 x" & integer'image(i1) & " got=0x" & to_hstring(rd1) & " expected=0x" & to_hstring(model(i1)));
            end if;
            if valid(i2) and rd2 /= model(i2) then
                fail(tag & ": rd2 x" & integer'image(i2) & " got=0x" & to_hstring(rd2) & " expected=0x" & to_hstring(model(i2)));
            end if;
        end procedure;

        procedure op(w : std_logic; a : natural; d : std_logic_vector(31 downto 0); r1, r2 : natural; tag : string) is
        begin
            wait until falling_edge(clk);
            we  <= w;
            wa  <= a5(a);
            wd  <= d;
            ra1 <= a5(r1);
            ra2 <= a5(r2);
            wait for 1 ns;
            expect_reads(tag & " before edge");
            wait until rising_edge(clk);
            wait for 1 ns;
            if w = '1' and a /= 0 then
                model(a) := d;
                valid(a) := true;
            end if;
            if w = '1' and a = 0 then
                n_x0 := n_x0 + 1;
            end if;
            expect_reads(tag & " after edge");
        end procedure;

        procedure sweep(tag : string) is
        begin
            we <= '0';
            for i in 0 to 31 loop
                ra1 <= a5(i);
                ra2 <= a5(31 - i);
                wait for 1 ns;
                expect_reads(tag);
            end loop;
        end procedure;
    begin
        wait until rising_edge(clk);
        op('1', 0, x"FFFFFFFF", 0, 0, "x0 write at start");
        checks := checks + 1;
        if rd1 /= x"00000000" or rd2 /= x"00000000" then
            fail("x0 not zero at start");
        end if;

        for i in 1 to 31 loop
            op('1', i, std_logic_vector(to_unsigned(i, 8)) & x"A5C3" & std_logic_vector(to_unsigned(255 - i, 8)), i, (i + 1) mod 32, "fill");
        end loop;
        sweep("after fill");

        for i in 0 to 31 loop
            for j in 0 to 31 loop
                ra1 <= a5(i);
                ra2 <= a5(j);
                wait for 1 ns;
                expect_reads("all pairs");
            end loop;
        end loop;

        op('1', 0, x"DEADBEEF", 0, 0, "x0 write");
        op('1', 0, x"FFFFFFFF", 0, 5, "x0 write 2");
        op('1', 0, x"80000000", 7, 0, "x0 write 3");
        op('0', 5, x"FFFFFFFF", 5, 5, "we=0");
        op('0', 31, x"00000000", 31, 30, "we=0 x31");
        op('1', 5, x"00000000", 5, 5, "write zero");
        op('1', 5, x"FFFFFFFF", 5, 6, "write ones");
        op('1', 31, x"80000001", 31, 1, "write x31");
        op('1', 1, x"7FFFFFFE", 31, 1, "write x1");
        sweep("after directed");

        for i in 1 to 31 loop
            op('1', i, x"00000000", 0, 0, "clear");
            op('1', i, std_logic_vector(shift_left(to_unsigned(1, 32), i)), i, (i * 7) mod 32, "walking one");
            for j in 0 to 31 loop
                ra1 <= a5(j);
                ra2 <= a5((j + 13) mod 32);
                wait for 1 ns;
                expect_reads("isolation");
            end loop;
        end loop;

        for n in 1 to N_RANDOM loop
            if rnd(4) = 0 then
                op('0', rnd(32), rnd_word, rnd(32), rnd(32), "random we=0");
            elsif rnd(10) = 0 then
                op('1', 0, rnd_word, rnd(32), 0, "random x0");
            else
                op('1', rnd(32), rnd_word, rnd(32), rnd(32), "random");
            end if;
            if n mod 1000 = 0 then
                sweep("random sweep");
            end if;
        end loop;
        sweep("final");

        report "tb_regfile: " & integer'image(checks) & " checks, " & integer'image(n_x0) & " writes to x0, " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_regfile FAILED" severity failure;
        report "tb_regfile PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;