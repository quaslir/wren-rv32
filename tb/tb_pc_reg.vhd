library ieee;
use ieee.std_logic_1164.all;

entity tb_pc_reg is
end entity tb_pc_reg;

architecture sim of tb_pc_reg is
    constant T : time := 10 ns;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal next_pc : std_logic_vector(31 downto 0) := (others => '0');
    signal pc      : std_logic_vector(31 downto 0);
    signal done    : boolean := false;
begin

    dut : entity work.pc_reg
        port map (
            clk     => clk,
            rst     => rst,
            next_pc => next_pc,
            pc      => pc
        );

    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for T / 2;
            clk <= '1'; wait for T / 2;
        end loop;
        wait;
    end process;

    stim : process
        variable errors : natural := 0;

        procedure check (expected : std_logic_vector(31 downto 0);
                         msg      : string) is
        begin
            if pc /= expected then
                errors := errors + 1;
                report msg & ": expected " & to_hstring(expected) &
                       ", got " & to_hstring(pc) severity error;
            end if;
        end procedure;

        procedure step (rst_val  : std_logic;
                        next_val : std_logic_vector(31 downto 0);
                        expected : std_logic_vector(31 downto 0);
                        msg      : string) is
        begin
            wait until falling_edge(clk);
            rst     <= rst_val;
            next_pc <= next_val;
            wait until rising_edge(clk);
            wait for 1 ns;
            check(expected, msg);
        end procedure;

    begin
        step('1', x"00000000", x"00000000", "reset");
        step('1', x"00000040", x"00000000", "reset ignores next_pc");

        step('0', x"00000004", x"00000004", "load 4");

        wait until falling_edge(clk);
        next_pc <= x"00000008";
        wait for 1 ns;
        check(x"00000004", "hold: next_pc changed, pc must wait for edge");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(x"00000008", "load 8 on edge");

        step('0', x"0000000C", x"0000000C", "load 12");
        step('0', x"12345678", x"12345678", "load arbitrary value");
        step('0', x"FFFFFFFC", x"FFFFFFFC", "load max aligned address");

        wait until falling_edge(clk);
        rst <= '1';
        wait for 1 ns;
        check(x"FFFFFFFC", "sync reset: pc must wait for edge");

        step('1', x"00000010", x"00000000", "reset in the middle");
        step('0', x"00000010", x"00000010", "run after reset");

        report "Test finished, errors: " & integer'image(errors);
        done <= true;
        std.env.finish;
    end process;

end architecture sim;