library ieee;
use ieee.std_logic_1164.all;

entity tb_calculator is
end entity tb_calculator;

architecture sim of tb_calculator is
    constant T : time := 10 ns;

    signal clk    : std_logic := '0';
    signal instr  : std_logic_vector(31 downto 0) := (others => '0');
    signal result : std_logic_vector(31 downto 0);
    signal done   : boolean := false;
begin

    dut : entity work.calculator
        port map (
            clk    => clk,
            instr  => instr,
            result => result
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

        procedure step (ins, exp : std_logic_vector(31 downto 0);
                        msg      : string) is
        begin
            wait until falling_edge(clk);
            instr <= ins;
            wait for 1 ns;
            if result /= exp then
                errors := errors + 1;
                report msg & " (" & to_hstring(ins) & "): expected " &
                       to_hstring(exp) & ", got " & to_hstring(result) severity error;
            else
                report msg & ": OK";
            end if;
        end procedure;

    begin
        step(x"00500093", x"00000005", "addi x1, x0, 5");
        step(x"00300113", x"00000003", "addi x2, x0, 3");
        step(x"002081B3", x"00000008", "add  x3, x1, x2");
        step(x"40208233", x"00000002", "sub  x4, x1, x2");
        step(x"0020F2B3", x"00000001", "and  x5, x1, x2");
        step(x"0020E333", x"00000007", "or   x6, x1, x2");
        step(x"FFF00393", x"FFFFFFFF", "addi x7, x0, -1");
        step(x"00138433", x"00000004", "add  x8, x7, x1");
        step(x"00500013", x"00000005", "addi x0, x0, 5");
        step(x"000004B3", x"00000000", "add  x9, x0, x0");
        step(x"00018533", x"00000008", "add  x10, x3, x0");
        step(x"000365B3", x"00000007", "or   x11, x6, x0");
        step(x"40100633", x"FFFFFFFB", "sub  x12, x0, x1");

        report "Test finished, errors: " & integer'image(errors);
        done <= true;
        wait;
    end process;

end architecture sim;