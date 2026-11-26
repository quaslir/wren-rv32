library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pc_reg is
    generic(
        WIDTH: positive := 32
        );
    port(
        clk : in std_logic;
        rst : in std_logic;
        next_pc: in std_logic_vector(WIDTH - 1 downto 0);
        pc: out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity pc_reg;


architecture synth of pc_reg is
    
begin
    process(clk) 
    begin
        if rising_edge(clk) then
            if rst = '1' then 
                pc <= (others => '0');
            else 
                pc <= next_pc;
        end if;
    end if;
    end process;
end architecture synth;
