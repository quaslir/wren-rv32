library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_instr_mem is
end entity tb_instr_mem;

architecture sim of tb_instr_mem is
    signal addr  : std_logic_vector(31 downto 0) := (others => '0');
    signal instr : std_logic_vector(31 downto 0);
begin
    dut : entity work.instr_mem
        generic map(
            INIT_FILE => "sw/test.hex",
            DEPTH     => 64
        )
        port map(
            addr  => addr,
            instr => instr
        );

    stim : process
        variable err : natural := 0;

        procedure check(a : std_logic_vector(31 downto 0); expected : std_logic_vector(31 downto 0)) is
        begin
            addr <= a;
            wait for 10 ns;
            if instr /= expected then
                report "FAIL addr=0x" & to_hstring(a) & " got=0x" & to_hstring(instr) & " expected=0x" & to_hstring(expected) severity error;
                err := err + 1;
            end if;
        end procedure;
    begin
        check(x"00000000", x"00500093");
        check(x"00000004", x"00300113");
        check(x"00000008", x"002081B3");
        check(x"0000000C", x"00000000");
        check(x"00000010", x"00000000");

        check(x"00000005", x"00300113");
        check(x"00000006", x"00300113");
        check(x"00000007", x"00300113");
        check(x"00000001", x"00500093");
        check(x"0000000B", x"002081B3");

        check(x"000000FC", x"00000000");
        check(x"00000100", x"00000000");
        check(x"00000104", x"00000000");
        check(x"7FFFFFFC", x"00000000");
        check(x"80000000", x"00000000");
        check(x"FFFFFFFC", x"00000000");

        check(x"00000000", x"00500093");
        check(x"00000008", x"002081B3");
        check(x"00000004", x"00300113");

        for i in 3 to 63 loop
            check(std_logic_vector(to_unsigned(i * 4, 32)), x"00000000");
        end loop;

        if err = 0 then
            report "tb_instr_mem: ALL TESTS PASSED" severity note;
        else
            report "tb_instr_mem: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        std.env.finish;
    end process;
end architecture sim;