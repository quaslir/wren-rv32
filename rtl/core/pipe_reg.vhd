library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipe_reg is
    generic(
        WIDTH : positive := 32
    );
    port(
        clk : in  std_logic;
        rst : in  std_logic;
        en  : in  std_logic;
        clr : in  std_logic;
        d   : in  std_logic_vector(WIDTH - 1 downto 0);
        q   : out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity pipe_reg;

architecture synth of pipe_reg is

begin
    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                q <= (others => '0');
            elsif clr = '1' then
                q <= (others => '0');
            elsif en = '1' then
                q <= d;

            end if;
        end if;

    end process;
end architecture synth;
