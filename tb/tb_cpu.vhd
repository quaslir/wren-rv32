library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cpu_prog is
    generic(
        PROG       : string := "sw/magic.hex";
        EXPECTED   : integer := 6765;
        MAX_CYCLES : natural := 1000
    );
end entity tb_cpu_prog;

architecture sim of tb_cpu_prog is
    constant CLK_PERIOD : time := 10 ns;

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal result : std_logic_vector(31 downto 0);
    signal done   : boolean := false;
begin
    dut : entity work.cpu
        generic map(
            INIT_FILE => PROG
        )
        port map(
            clk    => clk,
            rst    => rst,
            result => result
        );

    clk <= not clk after CLK_PERIOD / 2 when not done;

    stim : process
        alias pc is <<signal .tb_cpu_prog.dut.pc : std_logic_vector(31 downto 0)>>;
        variable err         : natural := 0;
        variable cycles      : natural := 0;
        variable prev_pc     : std_logic_vector(31 downto 0);
        variable prev_result : std_logic_vector(31 downto 0);
        variable last_result : std_logic_vector(31 downto 0);
        variable halted      : boolean := false;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        if pc /= x"00000000" then
            report "FAIL pc after reset = 0x" & to_hstring(pc) severity error;
            err := err + 1;
        end if;

        prev_pc     := pc;
        prev_result := result;
        last_result := result;

        while cycles < MAX_CYCLES loop
            wait until falling_edge(clk);
            cycles := cycles + 1;
            if pc = prev_pc then
                halted := true;
                exit;
            end if;
            last_result := prev_result;
            prev_pc     := pc;
            prev_result := result;
        end loop;

        if not halted then
            report "FAIL no halt within " & integer'image(MAX_CYCLES) & " cycles, pc=0x" & to_hstring(pc) severity error;
            err := err + 1;
        else
            report "halt at pc=0x" & to_hstring(pc) & " after " & integer'image(cycles) & " cycles" severity note;
            report "result before halt = 0x" & to_hstring(last_result) & " (" & integer'image(to_integer(unsigned(last_result))) & ")" severity note;
            if unsigned(last_result) /= to_unsigned(EXPECTED, 32) then
                report "FAIL expected " & integer'image(EXPECTED) & " = 0x" & to_hstring(to_unsigned(EXPECTED, 32)) severity error;
                err := err + 1;
            end if;
        end if;

        if err = 0 then
            report "tb_cpu_prog: PASSED (" & PROG & ")" severity note;
        else
            report "tb_cpu_prog: " & integer'image(err) & " FAILURES (" & PROG & ")" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;