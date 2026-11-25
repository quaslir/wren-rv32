library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_cpu_irq is
    generic(
        PROG       : string   := "build/irq/irq.hex";
        EXPECTED   : integer  := 0;
        MEM_DEPTH  : positive := 1024;
        MAX_CYCLES : positive := 2000000;
        MIN_GAP    : positive := 300;
        MAX_GAP    : positive := 1500;
        N_SW       : natural  := 10;
        SEED       : positive := 1
    );
end entity tb_cpu_irq;

architecture sim of tb_cpu_irq is
    constant T        : time := 10 ns;
    constant HALT_BEQ : std_logic_vector(31 downto 0) := x"00000063";

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal btn    : std_logic := '0';
    signal sw_in  : std_logic_vector(9 downto 0) := (others => '0');
    signal result : std_logic_vector(31 downto 0);
    signal led    : std_logic_vector(9 downto 0);
    signal hex    : std_logic_vector(23 downto 0);
    signal done   : boolean := false;
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
            btn    => btn,
            sw_in  => sw_in,
            result => result,
            led    => led,
            hex    => hex
        );

    stim : process
        alias pc       is <<signal dut.pc : std_logic_vector(31 downto 0)>>;
        alias instr    is <<signal dut.instr : std_logic_vector(31 downto 0)>>;
        alias illegal  is <<signal dut.illegal : std_logic>>;
        alias take_irq is <<signal dut.CORE.datapath_inst.csr_inst.take_irq : std_logic>>;
        variable s1      : positive := SEED;
        variable s2      : positive := SEED * 7 + 3;
        variable r       : real;
        variable cycles  : natural := 0;
        variable pulses  : natural := 0;
        variable traps   : natural := 0;
        variable gap     : natural := 0;
        variable hold    : natural := 0;
        variable last    : std_logic_vector(31 downto 0) := (others => '0');
        variable halted  : boolean := false;
        variable stopped : boolean := false;
        variable started : boolean := false;
        variable got     : integer;
        variable errors  : natural := 0;
        variable first_pulse_cycle : natural := 0;

        impure function rnd(lo, hi : natural) return natural is
        begin
            uniform(s1, s2, r);
            return lo + integer(floor(r * real(hi - lo + 1))) mod (hi - lo + 1);
        end function;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';
        wait for 1 ns;
        gap := rnd(1, MIN_GAP);
        while cycles < MAX_CYCLES loop
            if instr = HALT_BEQ then
                halted := true;
                exit;
            end if;
            if is_x(instr) then
                report "undefined instruction at pc=0x" & to_hstring(pc) severity failure;
            end if;
            if illegal = '1' then
                report "illegal instruction 0x" & to_hstring(instr) & " at pc=0x" & to_hstring(pc) severity failure;
            end if;
            if take_irq = '1' then
                traps := traps + 1;
            end if;

            if not started and led(1) = '1' and led(0) = '0' then
                started := true;
            end if;
            if started and not stopped and led(0) = '1' then
                stopped := true;
                btn <= '0';
                hold := 0;
                sw_in <= std_logic_vector(to_unsigned(pulses, 10));
            end if;
            if started and not stopped then
                if hold > 0 then
                    hold := hold - 1;
                    if hold = 0 then
                        btn <= '0';
                    end if;
                elsif gap > 0 then
                    gap := gap - 1;
                else
                    btn <= '1';
                    pulses := pulses + 1;
                    if pulses = 1 then first_pulse_cycle := cycles; end if;
                    hold := rnd(1, 40);
                    gap := rnd(MIN_GAP, MAX_GAP);
                end if;
            end if;

            last := result;
            cycles := cycles + 1;
            wait until falling_edge(clk);
            wait for 1 ns;
        end loop;

        if not halted then
            report PROG & ": no halt after " & integer'image(MAX_CYCLES) & " cycles, pc=0x" & to_hstring(pc) severity failure;
        end if;
        if not started or not stopped then
            report "program did not signal phases on LED (started=" & boolean'image(started) & ", stopped=" &
                   boolean'image(stopped) & ")" severity error;
            errors := errors + 1;
        end if;
        if pulses > 1023 then
            report "too many pulses for 10-bit SW: " & integer'image(pulses) severity error;
            errors := errors + 1;
        end if;
        if pulses = 0 then
            report "no button pulses were generated" severity error;
            errors := errors + 1;
        end if;
        if traps /= pulses + N_SW then
            report "traps=" & integer'image(traps) & " but pulses+N_SW=" & integer'image(pulses + N_SW) severity error;
            errors := errors + 1;
        end if;
        got := to_integer(signed(last));
        report PROG & " seed " & integer'image(SEED) & ": " & integer'image(cycles) & " cycles, " & integer'image(pulses) &
               " button presses, " & integer'image(traps) & " traps, result=" & integer'image(got) & " (0x" &
               to_hstring(last) & "), expected=" & integer'image(EXPECTED);
        if got /= EXPECTED then
            report "result mismatch" severity error;
            errors := errors + 1;
        end if;
        assert errors = 0 report "tb_cpu_irq FAILED" severity failure;
        report "tb_cpu_irq PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;