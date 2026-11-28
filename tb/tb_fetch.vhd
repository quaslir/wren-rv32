library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fetch is
end entity tb_fetch;

architecture sim of tb_fetch is
    constant T : time := 10 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal en       : std_logic := '1';
    signal pc       : std_logic_vector(31 downto 0);
    signal pc_plus4 : std_logic_vector(31 downto 0);
    signal done     : boolean := false;
begin
    u_pc : entity work.pc_reg
        port map (
            clk     => clk,
            rst     => rst,
            en      => en,
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
        variable expected : unsigned(31 downto 0) := (others => '0');

        procedure tick(e : std_logic; tag : string) is
        begin
            en <= e;
            wait until rising_edge(clk);
            wait for 1 ns;
            if e = '1' then
                expected := expected + 4;
            end if;
            if pc /= std_logic_vector(expected) then
                errors := errors + 1;
                report tag & ": expected " & to_hstring(expected) & ", got " & to_hstring(pc) severity error;
            end if;
        end procedure;
    begin
        rst <= '1';
        en <= '1';
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
            tick('1', "cycle " & integer'image(i));
        end loop;
        tick('0', "stall 1");
        tick('0', "stall 2");
        tick('1', "after stall");
        for i in 1 to 20 loop
            if i mod 3 = 0 then
                tick('0', "mixed stall " & integer'image(i));
            else
                tick('1', "mixed run " & integer'image(i));
            end if;
        end loop;

        wait until falling_edge(clk);
        rst <= '1';
        en <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        if pc /= x"00000000" then
            errors := errors + 1;
            report "reset with en=0: expected 00000000, got " & to_hstring(pc) severity error;
        end if;

        assert errors = 0 report "tb_fetch FAILED (" & integer'image(errors) & " errors)" severity failure;
        report "tb_fetch PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;