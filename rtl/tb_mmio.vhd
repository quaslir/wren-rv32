library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_mmio is
    generic(
        N_RANDOM : natural := 6000
    );
end entity tb_mmio;

architecture sim of tb_mmio is
    constant T : time := 10 ns;

    constant A_LED : std_logic_vector(31 downto 0) := x"80000000";
    constant A_SW  : std_logic_vector(31 downto 0) := x"80000004";
    constant A_HEX : std_logic_vector(31 downto 0) := x"80000008";

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal we    : std_logic := '0';
    signal addr  : std_logic_vector(31 downto 0) := (others => '0');
    signal wd    : std_logic_vector(31 downto 0) := (others => '0');
    signal be    : std_logic_vector(3 downto 0)  := (others => '0');
    signal sw_in : std_logic_vector(9 downto 0)  := (others => '0');
    signal rd    : std_logic_vector(31 downto 0);
    signal led   : std_logic_vector(9 downto 0);
    signal hex   : std_logic_vector(23 downto 0);
    signal done  : boolean := false;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut : entity work.mmio
        port map(
            clk   => clk,
            rst   => rst,
            we    => we,
            addr  => addr,
            wd    => wd,
            be    => be,
            sw_in => sw_in,
            rd    => rd,
            led   => led,
            hex   => hex
        );

    stim : process
        variable m_led  : std_logic_vector(9 downto 0)  := (others => '0');
        variable m_hex  : std_logic_vector(23 downto 0) := (others => '0');
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable n_led, n_hex, n_sw, n_none : natural := 0;
        variable s1     : positive := 71;
        variable s2     : positive := 17;
        variable r      : real;
        variable a      : std_logic_vector(31 downto 0);
        variable d      : std_logic_vector(31 downto 0);
        variable m      : std_logic_vector(3 downto 0);
        variable e      : std_logic;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        impure function rnd_word return std_logic_vector is
            variable w : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 3 loop
                w(8 * i + 7 downto 8 * i) := std_logic_vector(to_unsigned(rnd(256), 8));
            end loop;
            return w;
        end function;

        function which(av : std_logic_vector(31 downto 0)) return natural is
        begin
            if unsigned(av(30 downto 4)) /= 0 then
                return 0;
            end if;
            case av(3 downto 2) is
                when "00"   => return 1;
                when "01"   => return 2;
                when "10"   => return 3;
                when others => return 0;
            end case;
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "@" & time'image(now) & " addr=0x" & to_hstring(addr) & ": " & msg severity error;
            end if;
        end procedure;

        procedure expect_outputs(tag : string) is
        begin
            checks := checks + 2;
            if led /= m_led then
                fail(tag & ": led=" & to_string(led) & " expected=" & to_string(m_led));
            end if;
            if hex /= m_hex then
                fail(tag & ": hex=0x" & to_hstring(hex) & " expected=0x" & to_hstring(m_hex));
            end if;
        end procedure;

        procedure expect_read(tag : string) is
            variable exp : std_logic_vector(31 downto 0);
        begin
            case which(addr) is
                when 1      => exp := (31 downto 10 => '0') & m_led;
                when 2      => exp := (31 downto 10 => '0') & sw_in;
                when 3      => exp := (31 downto 24 => '0') & m_hex;
                when others => exp := (others => '0');
            end case;
            checks := checks + 1;
            if is_x(rd) then
                fail(tag & ": rd undefined 0x" & to_hstring(rd));
            elsif rd /= exp then
                fail(tag & ": rd=0x" & to_hstring(rd) & " expected=0x" & to_hstring(exp));
            end if;
        end procedure;

        procedure read_at(av : std_logic_vector(31 downto 0); tag : string) is
        begin
            we   <= '0';
            addr <= av;
            wait for 1 ns;
            expect_read(tag);
        end procedure;

        procedure write_op(av : std_logic_vector(31 downto 0);
                           dv : std_logic_vector(31 downto 0);
                           mv : std_logic_vector(3 downto 0);
                           ev : std_logic;
                           tag : string) is
        begin
            wait until falling_edge(clk);
            addr <= av;
            wd   <= dv;
            be   <= mv;
            we   <= ev;
            wait for 1 ns;
            expect_outputs(tag & " before edge");
            expect_read(tag & " before edge");
            wait until rising_edge(clk);
            wait for 1 ns;
            if ev = '1' then
                case which(av) is
                    when 1 =>
                        if mv(0) = '1' then m_led(7 downto 0) := dv(7 downto 0); end if;
                        if mv(1) = '1' then m_led(9 downto 8) := dv(9 downto 8); end if;
                        n_led := n_led + 1;
                    when 3 =>
                        if mv(0) = '1' then m_hex(7 downto 0) := dv(7 downto 0); end if;
                        if mv(1) = '1' then m_hex(15 downto 8) := dv(15 downto 8); end if;
                        if mv(2) = '1' then m_hex(23 downto 16) := dv(23 downto 16); end if;
                        n_hex := n_hex + 1;
                    when 2 =>
                        n_sw := n_sw + 1;
                    when others =>
                        n_none := n_none + 1;
                end case;
            end if;
            expect_outputs(tag & " after edge");
            expect_read(tag & " after edge");
            we <= '0';
        end procedure;

        procedure do_reset(tag : string) is
        begin
            wait until falling_edge(clk);
            rst <= '1';
            we  <= '1';
            addr <= A_LED;
            wd  <= x"FFFFFFFF";
            be  <= "1111";
            wait until rising_edge(clk);
            wait for 1 ns;
            m_led := (others => '0');
            m_hex := (others => '0');
            expect_outputs(tag);
            wait until falling_edge(clk);
            rst <= '0';
            we  <= '0';
        end procedure;

        procedure sweep(tag : string) is
        begin
            read_at(A_LED, tag);
            read_at(A_SW, tag);
            read_at(A_HEX, tag);
            read_at(x"8000000C", tag);
        end procedure;
    begin
        sw_in <= "1010010110";
        do_reset("initial reset");
        expect_outputs("after reset");
        sweep("after reset");

        write_op(A_LED, x"000003FF", "1111", '1', "led all ones");
        write_op(A_LED, x"FFFFFC00", "1111", '1', "led upper bits ignored");
        write_op(A_LED, x"00000155", "1111", '1', "led pattern");
        write_op(A_HEX, x"00ABCDEF", "1111", '1', "hex pattern");
        write_op(A_HEX, x"FF000000", "1111", '1', "hex byte3 ignored");
        write_op(A_SW, x"FFFFFFFF", "1111", '1', "write to SW ignored");
        sweep("after directed");

        for k in 0 to 15 loop
            write_op(A_LED, x"00000000", "1111", '1', "led clear");
            write_op(A_LED, x"FFFFFFFF", std_logic_vector(to_unsigned(k, 4)), '1', "led mask " & integer'image(k));
            write_op(A_HEX, x"00000000", "1111", '1', "hex clear");
            write_op(A_HEX, x"FFFFFFFF", std_logic_vector(to_unsigned(k, 4)), '1', "hex mask " & integer'image(k));
        end loop;

        write_op(A_LED, x"000002AA", "1111", '1', "led base");
        write_op(A_HEX, x"00123456", "1111", '1', "hex base");
        for k in 0 to 15 loop
            write_op(A_LED, x"FFFFFFFF", std_logic_vector(to_unsigned(k, 4)), '0', "led we=0 mask " & integer'image(k));
            write_op(A_HEX, x"FFFFFFFF", std_logic_vector(to_unsigned(k, 4)), '0', "hex we=0 mask " & integer'image(k));
        end loop;

        for lo in 1 to 3 loop
            write_op(std_logic_vector(unsigned(A_LED) + lo), x"0000FFFF", "0010", '1', "led byte addr +" & integer'image(lo));
            write_op(std_logic_vector(unsigned(A_HEX) + lo), x"00770000", "0100", '1', "hex byte addr +" & integer'image(lo));
        end loop;

        write_op(x"8000000C", x"FFFFFFFF", "1111", '1', "unmapped 0x0C");
        write_op(x"80000010", x"FFFFFFFF", "1111", '1', "alias 0x10");
        write_op(x"80000018", x"FFFFFFFF", "1111", '1', "alias 0x18");
        write_op(x"80000100", x"FFFFFFFF", "1111", '1', "alias 0x100");
        write_op(x"80010000", x"FFFFFFFF", "1111", '1', "alias 0x10000");
        write_op(x"C0000000", x"FFFFFFFF", "1111", '1', "alias bit30");
        write_op(x"80000008" or x"40000000", x"FFFFFFFF", "1111", '1', "alias bit30 hex");
        write_op(x"00000000", x"00000111", "1111", '1', "addr31=0 maps to led");
        write_op(x"00000008", x"00222222", "1111", '1', "addr31=0 maps to hex");
        sweep("after alias");

        for i in 0 to 9 loop
            sw_in <= (others => '0');
            sw_in(i) <= '1';
            read_at(A_SW, "sw walking one");
            sw_in <= (others => '1');
            sw_in(i) <= '0';
            read_at(A_SW, "sw walking zero");
        end loop;

        write_op(A_LED, x"0000037F", "1111", '1', "before mid reset");
        write_op(A_HEX, x"00FEDCBA", "1111", '1', "before mid reset");
        do_reset("mid reset");
        sweep("after mid reset");

        for n in 1 to N_RANDOM loop
            case rnd(8) is
                when 0 | 1 | 2 => a := A_LED;
                when 3 | 4 | 5 => a := A_HEX;
                when 6         => a := A_SW;
                when others    => a := x"80000000" or (rnd_word and x"7FFFFFF0");
            end case;
            a(1 downto 0) := std_logic_vector(to_unsigned(rnd(4), 2));
            d := rnd_word;
            m := std_logic_vector(to_unsigned(rnd(16), 4));
            if rnd(4) = 0 then e := '0'; else e := '1'; end if;
            if rnd(10) = 0 then
                sw_in <= std_logic_vector(to_unsigned(rnd(1024), 10));
            end if;
            write_op(a, d, m, e, "random");
            if rnd(200) = 0 then
                do_reset("random reset");
            end if;
            if n mod 500 = 0 then
                sweep("random sweep");
            end if;
        end loop;
        sweep("final");

        report "tb_mmio: " & integer'image(checks) & " checks, writes led/hex/sw/unmapped = " &
               integer'image(n_led) & "/" & integer'image(n_hex) & "/" & integer'image(n_sw) & "/" &
               integer'image(n_none) & ", " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_mmio FAILED" severity failure;
        report "tb_mmio PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;