library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb_cpu_prog is
    generic(
        PROG          : string   := "sw/main.hex";
        EXPECTED      : integer  := 6765;
        MEM_DEPTH     : positive := 64;
        MAX_CYCLES    : positive := 400000;
        ALLOW_ILLEGAL : boolean  := false;
        HALT_REPEATS  : positive := 3;
        DRAIN         : natural  := 6
    );
end entity tb_cpu_prog;
architecture sim of tb_cpu_prog is
    constant T        : time := 10 ns;
    constant HALT_BEQ : std_logic_vector(31 downto 0) := x"00000063";
    constant HALT_JAL : std_logic_vector(31 downto 0) := x"0000006F";
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
            btn    => '0',
            result => result
        );
    stim : process
        alias pc        is <<signal dut.pc      : std_logic_vector(31 downto 0)>>;
        alias instr     is <<signal dut.instr   : std_logic_vector(31 downto 0)>>;
        alias illegal   is <<signal dut.illegal : std_logic>>;
        alias reg_write is <<signal dut.CORE.datapath_inst.reg_write : std_logic>>;
        alias rd_w      is <<signal dut.CORE.datapath_inst.rd_w      : std_logic_vector(4 downto 0)>>;
        alias result_w  is <<signal dut.CORE.datapath_inst.result_w  : std_logic_vector(31 downto 0)>>;
        variable cycles  : natural := 0;
        variable n_ill   : natural := 0;
        variable n_spec  : natural := 0;
        variable n_wr    : natural := 0;
        variable last    : std_logic_vector(31 downto 0) := (others => '0');
        variable last_rd : natural := 0;
        variable have    : boolean := false;
        variable halted  : boolean := false;
        variable halt_pc : unsigned(31 downto 0) := (others => '0');
        variable prev_pc : std_logic_vector(31 downto 0) := (others => '1');
        variable n_halt  : natural := 0;
        variable got     : integer;

        procedure sample is
        begin
            if reg_write = '1' and rd_w /= "00000" then
                last := result_w;
                last_rd := to_integer(unsigned(rd_w));
                have := true;
                n_wr := n_wr + 1;
            end if;
        end procedure;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';
        wait for 1 ns;
        while cycles < MAX_CYCLES loop
            if is_x(pc) or is_x(instr) then
                report "undefined pc/instruction: pc=0x" & to_hstring(pc) & " instr=0x" & to_hstring(instr)
                    & " after " & integer'image(cycles) & " cycles" severity failure;
            end if;
            if n_halt > 0 and (unsigned(pc) < halt_pc or unsigned(pc) > halt_pc + 8) then
                n_spec := n_spec + 1;
                n_halt := 0;
            end if;
            if (instr = HALT_BEQ or instr = HALT_JAL) and pc /= prev_pc then
                if n_halt > 0 and unsigned(pc) = halt_pc then
                    n_halt := n_halt + 1;
                else
                    halt_pc := unsigned(pc);
                    n_halt := 1;
                end if;
            end if;
            if illegal = '1' then
                n_ill := n_ill + 1;
                if not ALLOW_ILLEGAL then
                    report "illegal instruction in EX, fetch pc=0x" & to_hstring(pc) & " after " & integer'image(cycles)
                        & " cycles" severity failure;
                end if;
            end if;
            sample;
            prev_pc := pc;
            cycles := cycles + 1;
            if n_halt >= HALT_REPEATS then
                halted := true;
                exit;
            end if;
            wait until falling_edge(clk);
            wait for 1 ns;
        end loop;
        if not halted then
            report PROG & ": no halt after " & integer'image(MAX_CYCLES) & " cycles, pc=0x" & to_hstring(pc)
                severity failure;
        end if;
        for i in 1 to DRAIN loop
            wait until falling_edge(clk);
            wait for 1 ns;
            sample;
        end loop;
        if not have then
            report PROG & ": halt reached before any register write" severity failure;
        end if;
        got := to_integer(signed(last));
        report PROG & ": halt at pc=0x" & to_hstring(halt_pc) & " after " & integer'image(cycles) & " cycles ("
            & integer'image(n_spec) & " speculative halt fetches, " & integer'image(n_wr) & " register writes), result=x"
            & integer'image(last_rd) & "=" & integer'image(got) & " (0x" & to_hstring(last) & "), expected="
            & integer'image(EXPECTED);
        assert got = EXPECTED
            report PROG & ": FAILED, result " & integer'image(got) & " /= expected " & integer'image(EXPECTED)
            severity failure;
        report PROG & ": PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;