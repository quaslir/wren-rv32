library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mmio is
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;
        we    : in  std_logic;
        addr  : in  std_logic_vector(31 downto 0);
        wd    : in  std_logic_vector(31 downto 0);
        be    : in  std_logic_vector(3 downto 0);
        sw_in : in  std_logic_vector(9 downto 0);
        btn   : in  std_logic;
        rd    : out std_logic_vector(31 downto 0);
        led   : out std_logic_vector(9 downto 0);
        hex   : out std_logic_vector(23 downto 0);
        irq   : out std_logic
    );
end entity mmio;

architecture synth of mmio is
    signal sel_led   : std_logic := '0';
    signal sel_sw_in : std_logic := '0';
    signal sel_hex   : std_logic := '0';
    signal sel_irq   : std_logic := '0';
    signal flag      : std_logic := '0';  -- irq pending flag
    signal btn_prev  : std_logic := '0';  -- button value last cycle
    signal rise      : std_logic := '0';  -- button rising edge
    signal irq_set   : std_logic := '0';
    signal irq_clear : std_logic := '0';
    signal in_range  : std_logic := '0';

    signal hex_reg : std_logic_vector(23 downto 0) := (others => '0');
    signal led_reg : std_logic_vector(9 downto 0)  := (others => '0');
begin
    in_range  <= '1' when unsigned(addr(30 downto 4)) = 0 else  -- I/O window 0x80000000..0x8000000F
                 '0';
    sel_led   <= '1' when in_range = '1' and addr(3 downto 2) = "00" else  -- 0x80000000: LEDs
                 '0';
    sel_sw_in <= '1' when in_range = '1' and addr(3 downto 2) = "01" else  -- 0x80000004: switches
                 '0';
    sel_hex   <= '1' when in_range = '1' and addr(3 downto 2) = "10" else  -- 0x80000008: hex display
                 '0';

    sel_irq <= '1' when in_range = '1' and addr(3 downto 2) = "11" else  -- 0x8000000C: irq control/status
        '0';
    rise <= btn and not btn_prev;  -- detect button press

    irq_set <= rise or (we and sel_irq and be(0) and wd(1));  -- set irq on press or write bit 1


    irq_clear <= we and sel_irq and be(0) and wd(0);  -- clear irq by writing bit 0
    process(clk)  -- LED / hex registers
    begin
        if rising_edge(clk) then

            if rst = '1' then

                led_reg <= (others => '0');
                hex_reg <= (others => '0');

            elsif we = '1' then
                if sel_led = '1' then  -- LED write
                    if be(0) = '1' then
                        led_reg(7 downto 0) <= wd(7 downto 0);
                    end if;
                    if be(1) = '1' then
                        led_reg(9 downto 8) <= wd(9 downto 8);
                    end if;

                end if;
                if sel_hex = '1' then  -- hex write
                    if be(0) = '1' then
                        hex_reg(7 downto 0) <= wd(7 downto 0);
                    end if;
                    if (be(1) = '1') then
                        hex_reg(15 downto 8) <= wd(15 downto 8);
                    end if;
                    if (be(2) = '1') then
                        hex_reg(23 downto 16) <= wd(23 downto 16);
                    end if;
                end if;
            end if;
        end if;
    end process;

    process(clk)  -- irq flag
    begin

        if rising_edge(clk) then
                btn_prev <= btn;  -- sample button for edge detect
            if rst = '1' then
                flag <= '0';
            else
                if irq_set = '1' then  -- set wins over clear
                    flag <= '1';
                elsif irq_clear = '1' then
                    flag <= '0';
                end if;

            end if;
        end if;

    end process;



    led <= led_reg;
    hex <= hex_reg;
    irq <= flag;
    rd  <= (31 downto 10 => '0') & led_reg when sel_led = '1' else  -- I/O read mux
           (31 downto 24 => '0') & hex_reg when sel_hex = '1' else
           (31 downto 10 => '0') & sw_in when sel_sw_in = '1' else
           (31 downto 1 => '0') & flag when sel_irq = '1' else
           (others => '0');
end architecture synth;
