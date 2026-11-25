library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
 
entity tb_cpu_io is
    generic(
        PROG       : string   := "build/io/io.hex";
        MEM_DEPTH  : positive := 1024;
        MAX_WAIT   : positive := 4000;
        N_RANDOM   : natural  := 40
    );
end entity tb_cpu_io;
 
architecture sim of tb_cpu_io is
    constant T : time := 10 ns;
 
    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal sw_in  : std_logic_vector(9 downto 0) := (others => '0');
    signal result : std_logic_vector(31 downto 0);
    signal led    : std_logic_vector(9 downto 0);
    signal hex    : std_logic_vector(23 downto 0);
    signal done   : boolean := false;
 
    function fib(n : natural) return unsigned is
        variable a, b, tt : unsigned(31 downto 0);
    begin
        a := (others => '0');
        b := to_unsigned(1, 32);
        for i in 1 to n loop
            tt := a + b;
            a := b;
            b := tt;
        end loop;
        return a;
    end function;
 
    function exp_led(s : std_logic_vector(9 downto 0)) return std_logic_vector is
    begin
        return '1' & s(8 downto 0);
    end function;
 
    function exp_hex(s : std_logic_vector(9 downto 0)) return std_logic_vector is
        variable n : natural := to_integer(unsigned(s(4 downto 0)));
        variable f : unsigned(31 downto 0) := fib(n);
    begin
        return std_logic_vector(to_unsigned(n, 8)) & std_logic_vector(f(15 downto 0));
    end function;
begin
    clk <= not clk after T / 2 when not done else '0';
 
    dut : entity work.cpu
        generic map(
            INIT_FILE => PROG,
            MEM_DEPTH => MEM_DEPTH
        )
        port map(
            clk    => clk,
            rst    => rst,
            irq    => '0',
            sw_in  => sw_in,
            result => result,
            led    => led,
            hex    => hex
        );
 
    stim : process
        alias pc      is <<signal dut.pc      : std_logic_vector(31 downto 0)>>;
        alias instr   is <<signal dut.instr   : std_logic_vector(31 downto 0)>>;
        alias illegal is <<signal dut.illegal : std_logic>>;
        variable errors  : natural := 0;
        variable checks  : natural := 0;
        variable cycles  : natural := 0;
        variable waited  : natural;
        variable worst   : natural := 0;
        variable s1      : positive := 33;
        variable s2      : positive := 44;
        variable r       : real;
        variable sv      : std_logic_vector(9 downto 0);
 
        procedure tick is
        begin
            wait until falling_edge(clk);
            wait for 1 ns;
            cycles := cycles + 1;
            if illegal = '1' then
                report "illegal instruction 0x" & to_hstring(instr) & " at pc=0x" & to_hstring(pc) severity failure;
            end if;
            if is_x(instr) then
                report "undefined instruction at pc=0x" & to_hstring(pc) severity failure;
            end if;
        end procedure;
 
        procedure apply(v : std_logic_vector(9 downto 0); tag : string) is
            variable el : std_logic_vector(9 downto 0);
            variable eh : std_logic_vector(23 downto 0);
            variable ok : boolean := false;
        begin
            sw_in <= v;
            el := exp_led(v);
            eh := exp_hex(v);
            waited := 0;
            while waited < MAX_WAIT loop
                tick;
                waited := waited + 1;
                if led = el and hex = eh then
                    ok := true;
                    exit;
                end if;
            end loop;
            checks := checks + 1;
            if not ok then
                errors := errors + 1;
                report tag & ": sw=" & to_string(v) & " after " & integer'image(MAX_WAIT) & " cycles led=" & to_string(led) &
                       " expected=" & to_string(el) & ", hex=0x" & to_hstring(hex) & " expected=0x" & to_hstring(eh)
                    severity error;
                return;
            end if;
            if waited > worst then
                worst := waited;
            end if;
            for k in 1 to 200 loop
                tick;
                checks := checks + 1;
                if led /= el or hex /= eh then
                    errors := errors + 1;
                    report tag & ": output not stable for sw=" & to_string(v) & " led=" & to_string(led) &
                           " hex=0x" & to_hstring(hex) severity error;
                    return;
                end if;
            end loop;
        end procedure;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        checks := checks + 1;
        if led /= "0000000000" or hex /= x"000000" then
            errors := errors + 1;
            report "outputs not zero during reset: led=" & to_string(led) & " hex=0x" & to_hstring(hex) severity error;
        end if;
        rst <= '0';
 
        apply("0000000000", "n=0");
        apply("0000000001", "n=1");
        apply("0000000010", "n=2");
        apply("0000001010", "n=10");
        apply("0000011111", "n=31");
        apply("1111111111", "all on");
        apply("1000000000", "sw9 only");
        apply("0101010101", "pattern 1");
        apply("1010101010", "pattern 2");
        for i in 0 to 9 loop
            sv := (others => '0');
            sv(i) := '1';
            apply(sv, "walking one sw" & integer'image(i));
        end loop;
        for n in 1 to N_RANDOM loop
            uniform(s1, s2, r);
            sv := std_logic_vector(to_unsigned(integer(trunc(r * 1024.0)) mod 1024, 10));
            apply(sv, "random");
        end loop;
 
        report "tb_cpu_io: " & integer'image(checks) & " checks, " & integer'image(cycles) & " cycles, worst response " &
               integer'image(worst) & " cycles, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_cpu_io FAILED" severity failure;
        report "tb_cpu_io PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;