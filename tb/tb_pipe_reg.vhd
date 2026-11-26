library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_pipe_reg is
    generic(
        N_RANDOM : natural := 20000
    );
end entity tb_pipe_reg;

architecture sim of tb_pipe_reg is
    signal clk  : std_logic := '0';
    signal rst  : std_logic := '0';
    signal en   : std_logic := '0';
    signal clr  : std_logic := '0';
    signal d32  : std_logic_vector(31 downto 0) := (others => '0');
    signal q32  : std_logic_vector(31 downto 0);
    signal d5   : std_logic_vector(4 downto 0) := (others => '0');
    signal q5   : std_logic_vector(4 downto 0);
    signal d1   : std_logic_vector(0 downto 0) := "0";
    signal q1   : std_logic_vector(0 downto 0);
begin
    dut32: entity work.pipe_reg
        generic map(WIDTH => 32)
        port map(clk => clk, rst => rst, en => en, clr => clr, d => d32, q => q32);

    dut5: entity work.pipe_reg
        generic map(WIDTH => 5)
        port map(clk => clk, rst => rst, en => en, clr => clr, d => d5, q => q5);

    dut1: entity work.pipe_reg
        generic map(WIDTH => 1)
        port map(clk => clk, rst => rst, en => en, clr => clr, d => d1, q => q1);

    stim: process
        variable m32 : std_logic_vector(31 downto 0) := (others => '0');
        variable m5  : std_logic_vector(4 downto 0) := (others => '0');
        variable m1  : std_logic_vector(0 downto 0) := "0";
        variable errors, checks : natural := 0;
        variable started : boolean := false;
        variable s1, s2 : positive := 29;
        variable r : real;

        impure function rnd_slv(n : positive) return std_logic_vector is
            variable x : std_logic_vector(n - 1 downto 0);
        begin
            for i in x'range loop
                uniform(s1, s2, r);
                if r < 0.5 then x(i) := '0'; else x(i) := '1'; end if;
            end loop;
            return x;
        end function;

        impure function rnd_bit(p : real) return std_logic is
        begin
            uniform(s1, s2, r);
            if r < p then return '1'; else return '0'; end if;
        end function;

        procedure chk(tag : string) is
        begin
            checks := checks + 3;
            if q32 /= m32 or q5 /= m5 or q1 /= m1 then
                errors := errors + 1;
                if errors <= 20 then
                    report tag & ": rst=" & std_logic'image(rst) & " clr=" & std_logic'image(clr) & " en=" &
                           std_logic'image(en) & " q32=0x" & to_hstring(q32) & " exp 0x" & to_hstring(m32) &
                           " q5=" & to_string(q5) & " exp " & to_string(m5) &
                           " q1=" & to_string(q1) & " exp " & to_string(m1) severity error;
                end if;
            end if;
        end procedure;

        procedure tick(tag : string) is
        begin
            wait for 1 ns;
            if started then
                chk(tag & " before edge");
            end if;
            if rst = '1' or clr = '1' then
                m32 := (others => '0');
                m5 := (others => '0');
                m1 := "0";
            elsif en = '1' then
                m32 := d32;
                m5 := d5;
                m1 := d1;
            end if;
            clk <= '1';
            wait for 5 ns;
            clk <= '0';
            wait for 4 ns;
            chk(tag & " after edge");
            started := true;
        end procedure;

        procedure apply(r_v, c_v, e_v : std_logic; tag : string) is
        begin
            rst <= r_v; clr <= c_v; en <= e_v;
            d32 <= rnd_slv(32); d5 <= rnd_slv(5); d1 <= rnd_slv(1);
            tick(tag);
        end procedure;

        procedure load_ones is
        begin
            rst <= '0'; clr <= '0'; en <= '1';
            d32 <= (others => '1'); d5 <= (others => '1'); d1 <= "1";
            tick("load ones");
        end procedure;
    begin
        apply('1', '0', '0', "reset");

        load_ones;
        for k in 1 to 5 loop
            apply('0', '0', '0', "hold (en=0)");
        end loop;

        for k in 1 to 5 loop
            apply('0', '0', '1', "load (en=1)");
        end loop;

        for c in 0 to 7 loop
            load_ones;
            apply(std_logic(to_unsigned(c, 3)(2)), std_logic(to_unsigned(c, 3)(1)), std_logic(to_unsigned(c, 3)(0)),
                  "combination rst/clr/en=" & to_string(std_logic_vector(to_unsigned(c, 3))));
        end loop;

        load_ones;
        apply('0', '1', '0', "clr while stalled");
        load_ones;
        apply('0', '1', '1', "clr beats en");
        load_ones;
        apply('1', '0', '1', "rst beats en");
        load_ones;
        apply('0', '0', '0', "en=0 keeps ones");
        apply('0', '0', '0', "en=0 keeps ones again");

        for n in 1 to N_RANDOM loop
            apply(rnd_bit(0.02), rnd_bit(0.15), rnd_bit(0.7), "random #" & integer'image(n));
        end loop;

        if errors = 0 then
            report "tb_pipe_reg: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_pipe_reg: FAIL (" & integer'image(errors) & " errors)" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;