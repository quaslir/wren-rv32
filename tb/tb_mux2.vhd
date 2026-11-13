library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mux2 is
end entity tb_mux2;

architecture sim of tb_mux2 is
    signal d0_32, d1_32, y_32 : std_logic_vector(31 downto 0);
    signal sel_32             : std_logic;

    signal d0_4, d1_4, y_4 : std_logic_vector(3 downto 0);
    signal sel_4           : std_logic;
begin

    dut32 : entity work.mux2
        generic map (WIDTH => 32)
        port map (d0 => d0_32, d1 => d1_32, sel => sel_32, y => y_32);

    dut4 : entity work.mux2
        generic map (WIDTH => 4)
        port map (d0 => d0_4, d1 => d1_4, sel => sel_4, y => y_4);

    stim : process
        variable errors   : natural := 0;
        variable expected : std_logic_vector(3 downto 0);
    begin
        d0_32 <= x"AAAAAAAA";
        d1_32 <= x"55555555";

        sel_32 <= '0';
        wait for 10 ns;
        if y_32 /= x"AAAAAAAA" then
            errors := errors + 1;
            report "32-bit sel=0: got " & to_hstring(y_32) severity error;
        end if;

        sel_32 <= '1';
        wait for 10 ns;
        if y_32 /= x"55555555" then
            errors := errors + 1;
            report "32-bit sel=1: got " & to_hstring(y_32) severity error;
        end if;

        for i in 0 to 15 loop
            for j in 0 to 15 loop
                for s in 0 to 1 loop
                    d0_4 <= std_logic_vector(to_unsigned(i, 4));
                    d1_4 <= std_logic_vector(to_unsigned(j, 4));
                    if s = 0 then
                        sel_4 <= '0';
                    else
                        sel_4 <= '1';
                    end if;

                    wait for 10 ns;

                    if s = 0 then
                        expected := std_logic_vector(to_unsigned(i, 4));
                    else
                        expected := std_logic_vector(to_unsigned(j, 4));
                    end if;

                    if y_4 /= expected then
                        errors := errors + 1;
                        report "4-bit d0=" & integer'image(i) &
                               " d1=" & integer'image(j) &
                               " sel=" & integer'image(s) &
                               " expected " & to_string(expected) &
                               " got " & to_string(y_4) severity error;
                    end if;
                end loop;
            end loop;
        end loop;

        report "Test finished, errors: " & integer'image(errors);
        wait;
    end process;

end architecture sim;