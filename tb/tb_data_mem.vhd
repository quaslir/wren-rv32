library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_data_mem is
    generic(
        DEPTH    : positive := 64;
        N_RANDOM : natural := 5000
    );
end entity tb_data_mem;

architecture sim of tb_data_mem is
    constant CLK_PERIOD : time := 10 ns;

    signal clk  : std_logic := '0';
    signal we   : std_logic := '0';
    signal addr : std_logic_vector(31 downto 0) := (others => '0');
    signal wd   : std_logic_vector(31 downto 0) := (others => '0');
    signal rd   : std_logic_vector(31 downto 0);
    signal done : boolean := false;

    type model_t is array (0 to DEPTH - 1) of std_logic_vector(31 downto 0);
begin
    dut : entity work.data_mem
        generic map(
            DEPTH => DEPTH
        )
        port map(
            clk  => clk,
            we   => we,
            addr => addr,
            wd   => wd,
            rd   => rd
        );

    clk <= not clk after CLK_PERIOD / 2 when not done;

    stim : process
        variable model : model_t := (others => (others => '0'));
        variable err   : natural := 0;
        variable cnt   : natural := 0;
        variable s1    : positive := 3;
        variable s2    : positive := 99;
        variable r     : real;
        variable a     : std_logic_vector(31 downto 0);
        variable d     : std_logic_vector(31 downto 0);
        variable w     : std_logic;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n)));
        end function;

        impure function rnd_word return std_logic_vector is
            variable x : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 31 loop
                if rnd(2) = 1 then x(i) := '1'; else x(i) := '0'; end if;
            end loop;
            return x;
        end function;

        function word_of(x : std_logic_vector(31 downto 0)) return natural is
        begin
            if unsigned(x(31 downto 2)) < DEPTH then
                return to_integer(unsigned(x(31 downto 2)));
            else
                return DEPTH;
            end if;
        end function;

        impure function expected(x : std_logic_vector(31 downto 0)) return std_logic_vector is
        begin
            if word_of(x) < DEPTH then
                return model(word_of(x));
            else
                return x"00000000";
            end if;
        end function;

        procedure fail(msg : string) is
        begin
            if err < 20 then
                report "FAIL #" & integer'image(cnt) & ": " & msg severity error;
            end if;
            err := err + 1;
        end procedure;

        procedure check_read(x : std_logic_vector(31 downto 0)) is
        begin
            we   <= '0';
            addr <= x;
            wait for 1 ns;
            cnt := cnt + 1;
            if rd /= expected(x) then
                fail("read addr=0x" & to_hstring(x) & " got=0x" & to_hstring(rd) & " expected=0x" & to_hstring(expected(x)));
            end if;
        end procedure;

        procedure cycle(x, data : std_logic_vector(31 downto 0); wen : std_logic) is
        begin
            wait until falling_edge(clk);
            we   <= wen;
            addr <= x;
            wd   <= data;
            wait for 1 ns;
            cnt := cnt + 1;
            if rd /= expected(x) then
                fail("before edge addr=0x" & to_hstring(x) & " got=0x" & to_hstring(rd) & " expected old=0x" & to_hstring(expected(x)));
            end if;
            wait until rising_edge(clk);
            if wen = '1' and word_of(x) < DEPTH then
                model(word_of(x)) := data;
            end if;
            wait for 1 ns;
            if rd /= expected(x) then
                fail("after edge addr=0x" & to_hstring(x) & " got=0x" & to_hstring(rd) & " expected=0x" & to_hstring(expected(x)));
            end if;
        end procedure;
    begin
        for i in 0 to DEPTH - 1 loop
            check_read(std_logic_vector(to_unsigned(4 * i, 32)));
        end loop;

        for i in 0 to DEPTH - 1 loop
            cycle(std_logic_vector(to_unsigned(4 * i, 32)), std_logic_vector(to_unsigned(16#1000# + i, 32)), '1');
        end loop;
        for i in 0 to DEPTH - 1 loop
            check_read(std_logic_vector(to_unsigned(4 * i, 32)));
        end loop;

        cycle(x"00000008", x"DEADBEEF", '0');
        check_read(x"00000008");

        cycle(x"0000000D", x"CAFEBABE", '1');
        check_read(x"0000000C");
        check_read(x"0000000F");

        cycle(std_logic_vector(to_unsigned(4 * DEPTH, 32)), x"11111111", '1');
        check_read(x"00000000");
        check_read(std_logic_vector(to_unsigned(4 * DEPTH, 32)));
        cycle(x"80000000", x"22222222", '1');
        cycle(x"80000004", x"33333333", '1');
        cycle(x"FFFFFFFC", x"44444444", '1');
        for i in 0 to DEPTH - 1 loop
            check_read(std_logic_vector(to_unsigned(4 * i, 32)));
        end loop;
        check_read(x"80000000");
        check_read(x"FFFFFFFC");

        for n in 1 to N_RANDOM loop
            if rnd(8) = 0 then
                a := rnd_word;
            else
                a := std_logic_vector(to_unsigned(rnd(4 * DEPTH), 32));
            end if;
            d := rnd_word;
            if rnd(2) = 1 then w := '1'; else w := '0'; end if;
            cycle(a, d, w);
        end loop;

        for i in 0 to DEPTH - 1 loop
            check_read(std_logic_vector(to_unsigned(4 * i, 32)));
        end loop;

        if err = 0 then
            report "tb_data_mem: ALL " & integer'image(cnt) & " CHECKS PASSED" severity note;
        else
            report "tb_data_mem: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;