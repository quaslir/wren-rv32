library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
 
entity tb_ram is
    generic(
        DEPTH     : positive := 64;
        INIT_FILE : string   := "tb/data/imem_gaps.hex";
        INIT_GEN  : boolean  := true;
        N_RANDOM  : natural  := 5000
    );
end entity tb_ram;
 
architecture sim of tb_ram is
    constant T : time := 10 ns;
 
    signal clk    : std_logic := '0';
    signal we     : std_logic := '0';
    signal addr   : std_logic_vector(31 downto 0) := (others => '0');
    signal addr_a : std_logic_vector(31 downto 0) := (others => '0');
    signal wd     : std_logic_vector(31 downto 0) := (others => '0');
    signal be     : std_logic_vector(3 downto 0)  := (others => '0');
    signal rd     : std_logic_vector(31 downto 0);
    signal rd_a   : std_logic_vector(31 downto 0);
    signal done   : boolean := false;
 
    type mem_t is array (0 to DEPTH - 1) of std_logic_vector(31 downto 0);
 
    function gen(i : natural) return std_logic_vector is
        variable p : unsigned(63 downto 0);
    begin
        p := to_unsigned(i, 32) * unsigned'(x"9E3779B1");
        return std_logic_vector(p(31 downto 0) + unsigned'(x"7F4A7C15"));
    end function;
 
    function initial_model return mem_t is
        variable m : mem_t := (others => (others => '0'));
    begin
        if INIT_GEN then
            for i in 0 to DEPTH - 1 loop
                m(i) := gen(i);
            end loop;
        end if;
        return m;
    end function;
 
    function merge(old_w, new_w : std_logic_vector(31 downto 0); mask : std_logic_vector(3 downto 0))
        return std_logic_vector is
        variable r : std_logic_vector(31 downto 0) := old_w;
    begin
        for i in 0 to 3 loop
            if mask(i) = '1' then
                r(8 * i + 7 downto 8 * i) := new_w(8 * i + 7 downto 8 * i);
            end if;
        end loop;
        return r;
    end function;
 
    function in_range(a : std_logic_vector(31 downto 0)) return boolean is
    begin
        return unsigned(a(31 downto 2)) < DEPTH;
    end function;
 
    function idx(a : std_logic_vector(31 downto 0)) return natural is
    begin
        return to_integer(unsigned(a(31 downto 2)));
    end function;
begin
    clk <= not clk after T / 2 when not done else '0';
 
    dut : entity work.ram
        generic map(
            DEPTH     => DEPTH,
            INIT_FILE => INIT_FILE
        )
        port map(
            clk    => clk,
            we     => we,
            addr   => addr,
            addr_a => addr_a,
            wd     => wd,
            be     => be,
            rd     => rd,
            rd_a   => rd_a
        );
 
    stim : process
        variable model  : mem_t := initial_model;
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable s1     : positive := 5;
        variable s2     : positive := 91;
        variable r      : real;
        variable a, b   : std_logic_vector(31 downto 0);
        variable m      : std_logic_vector(3 downto 0);
        variable e      : std_logic;
 
        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;
 
        impure function rnd_word return std_logic_vector is
            variable w : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 3 loop
                w(8 * i + 7 downto 8 * i) := std_logic_vector(to_unsigned(rnd(256), 8));
            end loop;
            return w;
        end function;
 
        impure function rnd_addr return std_logic_vector is
        begin
            if rnd(10) = 0 then
                return std_logic_vector(to_unsigned(rnd(DEPTH + 64) + DEPTH, 30)) & "00";
            else
                return std_logic_vector(to_unsigned(rnd(DEPTH), 30)) & std_logic_vector(to_unsigned(rnd(4), 2));
            end if;
        end function;
 
        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "@" & time'image(now) & ": " & msg severity error;
            end if;
        end procedure;
 
        procedure expect_ports(tag : string) is
            variable eb, ea : std_logic_vector(31 downto 0);
        begin
            if in_range(addr) then eb := model(idx(addr)); else eb := (others => '0'); end if;
            if in_range(addr_a) then ea := model(idx(addr_a)); else ea := (others => '0'); end if;
            checks := checks + 2;
            if rd /= eb then
                fail(tag & ": rd addr=0x" & to_hstring(addr) & " got=0x" & to_hstring(rd) & " expected=0x" & to_hstring(eb));
            end if;
            if rd_a /= ea then
                fail(tag & ": rd_a addr_a=0x" & to_hstring(addr_a) & " got=0x" & to_hstring(rd_a) & " expected=0x" & to_hstring(ea));
            end if;
        end procedure;
 
        procedure op(ab, aa, d : std_logic_vector(31 downto 0); mv : std_logic_vector(3 downto 0);
                     ev : std_logic; tag : string) is
        begin
            wait until falling_edge(clk);
            addr   <= ab;
            addr_a <= aa;
            wd     <= d;
            be     <= mv;
            we     <= ev;
            wait for 1 ns;
            expect_ports(tag & " before edge");
            wait until rising_edge(clk);
            wait for 1 ns;
            if ev = '1' and in_range(ab) then
                model(idx(ab)) := merge(model(idx(ab)), d, mv);
            end if;
            expect_ports(tag & " after edge");
            we <= '0';
        end procedure;
 
        procedure sweep(tag : string) is
        begin
            we <= '0';
            for i in 0 to DEPTH - 1 loop
                addr   <= std_logic_vector(to_unsigned(4 * i, 32));
                addr_a <= std_logic_vector(to_unsigned(4 * (DEPTH - 1 - i), 32));
                wait for 1 ns;
                expect_ports(tag);
            end loop;
        end procedure;
    begin
        wait for 1 ns;
        sweep("initial contents");
        for i in 0 to DEPTH - 1 loop
            for lo in 0 to 3 loop
                addr   <= std_logic_vector(to_unsigned(4 * i + lo, 32));
                addr_a <= std_logic_vector(to_unsigned(4 * i + lo, 32));
                wait for 1 ns;
                expect_ports("same address both ports");
            end loop;
        end loop;
 
        for i in 0 to DEPTH - 1 loop
            op(std_logic_vector(to_unsigned(4 * i, 32)), std_logic_vector(to_unsigned(4 * i, 32)),
               std_logic_vector(to_unsigned(i, 8)) & x"C35A" & std_logic_vector(to_unsigned(255 - i, 8)), "1111", '1',
               "fill, port A same address");
        end loop;
        sweep("after fill");
 
        for k in 0 to 15 loop
            a := std_logic_vector(to_unsigned(4 * (k mod DEPTH), 32));
            op(a, a, x"8040_20FF", "1111", '1', "mask base");
            op(a, a, x"ABCD_EF12", std_logic_vector(to_unsigned(k, 4)), '1', "mask " & integer'image(k));
        end loop;
 
        a := x"00000008";
        for k in 0 to 15 loop
            op(a, a, rnd_word, std_logic_vector(to_unsigned(k, 4)), '0', "we=0 mask " & integer'image(k));
        end loop;
 
        op(x"00000004", x"00000000", x"8040_20FF", "1111", '1', "port A other address");
        op(x"00000004", x"00000004", x"AAAA_AAAA", "0010", '1', "sb lane1, port A sees it");
        op(x"0000000D", x"0000000C", x"CAFE_BABE", "1111", '1', "low address bits ignored");
 
        op(std_logic_vector(to_unsigned(4 * DEPTH, 32)), x"00000000", x"DEADBEEF", "1111", '1', "write at DEPTH");
        op(std_logic_vector(to_unsigned(8 * DEPTH, 32)), x"00000000", x"DEADBEEF", "1111", '1', "write 2*DEPTH alias");
        op(x"80000000", x"80000000", x"DEADBEEF", "1111", '1', "write 0x80000000");
        op(x"FFFFFFFC", std_logic_vector(to_unsigned(4 * DEPTH, 32)), x"DEADBEEF", "1111", '1', "write 0xFFFFFFFC");
        op(x"00000000", x"FFFFFFFC", x"00000000", "0000", '0', "port A out of range");
        sweep("no aliasing");
 
        for n in 1 to N_RANDOM loop
            a := rnd_addr;
            if rnd(3) = 0 then
                b := a;
            else
                b := rnd_addr;
            end if;
            m := std_logic_vector(to_unsigned(rnd(16), 4));
            if rnd(4) = 0 then e := '0'; else e := '1'; end if;
            op(a, b, rnd_word, m, e, "random");
            if n mod 1000 = 0 then
                sweep("random sweep");
            end if;
        end loop;
        sweep("final");
 
        report "tb_ram: " & integer'image(checks) & " checks, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_ram FAILED" severity failure;
        report "tb_ram PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;
 