library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity ram is
    generic (
    DEPTH : positive := 64;
    INIT_FILE: string := "sw/main.hex"
    );
    port(
        clk : in std_logic;
        we: in std_logic;
        addr: in std_logic_vector(31 downto 0);
        addr_a: in std_logic_vector(31 downto 0);
        wd: in std_logic_vector(31 downto 0);
        be: in std_logic_vector(3 downto 0);
        rd : out std_logic_vector(31 downto 0);
        rd_a : out std_logic_vector(31 downto 0)

    );
end entity ram;



architecture synth of ram is
            type ram_t is array(integer range 0 to DEPTH - 1) of std_logic_vector(31 downto 0);
    impure function readfile(filename: string)
        return ram_t is
            file instr_file : text open read_mode is filename;
            variable line_buffer : line;
            variable word : std_logic_vector(31 downto 0) := (others => '0');
            variable instructions: ram_t := (others => x"00000000");
            variable index : integer := 0;
            
    begin
        
        for i in 0 to 4 * DEPTH - 1 loop
        if endfile(instr_file) then
            exit;
        end if;
        if index = DEPTH then
            exit;
        end if;
        readline(instr_file, line_buffer);
        if line_buffer'length /= 0 then 
        hread(line_buffer, word);
        instructions(index) := word;
        index := index + 1;
        end if;
        end loop;

        return instructions;
    end function readfile;

    signal mem: ram_t := readfile(INIT_FILE);
    signal index: integer range 0 to 2 ** 30 - 1;
    signal index2: integer range 0 to 2**30 - 1;
    

   
    

begin
    index <= to_integer(unsigned(addr(31 downto 2)));
    index2 <= to_integer(unsigned(addr_a(31 downto 2)));

    process(clk) 
    begin
        if rising_edge(clk) then
            if we = '1' and index < DEPTH then
            for i in 0 to 3 loop
                    if be(i) = '1' then
                       mem(index)(8 * i + 7 downto 8 * i) <= wd(8 * i + 7 downto 8 * i);
                    end if;
            end loop;
            
            end if;
        end if; 
    end process;
    
    rd <= mem(index) when index < DEPTH else (others => '0');
    rd_a <= mem(index2) when index2
         < DEPTH else (others => '0');
end architecture synth;
