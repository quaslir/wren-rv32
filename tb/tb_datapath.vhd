library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_datapath is
    generic(
        N_RANDOM : natural  := 8000;
        SEED1    : positive := 19;
        SEED2    : positive := 23
    );
end entity tb_datapath;

architecture sim of tb_datapath is
    constant T : time := 10 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal pc_src     : std_logic := '0';
    signal alu_src    : std_logic := '0';
    signal reg_write  : std_logic := '0';
    signal imm_src    : std_logic_vector(2 downto 0) := "000";
    signal alu_op     : std_logic_vector(3 downto 0) := "0000";
    signal instr      : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_result : std_logic_vector(31 downto 0);
    signal zero       : std_logic;
    signal pc         : std_logic_vector(31 downto 0);
    signal result_src : std_logic_vector(1 downto 0) := "00";
    signal read_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data : std_logic_vector(31 downto 0);
    signal done       : boolean := false;

    type op_arr_t is array (natural range <>) of std_logic_vector(3 downto 0);
    constant OPS : op_arr_t := ("0000", "1000", "0001", "0010", "0011", "0100", "0101", "1101", "0110", "0111");

    function ref_alu(x, y : std_logic_vector(31 downto 0); op : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable sh : natural := to_integer(unsigned(y(4 downto 0)));
    begin
        case op is
            when "0000" => return std_logic_vector(unsigned(x) + unsigned(y));
            when "1000" => return std_logic_vector(unsigned(x) - unsigned(y));
            when "0001" => return std_logic_vector(shift_left(unsigned(x), sh));
            when "0010" =>
                if signed(x) < signed(y) then return x"00000001"; else return x"00000000"; end if;
            when "0011" =>
                if unsigned(x) < unsigned(y) then return x"00000001"; else return x"00000000"; end if;
            when "0100" => return x xor y;
            when "0101" => return std_logic_vector(shift_right(unsigned(x), sh));
            when "1101" => return std_logic_vector(shift_right(signed(x), sh));
            when "0110" => return x or y;
            when "0111" => return x and y;
            when others => return x"00000000";
        end case;
    end function;

    function ref_ext(v : std_logic_vector(31 downto 0); src : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        case src is
            when "000"  => return (31 downto 12 => v(31)) & v(31 downto 20);
            when "001"  => return (31 downto 12 => v(31)) & v(31 downto 25) & v(11 downto 7);
            when "010"  => return (31 downto 12 => v(31)) & v(7) & v(30 downto 25) & v(11 downto 8) & '0';
            when others => return x"00000000";
        end case;
    end function;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut : entity work.datapath
        port map(
            clk        => clk,
            rst        => rst,
            pc_src     => pc_src,
            alu_src    => alu_src,
            reg_write  => reg_write,
            imm_src    => imm_src,
            alu_op     => alu_op,
            instr      => instr,
            alu_result => alu_result,
            zero       => zero,
            pc         => pc,
            result_src => result_src,
            read_data  => read_data,
            write_data => write_data
        );

    stim : process
        type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
        type valid_t is array (0 to 31) of boolean;
        type cnt4_t is array (0 to 3) of natural;
        variable regs    : regs_t := (others => (others => '0'));
        variable valid   : valid_t := (0 => true, others => false);
        variable m_pc    : unsigned(31 downto 0) := (others => '0');
        variable errors  : natural := 0;
        variable checks  : natural := 0;
        variable cycles  : natural := 0;
        variable n_rst   : natural := 0;
        variable n_jump  : natural := 0;
        variable n_res   : cnt4_t := (others => 0);
        variable s1      : positive := SEED1;
        variable s2      : positive := SEED2;
        variable r       : real;

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
                report "cycle " & integer'image(cycles) & " instr=0x" & to_hstring(instr) & " op=" & to_string(alu_op) &
                       " src=" & std_logic'image(alu_src) & " imm_src=" & to_string(imm_src) &
                       " res_src=" & to_string(result_src) & ": " & msg severity error;
            end if;
        end procedure;

        procedure step(v       : std_logic_vector(31 downto 0);
                       op      : std_logic_vector(3 downto 0);
                       isrc    : std_logic_vector(2 downto 0);
                       asrc    : std_logic;
                       rw      : std_logic;
                       rsrc    : std_logic_vector(1 downto 0);
                       psrc    : std_logic;
                       rdata   : std_logic_vector(31 downto 0);
                       do_rst  : std_logic) is
            variable rs1, rs2, rd : natural;
            variable a, b, imm   : std_logic_vector(31 downto 0);
            variable exp, res    : std_logic_vector(31 downto 0);
            variable pc4         : std_logic_vector(31 downto 0);
            variable known       : boolean;
        begin
            wait until falling_edge(clk);
            instr      <= v;
            alu_op     <= op;
            imm_src    <= isrc;
            alu_src    <= asrc;
            reg_write  <= rw;
            result_src <= rsrc;
            pc_src     <= psrc;
            read_data  <= rdata;
            rst        <= do_rst;
            wait for 1 ns;
            cycles := cycles + 1;

            rs1 := to_integer(unsigned(v(19 downto 15)));
            rs2 := to_integer(unsigned(v(24 downto 20)));
            rd  := to_integer(unsigned(v(11 downto 7)));
            imm := ref_ext(v, isrc);
            a   := regs(rs1);
            if asrc = '1' then
                b := imm;
                known := valid(rs1);
            else
                b := regs(rs2);
                known := valid(rs1) and valid(rs2);
            end if;
            exp := ref_alu(a, b, op);
            pc4 := std_logic_vector(m_pc + 4);

            checks := checks + 1;
            if pc /= std_logic_vector(m_pc) then
                fail("pc got=0x" & to_hstring(pc) & " expected=0x" & to_hstring(m_pc));
            end if;
            if known then
                checks := checks + 2;
                if alu_result /= exp then
                    fail("alu_result got=0x" & to_hstring(alu_result) & " expected=0x" & to_hstring(exp) &
                         " (a=0x" & to_hstring(a) & " b=0x" & to_hstring(b) & ")");
                end if;
                if (exp = x"00000000") /= (zero = '1') then
                    fail("zero=" & std_logic'image(zero) & " for result 0x" & to_hstring(exp));
                end if;
            end if;
            if valid(rs2) then
                checks := checks + 1;
                if write_data /= regs(rs2) then
                    fail("write_data got=0x" & to_hstring(write_data) & " expected x" & integer'image(rs2) &
                         "=0x" & to_hstring(regs(rs2)));
                end if;
            end if;

            case rsrc is
                when "00"   => res := exp;
                when "01"   => res := rdata;
                when "10"   => res := pc4;
                when others => res := imm;
            end case;
            n_res(to_integer(unsigned(rsrc))) := n_res(to_integer(unsigned(rsrc))) + 1;

            wait until rising_edge(clk);
            wait for 1 ns;

            if rw = '1' and rd /= 0 then
                regs(rd) := res;
                valid(rd) := known or rsrc /= "00";
            end if;
            if do_rst = '1' then
                m_pc := (others => '0');
                n_rst := n_rst + 1;
            elsif psrc = '1' then
                m_pc := m_pc + unsigned(imm);
                n_jump := n_jump + 1;
            else
                m_pc := m_pc + 4;
            end if;
            checks := checks + 1;
            if pc /= std_logic_vector(m_pc) then
                fail("pc after edge got=0x" & to_hstring(pc) & " expected=0x" & to_hstring(m_pc));
            end if;
        end procedure;

        function i_word(rs1, rd : natural; imm12 : std_logic_vector(11 downto 0)) return std_logic_vector is
        begin
            return imm12 & std_logic_vector(to_unsigned(rs1, 5)) & "000" & std_logic_vector(to_unsigned(rd, 5)) & "0010011";
        end function;

        function r_word(rs2, rs1, rd : natural) return std_logic_vector is
        begin
            return "0000000" & std_logic_vector(to_unsigned(rs2, 5)) & std_logic_vector(to_unsigned(rs1, 5)) & "000" &
                   std_logic_vector(to_unsigned(rd, 5)) & "0110011";
        end function;

        procedure sweep is
        begin
            for i in 0 to 31 loop
                step(r_word(0, i, 0), "0000", "000", '0', '0', "00", '0', rnd_word, '0');
                step(r_word(i, 0, 0), "0000", "000", '0', '0', "00", '0', rnd_word, '0');
            end loop;
        end procedure;

        variable v    : std_logic_vector(31 downto 0);
        variable op   : std_logic_vector(3 downto 0);
        variable isrc : std_logic_vector(2 downto 0);
        variable rsrc : std_logic_vector(1 downto 0);
        variable asrc, rw, psrc, rs : std_logic;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        m_pc := (others => '0');

        step(x"00000000", "0000", "000", '0', '1', "01", '0', x"DEADBEEF", '1');
        for i in 1 to 31 loop
            step(i_word(0, i, x"000"), "0000", "000", '1', '1', "01", '0', rnd_word, '0');
        end loop;
        step(i_word(0, 0, x"7FF"), "0000", "000", '1', '1', "01", '0', x"FFFFFFFF", '0');
        sweep;

        step(i_word(0, 1, x"7FF"), "0000", "000", '1', '1', "00", '0', rnd_word, '0');
        step(i_word(0, 2, x"800"), "0000", "000", '1', '1', "00", '0', rnd_word, '0');
        step(r_word(2, 1, 3), "1000", "000", '0', '1', "00", '0', rnd_word, '0');
        step(r_word(1, 1, 4), "1000", "000", '0', '1', "00", '0', rnd_word, '0');
        step(i_word(0, 5, x"123"), "0000", "000", '1', '1', "10", '0', rnd_word, '0');
        step(i_word(0, 6, x"FFF"), "0000", "000", '1', '1', "11", '0', rnd_word, '0');
        step(i_word(0, 7, x"001"), "0000", "001", '1', '1', "11", '0', rnd_word, '0');
        step(x"FE000FE3", "1000", "010", '0', '0', "00", '1', rnd_word, '0');
        step(x"00000463", "1000", "010", '0', '0', "00", '1', rnd_word, '0');
        step(x"80000063", "1000", "010", '0', '0', "00", '1', rnd_word, '0');
        step(x"7E000FE3", "1000", "010", '0', '0', "00", '1', rnd_word, '0');
        step(i_word(0, 8, x"7FF"), "0000", "000", '1', '1', "00", '1', rnd_word, '0');
        step(i_word(0, 9, x"000"), "0000", "000", '1', '1', "01", '0', x"80000000", '1');
        sweep;

        for n in 1 to N_RANDOM loop
            v := rnd_word;
            if rnd(6) = 0 then
                v(19 downto 15) := v(24 downto 20);
            end if;
            op := OPS(rnd(OPS'length));
            isrc := std_logic_vector(to_unsigned(rnd(3), 3));
            rsrc := std_logic_vector(to_unsigned(rnd(4), 2));
            if rnd(2) = 0 then asrc := '0'; else asrc := '1'; end if;
            if rnd(4) = 0 then rw := '0'; else rw := '1'; end if;
            if rnd(5) = 0 then psrc := '1'; else psrc := '0'; end if;
            if rnd(50) = 0 then rs := '1'; rw := '0'; else rs := '0'; end if;
            step(v, op, isrc, asrc, rw, rsrc, psrc, rnd_word, rs);
            if n mod 2000 = 0 then
                sweep;
            end if;
        end loop;
        sweep;

        report "tb_datapath: " & integer'image(cycles) & " cycles, " & integer'image(checks) & " checks, result_src 00/01/10/11 = " &
               integer'image(n_res(0)) & "/" & integer'image(n_res(1)) & "/" & integer'image(n_res(2)) & "/" &
               integer'image(n_res(3)) & ", jumps " & integer'image(n_jump) & ", resets " & integer'image(n_rst) & ", " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_datapath FAILED" severity failure;
        report "tb_datapath PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;