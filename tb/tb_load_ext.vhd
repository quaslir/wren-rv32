library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_load_ext is
end entity tb_load_ext;

architecture sim of tb_load_ext is
    signal funct3    : std_logic_vector(2 downto 0)  := (others => '0');
    signal addr_lo   : std_logic_vector(1 downto 0)  := (others => '0');
    signal rd        : std_logic_vector(31 downto 0) := (others => '0');
    signal read_data : std_logic_vector(31 downto 0);

    type word_array is array (natural range <>) of std_logic_vector(31 downto 0);
    constant DIRECTED : word_array := (
        x"00000000", x"FFFFFFFF", x"804020FF", x"80000000",
        x"7FFFFFFF", x"0000007F", x"00000080", x"00007FFF",
        x"00008000", x"7F807F80", x"807F807F", x"8000FFFF",
        x"FFFF8000", x"12345678", x"DEADBEEF", x"01020304"
    );
    constant RANDOM_PER_CASE : natural := 500;

    function ref_load(f : std_logic_vector(2 downto 0);
                      a : std_logic_vector(1 downto 0);
                      w : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable b : std_logic_vector(7 downto 0);
        variable h : std_logic_vector(15 downto 0);
        variable i : natural;
    begin
        i := to_integer(unsigned(a));
        b := w(8 * i + 7 downto 8 * i);
        if a(1) = '0' then
            h := w(15 downto 0);
        else
            h := w(31 downto 16);
        end if;
        case f is
            when "000"  => return std_logic_vector(resize(signed(b), 32));
            when "100"  => return std_logic_vector(resize(unsigned(b), 32));
            when "001"  => return std_logic_vector(resize(signed(h), 32));
            when "101"  => return std_logic_vector(resize(unsigned(h), 32));
            when "010"  => return w;
            when others => return w;
        end case;
    end function;

    function is_legal(f : std_logic_vector(2 downto 0)) return boolean is
    begin
        return f = "000" or f = "001" or f = "010" or f = "100" or f = "101";
    end function;
begin
    dut : entity work.load_ext
        port map(
            funct3    => funct3,
            addr_lo   => addr_lo,
            rd        => rd,
            read_data => read_data
        );

    stim : process
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable seed1  : positive := 13;
        variable seed2  : positive := 101;
        variable r      : real;
        variable rnd    : std_logic_vector(31 downto 0);

        procedure check(f : std_logic_vector(2 downto 0);
                        a : std_logic_vector(1 downto 0);
                        w : std_logic_vector(31 downto 0)) is
            variable expected : std_logic_vector(31 downto 0);
        begin
            funct3  <= f;
            addr_lo <= a;
            rd      <= w;
            wait for 1 ns;
            checks := checks + 1;
            if is_legal(f) then
                expected := ref_load(f, a, w);
                if read_data /= expected then
                    errors := errors + 1;
                    report "mismatch: funct3=" & to_string(f) & " addr_lo=" & to_string(a) &
                           " rd=0x" & to_hstring(w) & " got=0x" & to_hstring(read_data) &
                           " expected=0x" & to_hstring(expected) severity error;
                end if;
            elsif is_x(read_data) then
                errors := errors + 1;
                report "undefined output for illegal funct3=" & to_string(f) &
                       " addr_lo=" & to_string(a) & " got=0x" & to_hstring(read_data)
                       severity error;
            end if;
        end procedure;

        procedure check_case(f : std_logic_vector(2 downto 0);
                             a : std_logic_vector(1 downto 0);
                             w : std_logic_vector(31 downto 0);
                             expected : std_logic_vector(31 downto 0)) is
        begin
            funct3  <= f;
            addr_lo <= a;
            rd      <= w;
            wait for 1 ns;
            checks := checks + 1;
            if read_data /= expected then
                errors := errors + 1;
                report "directed: funct3=" & to_string(f) & " addr_lo=" & to_string(a) &
                       " rd=0x" & to_hstring(w) & " got=0x" & to_hstring(read_data) &
                       " expected=0x" & to_hstring(expected) severity error;
            end if;
        end procedure;
    begin
        check_case("000", "00", x"804020FF", x"FFFFFFFF");
        check_case("100", "00", x"804020FF", x"000000FF");
        check_case("000", "01", x"804020FF", x"00000020");
        check_case("100", "01", x"804020FF", x"00000020");
        check_case("000", "10", x"804020FF", x"00000040");
        check_case("000", "11", x"804020FF", x"FFFFFF80");
        check_case("100", "11", x"804020FF", x"00000080");
        check_case("001", "00", x"804020FF", x"000020FF");
        check_case("101", "00", x"804020FF", x"000020FF");
        check_case("001", "10", x"804020FF", x"FFFF8040");
        check_case("101", "10", x"804020FF", x"00008040");
        check_case("010", "00", x"804020FF", x"804020FF");
        check_case("000", "01", x"7F807F80", x"0000007F");
        check_case("000", "00", x"7F807F80", x"FFFFFF80");
        check_case("001", "00", x"8000FFFF", x"FFFFFFFF");
        check_case("001", "10", x"0000FFFF", x"00000000");
        check_case("001", "01", x"804020FF", x"000020FF");
        check_case("001", "11", x"804020FF", x"FFFF8040");
        check_case("010", "11", x"804020FF", x"804020FF");

        for f in 0 to 7 loop
            for a in 0 to 3 loop
                for k in DIRECTED'range loop
                    check(std_logic_vector(to_unsigned(f, 3)),
                          std_logic_vector(to_unsigned(a, 2)),
                          DIRECTED(k));
                end loop;
                for k in 1 to RANDOM_PER_CASE loop
                    for b in 0 to 3 loop
                        uniform(seed1, seed2, r);
                        rnd(8 * b + 7 downto 8 * b) :=
                            std_logic_vector(to_unsigned(integer(floor(r * 256.0)) mod 256, 8));
                    end loop;
                    check(std_logic_vector(to_unsigned(f, 3)),
                          std_logic_vector(to_unsigned(a, 2)),
                          rnd);
                end loop;
            end loop;
        end loop;

        report "tb_load_ext: " & integer'image(checks) & " checks, " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_load_ext FAILED" severity failure;
        report "tb_load_ext PASSED";
        std.env.finish;
    end process;
end architecture sim;