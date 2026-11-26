library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
    port(
        clk : in std_logic;
        we : in std_logic;
        ra1: in std_logic_vector(4 downto 0);
        ra2: in std_logic_vector(4 downto 0);
        wa : in std_logic_vector(4 downto 0);
        wd: in std_logic_vector(31 downto 0);

        rd1: out std_logic_vector(31 downto 0);
        rd2: out std_logic_vector(31 downto 0)

    );
end entity regfile;


architecture synth of regfile is
    type mem_array is array (31 downto 0) of std_logic_vector(31 downto 0);
    signal mem : mem_array := (others => (others => '0'));
begin
   process(clk)
   begin

    if rising_edge(clk)  then
        if we = '1' and wa /= "00000" then
            mem(to_integer(unsigned(wa))) <= wd;
        end if;
    end if;

   end process;

    rd1 <= mem(to_integer(unsigned(ra1)));
    rd2 <= mem(to_integer(unsigned(ra2)));
end architecture synth;
