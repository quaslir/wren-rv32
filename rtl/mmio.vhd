library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mmio is
    port(
        clk : in std_logic;
        rst : in std_logic;
        we: in std_logic;
        addr: in std_logic_vector(31 downto 0);
        wd: in std_logic_vector(31 downto 0);
        be: in std_logic_vector(3 downto 0);
        sw_in: in std_logic_vector(9 downto 0);

        rd: out std_logic_vector(31 downto 0);
        led : out std_logic_vector(9 downto 0);
        hex: out std_logic_vector(23 downto 0)
    );
end entity mmio;


architecture synth of mmio is
    signal sel_led : std_logic := '0';
    signal sel_sw_in : std_logic := '0';
    signal sel_hex: std_logic := '0';
    signal in_range: std_logic := '0';


    signal hex_reg: std_logic_vector(23 downto 0) := (others => '0');
    signal led_reg: std_logic_vector(9 downto 0) := (others => '0'); 
begin
    in_range <= '1' when unsigned(addr(30 downto 4)) = 0 else
        '0';
    sel_led <= '1' when in_range = '1' and addr(3 downto 2) = "00" else
        '0';
    sel_sw_in <= '1' when in_range = '1' and addr(3 downto 2) = "01" else
        '0';
    sel_hex <= '1' when in_range = '1' and addr(3 downto 2) = "10" else
        '0';
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then

            led_reg <= (others => '0');
            hex_reg <= (others => '0');

            elsif we = '1' then
                if sel_led = '1' then
                if be(0) = '1' then
                    led_reg(7 downto 0) <= wd(7 downto 0);
                end if;
                if be(1) = '1' then
                    led_reg(9 downto 8) <= wd(9 downto 8);
                end if;
                
            end if;
            if sel_hex = '1' then
                if be(0) = '1' then
                    hex_reg(7 downto 0) <= wd(7 downto 0);
                end if;
                if(be(1) = '1') then
                    hex_reg(15 downto 8) <= wd(15 downto 8);
                end if;
                if(be(2) = '1') then
                    hex_reg(23 downto 16) <= wd(23 downto 16);
                end if;
            end if;
        end if;
    end if;
    end process;

    led <= led_reg;
    hex <= hex_reg;
    
rd <= (31 downto 10 => '0') & led_reg when sel_led = '1' else
    (31 downto 24 => '0') & hex_reg when sel_hex = '1' else
    (31 downto 10 => '0') & sw_in when sel_sw_in = '1' else
    (others => '0');  
end architecture synth;
