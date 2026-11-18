library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_mem is
    generic (
    DEPTH : positive := 64
    );
    port(
        clk : in std_logic;
        we: in std_logic;
        addr: in std_logic_vector(31 downto 0);
        wd: in std_logic_vector(31 downto 0);
        rd : out std_logic_vector(31 downto 0)

    );
end entity data_mem;



architecture synth of data_mem is
        type ram_t is array(integer range 0 to DEPTH - 1) of std_logic_vector(31 downto 0);
    signal RAM: ram_t := (others => (others => '0'));
    signal index: integer range 0 to 2 ** 30 - 1;

begin
    index <= to_integer(unsigned(addr(31 downto 2)));
    process(clk) 
    begin
        if rising_edge(clk) then
            if we = '1' and index < DEPTH then
            RAM(index) <= wd;
            end if;
        end if; 
    end process;
    
    rd <= RAM(index) when index < DEPTH else (others => '0');
end architecture synth;
