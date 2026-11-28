library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_pc_reg is
    generic(
        N_RANDOM : natural := 5000
    );
end entity tb_pc_reg;

architecture sim of tb_pc_reg is
    constant T : time := 10 ns;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal en        : std_logic := '1';
    signal next_pc   : std_logic_vector(31 downto 0) := (others => '0');
    signal pc        : std_logic_vector(31 downto 0);
    signal next_pc_n : std_logic_vector(7 downto 0) := (others => '0');
    signal pc_n      : std_logic_vector(7 downto 0);
    signal done      : boolean := false;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut_w : entity work.pc_reg
        generic map(WIDTH => 32)
        port map(clk => clk, rst => rst, en => en, next_pc => next_pc, pc => pc);

    dut_n : entity work.pc_reg
        generic map(WIDTH => 8)
        port map(clk => clk, rst => rst, en => en, next_pc => next_pc_n, pc => pc_n);

    stim : process
        variable errors  : natural := 0;
        variable checks  : natural := 0;
        variable s1      : positive := 77;
        variable s2      : positive := 88;
        variable r       : real;
        variable model   : std_logic_vector(31 downto 0) := (others => '0');
        variable model_n : std_logic_vector(7 downto 0) := (others => '0');
        variable w       : std_logic_vector(31 downto 0);
        variable rv, ev  : std_logic;
        variable n_rst   : natural := 0;
        variable n_hold  : natural := 0;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        impure function rnd_word return std_logic_vector is
            variable v : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 3 loop
                v(8 * i + 7 downto 8 * i) := std_logic_vector(to_unsigned(rnd(256), 8));
            end loop;
            return v;
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "@" & time'image(now) & ": " & msg severity error;
            end if;
        end procedure;

        procedure expect(tag : string) is
        begin
            checks := checks + 1;
            if pc /= model then
                fail(tag & " WIDTH=32 pc=0x" & to_hstring(pc) & " expected=0x" & to_hstring(model));
            end if;
            checks := checks + 1;
            if pc_n /= model_n then
                fail(tag & " WIDTH=8 pc=0x" & to_hstring(pc_n) & " expected=0x" & to_hstring(model_n));
            end if;
        end procedure;

        procedure cycle(nv : std_logic_vector(31 downto 0); rs, e : std_logic; tag : string) is
        begin
            wait until falling_edge(clk);
            next_pc   <= nv;
            next_pc_n <= nv(7 downto 0);
            rst       <= rs;
            en        <= e;
            wait for T / 4;
            expect(tag & " before edge");
            wait until rising_edge(clk);
            wait for 1 ns;
            if rs = '1' then
                model   := (others => '0');
                model_n := (others => '0');
            elsif e = '1' then
                model   := nv;
                model_n := nv(7 downto 0);
            end if;
            expect(tag & " after edge");
            wait for T / 4;
            expect(tag & " mid cycle");
        end procedure;
    begin
        rst <= '1';
        en <= '1';
        next_pc <= x"DEADBEEF";
        next_pc_n <= x"EF";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        expect("reset");

        cycle(x"00000004", '0', '1', "first step");
        cycle(x"FFFFFFFF", '0', '1', "all ones");
        cycle(x"FFFFFFFF", '1', '1', "reset priority over next_pc");
        cycle(x"80000000", '0', '1', "msb");
        cycle(x"00000000", '0', '1', "zero");
        cycle(x"12345678", '0', '1', "pattern");
        cycle(x"CAFEBABE", '0', '0', "en=0 holds");
        cycle(x"00000000", '0', '0', "en=0 holds 2");
        cycle(x"FFFFFFFF", '0', '0', "en=0 holds 3");
        cycle(x"FFFFFFFF", '1', '0', "reset priority over en=0");
        cycle(x"ABCDEF01", '0', '0', "en=0 after reset");
        cycle(x"ABCDEF01", '0', '1', "en=1 again");

        wait until falling_edge(clk);
        rst <= '1';
        en <= '1';
        next_pc <= x"CAFEBABE";
        next_pc_n <= x"BE";
        wait for 1 ns;
        expect("sync reset: no change before edge");
        wait until rising_edge(clk);
        wait for 1 ns;
        model := (others => '0');
        model_n := (others => '0');
        expect("sync reset: zero after edge");
        wait until falling_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        model := x"CAFEBABE";
        model_n := x"BE";
        expect("release reset");

        for n in 1 to N_RANDOM loop
            w := rnd_word;
            if rnd(20) = 0 then rv := '1'; n_rst := n_rst + 1; else rv := '0'; end if;
            if rnd(4) = 0 then ev := '0'; n_hold := n_hold + 1; else ev := '1'; end if;
            cycle(w, rv, ev, "random");
        end loop;

        report "tb_pc_reg: " & integer'image(checks) & " checks, " & integer'image(n_rst) & " random resets, "
            & integer'image(n_hold) & " holds, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_pc_reg FAILED" severity failure;
        report "tb_pc_reg PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;