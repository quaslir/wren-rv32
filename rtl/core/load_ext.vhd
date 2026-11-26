library ieee;
use ieee.std_logic_1164.all;

entity load_ext is
    port(
        funct3: in std_logic_vector(2 downto 0);
        addr_lo: in std_logic_vector(1 downto 0);
        rd: in std_logic_vector(31 downto 0);
        read_data: out std_logic_vector(31 downto 0)
    );
end entity load_ext;


architecture synth of load_ext is
    signal byte: std_logic_vector(7 downto 0) := (others => '0');
    signal half_word: std_logic_vector(15 downto 0) := (others => '0');
    signal sign_b: std_logic := '0';
    signal sign_h: std_logic := '0';
    alias size: std_logic_vector(1 downto 0) is funct3(1 downto 0);
begin
    byte_mux : entity work.mux4  -- pick byte by address
        generic map(
            WIDTH => 8
        )
        port map(
            d0  => rd(7 downto 0),
            d1  => rd(15 downto 8),
            d2  => rd(23 downto 16),
            d3  => rd(31 downto 24),
            sel => addr_lo,
            y   => byte
        );
    
        half_word_mux : entity work.mux2  -- pick halfword by address bit 1
            generic map(
                WIDTH => 16
            )
            port map(
                d0  => rd(15 downto 0),
                d1  => rd(31 downto 16),
                sel => addr_lo(1),
                y   => half_word
            );

    sign_b <= byte(7) and (not funct3(2));  -- sign bit for lb (0 for lbu)
    sign_h <= half_word(15) and (not funct3(2));  -- sign bit for lh (0 for lhu)
    
    read_data <= (31 downto 8 => sign_b ) & byte when size  = "00" else  -- byte load
        (31 downto 16 => sign_h) & half_word when size = "01" else  -- halfword load
        rd;  -- word load

end architecture synth;
