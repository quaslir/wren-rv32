library ieee;
use ieee.std_logic_1164.all;
entity store_align is
    port(
       size: in std_logic_vector(1 downto 0);
       addr_lo : in std_logic_vector(1 downto 0);
       wd: in std_logic_vector(31 downto 0);
       wd_out: out std_logic_vector(31 downto 0);
       be: out std_logic_vector(3 downto 0)

    );
end entity store_align;



architecture synth of store_align is
    signal is_sb: std_logic := '0';
    signal is_sh : std_logic := '0';
    signal is_sw: std_logic := '0';
    
begin
    wd_out <= wd(7 downto 0) & wd(7 downto 0) & wd(7 downto 0) & wd(7 downto 0) when size = "00" else  -- sb: copy byte to all lanes
        wd(15 downto 0) & wd(15 downto 0) when size = "01" else  -- sh: copy halfword to both halves
        wd when size = "10" else  -- sw: as is
        (others => '0');
    
    is_sb <= '1' when size = "00" else '0';  -- store byte
    is_sh <= '1' when size = "01" and addr_lo(0) = '0' else '0';  -- aligned store half
    is_sw <= '1' when size = "10"and addr_lo = "00" else '0';  -- aligned store word

    be(0) <= '1' when is_sw = '1' or (is_sb = '1' and addr_lo = "00") or (is_sh = '1' and addr_lo(1) = '0') else '0';  -- byte lane 0 enable
    be(1) <= '1' when is_sw = '1' or (is_sb = '1' and addr_lo = "01") or (is_sh = '1' and addr_lo(1) = '0') else '0';  -- byte lane 1 enable
    be(2) <= '1' when is_sw = '1' or (is_sb = '1' and addr_lo = "10") or (is_sh = '1' and addr_lo(1) = '1') else '0';  -- byte lane 2 enable
    be(3) <= '1' when is_sw = '1' or (is_sb = '1' and addr_lo = "11") or (is_sh = '1' and addr_lo(1) = '1') else '0';  -- byte lane 3 enable
    
end architecture synth;
