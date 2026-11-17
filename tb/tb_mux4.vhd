library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mux4 is
end entity tb_mux4;

architecture sim of tb_mux4 is
    signal d0, d1, d2, d3, y : std_logic_vector(31 downto 0) := (others => '0');
    signal sel : std_logic_vector(1 downto 0) := "00";
    signal n0, n1, n2, n3, ny : std_logic_vector(3 downto 0) := (others => '0');
begin
    dut32 : entity work.mux4
        generic map(
            WIDTH => 32
        )
        port map(
            d0  => d0,
            d1  => d1,
            d2  => d2,
            d3  => d3,
            sel => sel,
            y   => y
        );

    dut4 : entity work.mux4
        generic map(
            WIDTH => 4
        )
        port map(
            d0  => n0,
            d1  => n1,
            d2  => n2,
            d3  => n3,
            sel => sel,
            y   => ny
        );

    stim : process
        variable err : natural := 0;
        variable cnt : natural := 0;
        variable exp : std_logic_vector(3 downto 0);
    begin
        d0 <= x"11111111";
        d1 <= x"22222222";
        d2 <= x"33333333";
        d3 <= x"44444444";
        for s in 0 to 3 loop
            sel <= std_logic_vector(to_unsigned(s, 2));
            wait for 1 ns;
            cnt := cnt + 1;
            case s is
                when 0 => if y /= x"11111111" then err := err + 1; report "FAIL sel=00 y=0x" & to_hstring(y) severity error; end if;
                when 1 => if y /= x"22222222" then err := err + 1; report "FAIL sel=01 y=0x" & to_hstring(y) severity error; end if;
                when 2 => if y /= x"33333333" then err := err + 1; report "FAIL sel=10 y=0x" & to_hstring(y) severity error; end if;
                when others => if y /= x"44444444" then err := err + 1; report "FAIL sel=11 y=0x" & to_hstring(y) severity error; end if;
            end case;
        end loop;

        for a in 0 to 15 loop
            for b in 0 to 15 loop
                for s in 0 to 3 loop
                    n0  <= std_logic_vector(to_unsigned(a, 4));
                    n1  <= std_logic_vector(to_unsigned(b, 4));
                    n2  <= std_logic_vector(to_unsigned(15 - a, 4));
                    n3  <= std_logic_vector(to_unsigned(15 - b, 4));
                    sel <= std_logic_vector(to_unsigned(s, 2));
                    wait for 1 ns;
                    cnt := cnt + 1;
                    case s is
                        when 0      => exp := std_logic_vector(to_unsigned(a, 4));
                        when 1      => exp := std_logic_vector(to_unsigned(b, 4));
                        when 2      => exp := std_logic_vector(to_unsigned(15 - a, 4));
                        when others => exp := std_logic_vector(to_unsigned(15 - b, 4));
                    end case;
                    if ny /= exp then
                        err := err + 1;
                        report "FAIL 4-bit sel=" & integer'image(s) & " y=" & to_string(ny) & " expected=" & to_string(exp) severity error;
                    end if;
                end loop;
            end loop;
        end loop;

        if err = 0 then
            report "tb_mux4: ALL " & integer'image(cnt) & " TESTS PASSED" severity note;
        else
            report "tb_mux4: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        std.env.finish;
    end process;
end architecture sim;