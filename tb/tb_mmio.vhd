library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_mmio is
    generic(
        N_RANDOM : natural := 20000
    );
end entity tb_mmio;

architecture sim of tb_mmio is
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal we    : std_logic := '0';
    signal addr  : std_logic_vector(31 downto 0) := (others => '0');
    signal wd    : std_logic_vector(31 downto 0) := (others => '0');
    signal be    : std_logic_vector(3 downto 0) := "0000";
    signal sw_in : std_logic_vector(9 downto 0) := (others => '0');
    signal btn   : std_logic := '0';
    signal rd    : std_logic_vector(31 downto 0);
    signal led   : std_logic_vector(9 downto 0);
    signal hex   : std_logic_vector(23 downto 0);
    signal irq   : std_logic;

    constant A_LED : std_logic_vector(31 downto 0) := x"80000000";
    constant A_SW  : std_logic_vector(31 downto 0) := x"80000004";
    constant A_HEX : std_logic_vector(31 downto 0) := x"80000008";
    constant A_IRQ : std_logic_vector(31 downto 0) := x"8000000C";
begin
    dut: entity work.mmio
        port map(clk => clk, rst => rst, we => we, addr => addr, wd => wd, be => be, sw_in => sw_in,
                 btn => btn, rd => rd, led => led, hex => hex, irq => irq);

    stim: process
        variable m_led   : std_logic_vector(9 downto 0) := (others => '0');
        variable m_hex   : std_logic_vector(23 downto 0) := (others => '0');
        variable m_flag  : std_logic := '0';
        variable m_prev  : std_logic := '0';
        variable started : boolean := false;
        variable errors, checks : natural := 0;
        variable n_rise, n_swset, n_clr : natural := 0;
        variable s1, s2  : positive := 17;
        variable r       : real;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(floor(r * real(n))) mod n;
        end function;

        impure function rnd_slv(n : positive) return std_logic_vector is
            variable x : std_logic_vector(n - 1 downto 0);
        begin
            for i in x'range loop
                if rnd(2) = 1 then x(i) := '1'; else x(i) := '0'; end if;
            end loop;
            return x;
        end function;

        procedure chk(ok : boolean; what : string) is
        begin
            checks := checks + 1;
            if not ok then
                errors := errors + 1;
                if errors <= 20 then
                    report what & " (addr=0x" & to_hstring(addr) & " we=" & std_logic'image(we) & " be=" & to_string(be)
                        & " wd=0x" & to_hstring(wd) & " btn=" & std_logic'image(btn) & ")" severity error;
                end if;
            end if;
        end procedure;

        impure function in_range return boolean is
        begin
            return unsigned(addr(30 downto 4)) = 0;
        end function;

        impure function m_rd return std_logic_vector is
            variable v : std_logic_vector(31 downto 0) := (others => '0');
        begin
            if in_range then
                case addr(3 downto 2) is
                    when "00"   => v(9 downto 0) := m_led;
                    when "01"   => v(9 downto 0) := sw_in;
                    when "10"   => v(23 downto 0) := m_hex;
                    when others => v(0) := m_flag;
                end case;
            end if;
            return v;
        end function;

        procedure check_outputs(tag : string) is
        begin
            chk(rd = m_rd, tag & ": rd got 0x" & to_hstring(rd) & " exp 0x" & to_hstring(m_rd));
            chk(led = m_led, tag & ": led got " & to_string(led) & " exp " & to_string(m_led));
            chk(hex = m_hex, tag & ": hex got 0x" & to_hstring(hex) & " exp 0x" & to_hstring(m_hex));
            chk(irq = m_flag, tag & ": irq got " & std_logic'image(irq) & " exp " & std_logic'image(m_flag));
        end procedure;

        procedure model_edge is
            variable rise, set, clr : boolean;
            variable sel : boolean;
        begin
            if rst = '1' then
                m_led := (others => '0');
                m_hex := (others => '0');
                m_flag := '0';
                m_prev := btn;
                return;
            end if;
            sel := in_range;
            if we = '1' and sel then
                case addr(3 downto 2) is
                    when "00" =>
                        if be(0) = '1' then m_led(7 downto 0) := wd(7 downto 0); end if;
                        if be(1) = '1' then m_led(9 downto 8) := wd(9 downto 8); end if;
                    when "10" =>
                        if be(0) = '1' then m_hex(7 downto 0) := wd(7 downto 0); end if;
                        if be(1) = '1' then m_hex(15 downto 8) := wd(15 downto 8); end if;
                        if be(2) = '1' then m_hex(23 downto 16) := wd(23 downto 16); end if;
                    when others => null;
                end case;
            end if;
            rise := btn = '1' and m_prev = '0';
            set := rise or (we = '1' and sel and addr(3 downto 2) = "11" and be(0) = '1' and wd(1) = '1');
            clr := we = '1' and sel and addr(3 downto 2) = "11" and be(0) = '1' and wd(0) = '1';
            if rise then n_rise := n_rise + 1; end if;
            if set and not rise then n_swset := n_swset + 1; end if;
            if clr then n_clr := n_clr + 1; end if;
            if set then
                m_flag := '1';
            elsif clr then
                m_flag := '0';
            end if;
            m_prev := btn;
        end procedure;

        procedure tick(tag : string) is
        begin
            wait for 1 ns;
            if started then
                check_outputs(tag);
            end if;
            model_edge;
            clk <= '1';
            wait for 5 ns;
            clk <= '0';
            wait for 4 ns;
            check_outputs(tag & " after edge");
            started := true;
        end procedure;

        procedure idle is
        begin
            we <= '0'; rst <= '0'; be <= "0000"; wd <= (others => '0');
        end procedure;

        procedure wr(a : std_logic_vector(31 downto 0); d : std_logic_vector(31 downto 0);
                     b : std_logic_vector(3 downto 0); tag : string) is
        begin
            addr <= a; wd <= d; be <= b; we <= '1'; rst <= '0';
            tick(tag);
            idle;
        end procedure;

        procedure rd_chk(a : std_logic_vector(31 downto 0); exp : std_logic_vector(31 downto 0); tag : string) is
        begin
            addr <= a; we <= '0';
            wait for 1 ns;
            chk(rd = exp, tag & ": read got 0x" & to_hstring(rd) & " exp 0x" & to_hstring(exp));
        end procedure;

        procedure do_reset is
        begin
            idle; rst <= '1';
            tick("reset");
            rst <= '0';
        end procedure;

        procedure press(tag : string) is
        begin
            btn <= '1'; idle; tick(tag & " press");
        end procedure;

        procedure let_go(tag : string) is
        begin
            btn <= '0'; idle; tick(tag & " release");
        end procedure;

        variable bb : std_logic_vector(3 downto 0);
    begin
        sw_in <= "1010011001";
        do_reset;
        rd_chk(A_LED, x"00000000", "reset led");
        rd_chk(A_HEX, x"00000000", "reset hex");
        rd_chk(A_IRQ, x"00000000", "reset irq");
        rd_chk(A_SW, x"00000299", "sw read");
        rd_chk(x"80000006", x"00000299", "sw read addr(1:0) ignored");

        for m in 0 to 15 loop
            bb := std_logic_vector(to_unsigned(m, 4));
            wr(A_LED, x"00000000", "1111", "led clear");
            wr(A_LED, x"FFFFFFFF", bb, "led be=" & to_string(bb));
            wr(A_HEX, x"00000000", "1111", "hex clear");
            wr(A_HEX, x"FFFFFFFF", bb, "hex be=" & to_string(bb));
        end loop;
        wr(A_LED, x"00000155", "1111", "led 0x155");
        addr <= A_LED; wd <= x"FFFFFFFF"; be <= "1111"; we <= '0';
        tick("led we=0");
        idle;
        wr(A_SW, x"FFFFFFFF", "1111", "sw write ignored");
        wr(x"80000010", x"FFFFFFFF", "1111", "0x10 out of range");
        wr(x"80000020", x"FFFFFFFF", "1111", "0x20 out of range");
        wr(x"C0000000", x"FFFFFFFF", "1111", "0xC0000000 alias");
        wr(x"80001008", x"FFFFFFFF", "1111", "0x1008 alias");
        rd_chk(x"80000010", x"00000000", "0x10 reads 0");
        rd_chk(x"80001000", x"00000000", "0x1000 reads 0");
        wr(x"80000003", x"FFFFFFFF", "1111", "led via addr(1:0)=11");
        do_reset;

        press("edge 1");
        rd_chk(A_IRQ, x"00000001", "flag set by edge");
        btn <= '1'; idle; tick("held");
        wr(A_IRQ, x"00000001", "0001", "clear while held");
        rd_chk(A_IRQ, x"00000000", "held button does not re-set");
        for k in 1 to 5 loop
            btn <= '1'; idle; tick("still held");
        end loop;
        let_go("edge 1");
        press("edge 2");
        rd_chk(A_IRQ, x"00000001", "second press sets");
        let_go("edge 2");
        wr(A_IRQ, x"00000001", "1110", "clear without be0");
        rd_chk(A_IRQ, x"00000001", "be0=0 ignored");
        wr(A_IRQ, x"00000000", "1111", "write 0");
        rd_chk(A_IRQ, x"00000001", "write 0 does nothing");
        wr(A_IRQ, x"00000001", "1111", "clear");
        rd_chk(A_IRQ, x"00000000", "cleared");
        wr(A_IRQ, x"00000002", "0001", "sw set");
        rd_chk(A_IRQ, x"00000001", "sw set works");
        wr(A_IRQ, x"00000001", "0001", "clear");
        wr(A_IRQ, x"00000003", "0001", "set+clear");
        rd_chk(A_IRQ, x"00000001", "set beats clear");
        wr(A_IRQ, x"00000001", "0001", "clear");
        wr(A_IRQ, x"00000002", "1110", "sw set without be0");
        rd_chk(A_IRQ, x"00000000", "sw set needs be0");
        wr(A_LED, x"00000003", "1111", "led write with bits 1,0");
        wr(x"80000010", x"00000002", "1111", "0x10 with bit 1");
        rd_chk(A_IRQ, x"00000000", "other writes do not touch flag");
        btn <= '1';
        addr <= A_IRQ; wd <= x"00000001"; be <= "0001"; we <= '1';
        tick("press during clear");
        idle;
        rd_chk(A_IRQ, x"00000001", "edge beats clear");
        let_go("x");
        wr(A_IRQ, x"00000001", "0001", "clear");
        wr(A_IRQ, x"00000002", "0001", "set before reset");
        btn <= '1';
        do_reset;
        rd_chk(A_IRQ, x"00000000", "reset clears flag");
        for k in 1 to 3 loop
            btn <= '1'; idle; tick("held after reset");
        end loop;
        rd_chk(A_IRQ, x"00000000", "button held through reset: no edge");
        let_go("after reset");
        press("after reset");
        rd_chk(A_IRQ, x"00000001", "real press after reset");

        do_reset;
        for n in 1 to N_RANDOM loop
            idle;
            case rnd(8) is
                when 0 => addr <= A_LED;
                when 1 => addr <= A_SW;
                when 2 => addr <= A_HEX;
                when 3 | 4 => addr <= A_IRQ;
                when 5 => addr <= x"800000" & "000" & rnd_slv(5);
                when 6 => addr <= rnd_slv(32);
                when others => addr <= x"8000000" & rnd_slv(4);
            end case;
            wd <= rnd_slv(32);
            be <= rnd_slv(4);
            if rnd(3) /= 0 then we <= '1'; end if;
            if rnd(4) = 0 then btn <= not btn; end if;
            if rnd(10) = 0 then sw_in <= rnd_slv(10); end if;
            if rnd(1000) = 0 then rst <= '1'; end if;
            tick("random #" & integer'image(n));
        end loop;

        if errors = 0 then
            report "tb_mmio: PASS (" & integer'image(checks) & " checks, rises " & integer'image(n_rise)
                & ", sw sets " & integer'image(n_swset) & ", clears " & integer'image(n_clr) & ")" severity note;
        else
            report "tb_mmio: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & ")" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;