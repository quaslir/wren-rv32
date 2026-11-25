library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb_cpu_prog is
    generic(
        PROG          : string   := "sw/main.hex";
        EXPECTED      : integer  := 6765;
        MEM_DEPTH     : positive := 64;
        MAX_CYCLES    : positive := 400000;
        ALLOW_ILLEGAL : boolean  := false
    );
end entity tb_cpu_prog;
architecture sim of tb_cpu_prog is
    constant T          : time := 10 ns;
    constant HALT_BEQ   : std_logic_vector(31 downto 0) := x"00000063";
    constant HALT_JAL   : std_logic_vector(31 downto 0) := x"0000006F";
    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal result : std_logic_vector(31 downto 0);
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
            irq    => '0',
            result => result
        );
    stim : process
        alias pc      is <<signal dut.pc      : std_logic_vector(31 downto 0)>>;
        alias instr   is <<signal dut.instr   : std_logic_vector(31 downto 0)>>;
        alias illegal is <<signal dut.illegal : std_logic>>;
        variable cycles  : natural := 0;
        variable n_ill   : natural := 0;
        variable last    : std_logic_vector(31 downto 0) := (others => '0');
        variable have    : boolean := false;
        variable halted  : boolean := false;
        variable got     : integer;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';
        wait for 1 ns;
        while cycles < MAX_CYCLES loop
            if instr = HALT_BEQ or instr = HALT_JAL then
                halted := true;
                exit;
            end if;
            if is_x(instr) then
                report "undefined instruction at pc=0x" & to_hstring(pc) & " after " & integer'image(cycles) & " cycles"
                    severity failure;
            end if;
            if illegal = '1' then
                n_ill := n_ill + 1;
                if not ALLOW_ILLEGAL then
                    report "illegal instruction 0x" & to_hstring(instr) & " at pc=0x" & to_hstring(pc) &
                           " after " & integer'image(cycles) & " cycles" severity failure;
                end if;
            end if;
            last := result;
            have := true;
            cycles := cycles + 1;
            wait until falling_edge(clk);
            wait for 1 ns;
        end loop;
        if not halted then
            report PROG & ": no halt after " & integer'image(MAX_CYCLES) & " cycles, pc=0x" & to_hstring(pc)
                severity failure;
        end if;
        if not have then
            report PROG & ": halt reached before any instruction executed" severity failure;
        end if;
        got := to_integer(signed(last));
        report PROG & ": halt at pc=0x" & to_hstring(pc) & " after " & integer'image(cycles) & " cycles, result=" &
               integer'image(got) & " (0x" & to_hstring(last) & "), expected=" & integer'image(EXPECTED);
        assert got = EXPECTED
            report PROG & ": FAILED, result " & integer'image(got) & " /= expected " & integer'image(EXPECTED)
            severity failure;
        report PROG & ": PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;