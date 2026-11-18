library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_alu is
    generic(
        N_RANDOM : natural  := 20000;
        SEED1    : positive := 101;
        SEED2    : positive := 7
    );
end entity tb_alu;

architecture sim of tb_alu is
    signal a           : std_logic_vector(31 downto 0) := (others => '0');
    signal b           : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_control : std_logic_vector(3 downto 0)  := (others => '0');
    signal result      : std_logic_vector(31 downto 0);
    signal zero        : std_logic;

    type op_arr_t is array (natural range <>) of std_logic_vector(3 downto 0);
    constant OPS : op_arr_t := ("0000", "1000", "0001", "0010", "0011", "0100", "0101", "1101", "0110", "0111");

    type word_arr_t is array (natural range <>) of std_logic_vector(31 downto 0);
    constant EDGE : word_arr_t := (
        x"00000000", x"00000001", x"00000002", x"0000001F", x"00000020", x"00000021",
        x"7FFFFFFF", x"80000000", x"80000001", x"FFFFFFFF", x"FFFFFFFE", x"FFFFFFE0",
        x"55555555", x"AAAAAAAA", x"0000FFFF", x"FFFF0000", x"12345678", x"FEDCBA98"
    );

    function ref_alu(x, y : std_logic_vector(31 downto 0); op : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable sh : natural := to_integer(unsigned(y(4 downto 0)));
        variable r  : std_logic_vector(31 downto 0) := (others => '0');
    begin
        case op is
            when "0000" => r := std_logic_vector(unsigned(x) + unsigned(y));
            when "1000" => r := std_logic_vector(unsigned(x) - unsigned(y));
            when "0001" =>
                for i in 31 downto 0 loop
                    if i - sh >= 0 then
                        r(i) := x(i - sh);
                    else
                        r(i) := '0';
                    end if;
                end loop;
            when "0101" =>
                for i in 0 to 31 loop
                    if i + sh <= 31 then
                        r(i) := x(i + sh);
                    else
                        r(i) := '0';
                    end if;
                end loop;
            when "1101" =>
                for i in 0 to 31 loop
                    if i + sh <= 31 then
                        r(i) := x(i + sh);
                    else
                        r(i) := x(31);
                    end if;
                end loop;
            when "0010" =>
                if to_integer(signed(x(31 downto 16))) < to_integer(signed(y(31 downto 16))) or
                   (x(31 downto 16) = y(31 downto 16) and unsigned(x(15 downto 0)) < unsigned(y(15 downto 0))) then
                    r := x"00000001";
                end if;
            when "0011" =>
                if unsigned(x(31 downto 16)) < unsigned(y(31 downto 16)) or
                   (x(31 downto 16) = y(31 downto 16) and unsigned(x(15 downto 0)) < unsigned(y(15 downto 0))) then
                    r := x"00000001";
                end if;
            when "0100" => r := x xor y;
            when "0110" => r := x or y;
            when "0111" => r := x and y;
            when others => r := (others => '-');
        end case;
        return r;
    end function;

    function op_name(op : std_logic_vector(3 downto 0)) return string is
    begin
        case op is
            when "0000" => return "ADD";
            when "1000" => return "SUB";
            when "0001" => return "SLL";
            when "0010" => return "SLT";
            when "0011" => return "SLTU";
            when "0100" => return "XOR";
            when "0101" => return "SRL";
            when "1101" => return "SRA";
            when "0110" => return "OR";
            when "0111" => return "AND";
            when others => return "op" & to_string(op);
        end case;
    end function;
begin
    dut : entity work.alu
        port map(
            a           => a,
            b           => b,
            alu_control => alu_control,
            result      => result,
            zero        => zero
        );

    stim : process
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable n_zero : natural := 0;
        variable s1     : positive := SEED1;
        variable s2     : positive := SEED2;
        variable r      : real;
        variable x, y   : std_logic_vector(31 downto 0);
        variable op     : std_logic_vector(3 downto 0);

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

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report op_name(alu_control) & " a=0x" & to_hstring(a) & " b=0x" & to_hstring(b) & ": " & msg
                    severity error;
            end if;
        end procedure;

        procedure check(xv, yv : std_logic_vector(31 downto 0); opv : std_logic_vector(3 downto 0)) is
            variable exp : std_logic_vector(31 downto 0);
            variable ok  : boolean := true;
        begin
            a           <= xv;
            b           <= yv;
            alu_control <= opv;
            wait for 1 ns;
            checks := checks + 1;
            exp := ref_alu(xv, yv, opv);
            if is_x(result) or is_x(zero) then
                fail("undefined output result=0x" & to_hstring(result) & " zero=" & std_logic'image(zero));
                return;
            end if;
            for i in 0 to 31 loop
                if exp(i) /= '-' and result(i) /= exp(i) then
                    ok := false;
                end if;
            end loop;
            if not ok then
                fail("result got=0x" & to_hstring(result) & " expected=0x" & to_hstring(exp));
            end if;
            checks := checks + 1;
            if (result = x"00000000") /= (zero = '1') then
                fail("zero=" & std_logic'image(zero) & " but result=0x" & to_hstring(result));
            end if;
            if zero = '1' then
                n_zero := n_zero + 1;
            end if;
        end procedure;
    begin
        check(x"00000005", x"00000003", "0000");
        check(x"00000005", x"00000005", "1000");
        check(x"00000000", x"00000001", "1000");
        check(x"80000000", x"00000001", "1000");
        check(x"FFFFFFFF", x"00000001", "0000");
        check(x"7FFFFFFF", x"00000001", "0000");
        check(x"00000001", x"0000001F", "0001");
        check(x"00000001", x"00000020", "0001");
        check(x"00000001", x"00000021", "0001");
        check(x"80000000", x"0000001F", "0101");
        check(x"80000000", x"0000001F", "1101");
        check(x"80000000", x"FFFFFFE1", "1101");
        check(x"7FFFFFFF", x"00000004", "1101");
        check(x"FFFFFFFF", x"00000001", "0010");
        check(x"FFFFFFFF", x"00000001", "0011");
        check(x"00000001", x"FFFFFFFF", "0010");
        check(x"00000001", x"FFFFFFFF", "0011");
        check(x"80000000", x"7FFFFFFF", "0010");
        check(x"80000000", x"7FFFFFFF", "0011");
        check(x"12345678", x"12345678", "0010");
        check(x"12345678", x"12345678", "0011");
        check(x"F0F0F0F0", x"FF00FF00", "0100");
        check(x"F0F0F0F0", x"FF00FF00", "0110");
        check(x"F0F0F0F0", x"FF00FF00", "0111");
        check(x"AAAAAAAA", x"55555555", "0111");
        check(x"AAAAAAAA", x"AAAAAAAA", "0100");

        for k in OPS'range loop
            for i in EDGE'range loop
                for j in EDGE'range loop
                    check(EDGE(i), EDGE(j), OPS(k));
                end loop;
            end loop;
            for sh in 0 to 63 loop
                check(x"80000001", std_logic_vector(to_unsigned(sh, 32)), OPS(k));
                check(x"7FFFFFFE", x"FFFFFFC0" or std_logic_vector(to_unsigned(sh, 32)), OPS(k));
            end loop;
        end loop;

        for op_i in 0 to 15 loop
            for i in EDGE'range loop
                check(EDGE(i), EDGE(EDGE'high - i), std_logic_vector(to_unsigned(op_i, 4)));
            end loop;
        end loop;

        for n in 1 to N_RANDOM loop
            op := OPS(rnd(OPS'length));
            x  := rnd_word;
            case rnd(8) is
                when 0      => y := x;
                when 1      => y := std_logic_vector(unsigned(x) + 1);
                when 2      => y := std_logic_vector(unsigned(x) - 1);
                when 3      => y := x xor x"80000000";
                when others => y := rnd_word;
            end case;
            check(x, y, op);
        end loop;

        report "tb_alu: " & integer'image(checks) & " checks, " & integer'image(n_zero) & " with zero=1, " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_alu FAILED" severity failure;
        report "tb_alu PASSED";
        std.env.finish;
    end process;
end architecture sim;