library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity instr_mem is
    generic(
    INIT_FILE: string;
    DEPTH : positive := 64
    
    );
    port(
        addr: in std_logic_vector(31 downto 0);
        instr: out std_logic_vector(31 downto 0)

    );
end entity instr_mem;



architecture synth of instr_mem is
type rom_t is array(0 to DEPTH - 1) of std_logic_vector(31 downto 0);

    impure function readfile(filename: string)
        return rom_t is
            file instr_file : text open read_mode is filename;
            variable line_buffer : line;
            variable word : std_logic_vector(31 downto 0) := (others => '0');
            variable instructions: rom_t := (others => x"00000000");
            variable index: integer range 0 to DEPTH;
            
    begin
        
       while not endfile(instr_file) and index < DEPTH loop
        readline(instr_file, line_buffer);
        if line_buffer'length /= 0 then 
        hread(line_buffer, word);
        instructions(index) := word;
                index := index + 1;
        end if;
       end loop;
       



        return instructions;
    end function readfile;
    


    constant ROM: rom_t := readfile(INIT_FILE);
    signal index: integer range 0 to 2**30 - 1;
    signal next_instr : std_logic_vector(31 downto 0);
begin   
     index <= to_integer(unsigned(addr(31 downto 2)));
    process (index)
    begin
    next_instr <= (others => '0');

    if index < DEPTH then
        next_instr <= ROM(index);
    end if;
    end process;

    instr <= next_instr;
end architecture synth;
