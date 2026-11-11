library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_regfile is
end entity tb_regfile;

architecture sim of tb_regfile is
    signal clk: STD_LOGIC := '0';
    signal we: STD_LOGIC := '0';
    signal ra1: std_logic_vector(4 downto 0) := (others => '0');
    signal ra2: std_logic_vector(4 downto 0) := (others => '0');
    signal wa: std_logic_vector(4 downto 0) := (others => '0');
    signal wd: std_logic_vector(31 downto 0):= (others => '0');
    signal rd1: std_logic_vector(31 downto 0):= (others => '0');
    signal rd2: std_logic_vector(31 downto 0):= (others => '0');
begin
riscv_ram_inst : entity work.riscv_ram
    port map(
        clk => clk,
        we  => we,
        ra1 => ra1,
        ra2 => ra2,
        wa  => wa,
        wd  => wd,
        rd1 => rd1,
        rd2 => rd2
    );

    clk <= not clk after 10 ns;
    process
    begin

    we <= '1';


    for i in 0 to 5 loop
    wa <= std_logic_vector(to_unsigned(i, 5));
    wd <= std_logic_vector(to_unsigned(i * 4 + 1, 32));
    wait until rising_edge(clk);
    end loop;

    we <= '0';

   for i in 0 to 5 loop
    ra1 <= std_logic_vector(to_unsigned(i, 5));
    ra2 <= std_logic_vector(to_unsigned(5 - i, 5));
    wait for 1 ns;

    if i = 0 then
        assert rd1 = x"00000000"
            report "rd1: x0 is not zero" severity error;
    else
        assert rd1 = std_logic_vector(to_unsigned(i * 4 + 1, 32))
            report "rd1: wrong value in x" & integer'image(i) severity error;
    end if;

    if 5 - i = 0 then
        assert rd2 = x"00000000"
            report "rd2: x0 is not zero" severity error;
    else
        assert rd2 = std_logic_vector(to_unsigned((5 - i) * 4 + 1, 32))
            report "rd2: wrong value in x" & integer'image(5 - i) severity error;
    end if;

    wait until rising_edge(clk);
end loop;

report "Read tests done";


    wait;
    end process;
end architecture sim;
