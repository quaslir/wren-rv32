library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fetch is
end entity tb_fetch;

architecture sim of tb_fetch is
    constant T : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal pc       : std_logic_vector(31 downto 0);
    signal pc_plus4 : std_logic_vector(31 downto 0);
    signal done     : boolean := false;
begin

    u_pc : entity work.pc_reg
        port map (
            clk     => clk,
            rst     => rst,
            next_pc => pc_plus4,
            pc      => pc
        );

    u_add : entity work.adder
        generic map (WIDTH => 32)
        port map (
            a => pc,
            b => x"00000004",
            y => pc_plus4
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
        variable errors   : natural := 0;
        variable expected : std_logic_vector(31 downto 0);
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        if pc /= x"00000000" then
            errors := errors + 1;
            report "after reset: expected 00000000, got " & to_hstring(pc) severity error;
        end if;

        wait until falling_edge(clk);
        rst <= '0';

        for i in 1 to 10 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            expected := std_logic_vector(to_unsigned(i * 4, 32));
            if pc /= expected then
                errors := errors + 1;
                report "cycle " & integer'image(i) & ": expected " & to_hstring(expected) &
                       ", got " & to_hstring(pc) severity error;
            end if;
        end loop;

        wait until falling_edge(clk);
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        if pc /= x"00000000" then
            errors := errors + 1;
            report "reset in the middle: expected 00000000, got " & to_hstring(pc) severity error;
        end if;

        report "Test finished, errors: " & integer'image(errors);
        done <= true;
        wait;
    end process;

end architecture sim;