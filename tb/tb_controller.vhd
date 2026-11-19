library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_controller is
    generic(
        SEED1 : positive := 17;
        SEED2 : positive := 43
    );
end entity tb_controller;

architecture sim of tb_controller is
    signal instr      : std_logic_vector(31 downto 0) := (others => '0');
    signal zero       : std_logic := '0';
    signal addr_lo    : std_logic_vector(1 downto 0) := "00";
    signal misaligned : std_logic;
    signal jalr       : std_logic;
    signal alu_src_a  : std_logic;
    signal reg_write  : std_logic;
    signal alu_src    : std_logic;
    signal illegal    : std_logic;
    signal pc_src     : std_logic;
    signal alu_op     : std_logic_vector(3 downto 0);
    signal imm_src    : std_logic_vector(2 downto 0);
    signal mem_write  : std_logic;
    signal result_src : std_logic_vector(1 downto 0);

    constant OP_R : std_logic_vector(6 downto 0) := "0110011";
    constant OP_I : std_logic_vector(6 downto 0) := "0010011";
    constant OP_B : std_logic_vector(6 downto 0) := "1100011";
    constant OP_L : std_logic_vector(6 downto 0) := "0000011";
    constant OP_S : std_logic_vector(6 downto 0) := "0100011";
    constant OP_J : std_logic_vector(6 downto 0) := "1101111";
    constant OP_JR : std_logic_vector(6 downto 0) := "1100111";
    constant OP_LUI : std_logic_vector(6 downto 0) := "0110111";
    constant OP_AUIPC : std_logic_vector(6 downto 0) := "0010111";

    type ctrl_t is record
        reg_write   : std_logic;
        alu_src     : std_logic;
        illegal     : std_logic;
        branch      : std_logic;
        mem_write   : std_logic;
        mem_access  : std_logic;
        jump        : std_logic;
        jalr        : std_logic;
        alu_op      : std_logic_vector(3 downto 0);
        imm_src     : std_logic_vector(2 downto 0);
        result_src  : std_logic_vector(1 downto 0);
        c_alu_src   : boolean;
        c_alu_op    : boolean;
        c_imm_src   : boolean;
        c_result    : boolean;
        alu_src_a   : std_logic;
        c_srca      : boolean;
    end record;

    constant ILLEGAL_CTRL : ctrl_t := (
        reg_write => '0', alu_src => '-', illegal => '1', branch => '0',
        mem_write => '0', mem_access => '0', jump => '0', jalr => '0', alu_op => "----", imm_src => "---",
        result_src => "--", c_alu_src => false, c_alu_op => false,
        c_imm_src => false, c_result => false, alu_src_a => '-', c_srca => false
    );

    function ref_ctrl(v : std_logic_vector(31 downto 0)) return ctrl_t is
        variable op : std_logic_vector(6 downto 0) := v(6 downto 0);
        variable f3 : std_logic_vector(2 downto 0) := v(14 downto 12);
        variable f7 : std_logic_vector(6 downto 0) := v(31 downto 25);
        variable c  : ctrl_t := ILLEGAL_CTRL;
    begin
        if op = OP_R then
            if f7 = "0000000" or (f7 = "0100000" and (f3 = "000" or f3 = "101")) then
                c := ('1', '0', '0', '0', '0', '0', '0', '0', f7(5) & f3, "---", "00", true, true, false, true, '0', true);
            end if;
        elsif op = OP_I then
            if f3 = "001" then
                if f7 = "0000000" then
                    c := ('1', '1', '0', '0', '0', '0', '0', '0', "0001", "000", "00", true, true, true, true, '0', true);
                end if;
            elsif f3 = "101" then
                if f7 = "0000000" then
                    c := ('1', '1', '0', '0', '0', '0', '0', '0', "0101", "000", "00", true, true, true, true, '0', true);
                elsif f7 = "0100000" then
                    c := ('1', '1', '0', '0', '0', '0', '0', '0', "1101", "000", "00", true, true, true, true, '0', true);
                end if;
            else
                c := ('1', '1', '0', '0', '0', '0', '0', '0', '0' & f3, "000", "00", true, true, true, true, '0', true);
            end if;
        elsif op = OP_B then
            case f3 is
                when "000" | "001" =>
                    c := ('0', '0', '0', '1', '0', '0', '0', '0', "1000", "010", "--", true, true, true, false, '0', true);
                when "100" | "101" =>
                    c := ('0', '0', '0', '1', '0', '0', '0', '0', "0010", "010", "--", true, true, true, false, '0', true);
                when "110" | "111" =>
                    c := ('0', '0', '0', '1', '0', '0', '0', '0', "0011", "010", "--", true, true, true, false, '0', true);
                when others =>
                    null;
            end case;
        elsif op = OP_L then
            case f3 is
                when "000" | "001" | "010" | "100" | "101" =>
                    c := ('1', '1', '0', '0', '0', '1', '0', '0', "0000", "000", "01", true, true, true, true, '0', true);
                when others =>
                    null;
            end case;
        elsif op = OP_J then
            c := ('1', '-', '0', '0', '0', '0', '1', '0', "----", "011", "10", false, false, true, true, '-', false);
        elsif op = OP_JR then
            if f3 = "000" then
                c := ('1', '-', '0', '0', '0', '0', '1', '1', "----", "000", "10", false, false, true, true, '-', false);
            end if;
        elsif op = OP_LUI then
            c := ('1', '-', '0', '0', '0', '0', '0', '0', "----", "100", "11", false, false, true, true, '-', false);
        elsif op = OP_AUIPC then
            c := ('1', '1', '0', '0', '0', '0', '0', '0', "0000", "100", "00", true, true, true, true, '1', true);
        elsif op = OP_S then
            case f3 is
                when "000" | "001" | "010" =>
                    c := ('0', '1', '0', '0', '1', '1', '0', '0', "0000", "001", "--", true, true, true, false, '0', true);
                when others =>
                    null;
            end case;
        end if;
        return c;
    end function;

    function ref_taken(v : std_logic_vector(31 downto 0); z : std_logic) return std_logic is
        variable f3 : std_logic_vector(2 downto 0) := v(14 downto 12);
    begin
        if ref_ctrl(v).jump = '1' then
            return '1';
        end if;
        if ref_ctrl(v).branch /= '1' then
            return '0';
        end if;
        case f3 is
            when "000"  => return z;
            when "001"  => return not z;
            when "100"  => return not z;
            when "101"  => return z;
            when "110"  => return not z;
            when "111"  => return z;
            when others => return '0';
        end case;
    end function;

    function ref_mis(v : std_logic_vector(31 downto 0); a : std_logic_vector(1 downto 0)) return std_logic is
    begin
        if ref_ctrl(v).mem_access /= '1' then
            return '0';
        end if;
        case v(13 downto 12) is
            when "01"   => return a(0);
            when "10"   => return a(1) or a(0);
            when others => return '0';
        end case;
    end function;

    function std_match_v(got, exp : std_logic_vector) return boolean is
    begin
        for i in got'range loop
            if exp(i) /= '-' and got(i) /= exp(i) then
                return false;
            end if;
        end loop;
        return true;
    end function;
begin
    dut : entity work.controller
        port map(
            instr      => instr,
            zero       => zero,
            addr_lo    => addr_lo,
            misaligned => misaligned,
            jalr       => jalr,
            alu_src_a  => alu_src_a,
            reg_write  => reg_write,
            alu_src    => alu_src,
            illegal    => illegal,
            pc_src     => pc_src,
            alu_op     => alu_op,
            imm_src    => imm_src,
            mem_write  => mem_write,
            result_src => result_src
        );

    stim : process
        variable errors  : natural := 0;
        variable checks  : natural := 0;
        variable n_taken : natural := 0;
        variable n_br    : natural := 0;
        variable n_mis   : natural := 0;
        variable n_jump  : natural := 0;
        variable s1      : positive := SEED1;
        variable s2      : positive := SEED2;
        variable r       : real;
        variable v       : std_logic_vector(31 downto 0);
        variable c       : ctrl_t;
        variable t       : std_logic;

        impure function rnd5 return std_logic_vector is
        begin
            uniform(s1, s2, r);
            return std_logic_vector(to_unsigned(integer(trunc(r * 32.0)) mod 32, 5));
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "instr=0x" & to_hstring(instr) & " zero=" & std_logic'image(zero) &
                       " addr_lo=" & to_string(addr_lo) & ": " & msg severity error;
            end if;
        end procedure;

        procedure chk1(name : string; got, exp : std_logic) is
        begin
            checks := checks + 1;
            if exp /= '-' and got /= exp then
                fail(name & " got=" & std_logic'image(got) & " expected=" & std_logic'image(exp));
            end if;
        end procedure;

        procedure chkv(name : string; got, exp : std_logic_vector) is
        begin
            checks := checks + 1;
            if not std_match_v(got, exp) then
                fail(name & " got=" & to_string(got) & " expected=" & to_string(exp));
            end if;
        end procedure;

        procedure check_all is
            variable m : std_logic;
        begin
            c := ref_ctrl(instr);
            t := ref_taken(instr, zero);
            m := ref_mis(instr, addr_lo);
            chk1("pc_src", pc_src, t);
            chk1("misaligned", misaligned, m);
            chk1("jalr", jalr, c.jalr);
            if c.c_srca then
                chk1("alu_src_a", alu_src_a, c.alu_src_a);
            end if;
            if c.jump = '1' then
                n_jump := n_jump + 1;
            end if;
            chk1("reg_write", reg_write, c.reg_write and not m);
            chk1("illegal", illegal, c.illegal);
            chk1("mem_write", mem_write, c.mem_write and not m);
            if m = '1' then
                n_mis := n_mis + 1;
            end if;
            if c.c_alu_src then
                chk1("alu_src", alu_src, c.alu_src);
            end if;
            if c.c_alu_op then
                chkv("alu_op", alu_op, c.alu_op);
            end if;
            if c.c_imm_src then
                chkv("imm_src", imm_src, c.imm_src);
            end if;
            if c.c_result then
                chkv("result_src", result_src, c.result_src);
            end if;
            checks := checks + 1;
            if is_x(reg_write & alu_src & illegal & pc_src & alu_op & imm_src & mem_write & result_src & misaligned & jalr & alu_src_a) then
                fail("undefined output");
            end if;
            if c.branch = '1' then
                n_br := n_br + 1;
                if t = '1' then
                    n_taken := n_taken + 1;
                end if;
            end if;
        end procedure;

        type br_t is record
            f3 : std_logic_vector(2 downto 0);
            z0 : std_logic;
            z1 : std_logic;
        end record;
        type br_arr_t is array (natural range <>) of br_t;
        constant BR_TABLE : br_arr_t := (
            ("000", '0', '1'),
            ("001", '1', '0'),
            ("100", '1', '0'),
            ("101", '0', '1'),
            ("110", '1', '0'),
            ("111", '0', '1'),
            ("010", '0', '0'),
            ("011", '0', '0')
        );
        type mis_t is record
            name : string(1 to 12);
            v    : std_logic_vector(31 downto 0);
            a    : std_logic_vector(1 downto 0);
            mis  : std_logic;
            rw   : std_logic;
            mw   : std_logic;
        end record;
        type mis_arr_t is array (natural range <>) of mis_t;
        constant MIS_TABLE : mis_arr_t := (
            ("lb  @01     ", x"00010083", "01", '0', '1', '0'),
            ("lb  @11     ", x"00010083", "11", '0', '1', '0'),
            ("lbu @11     ", x"00014083", "11", '0', '1', '0'),
            ("lh  @00     ", x"00011083", "00", '0', '1', '0'),
            ("lh  @10     ", x"00011083", "10", '0', '1', '0'),
            ("lh  @01     ", x"00011083", "01", '1', '0', '0'),
            ("lh  @11     ", x"00011083", "11", '1', '0', '0'),
            ("lhu @10     ", x"00015083", "10", '0', '1', '0'),
            ("lhu @01     ", x"00015083", "01", '1', '0', '0'),
            ("lw  @00     ", x"00012083", "00", '0', '1', '0'),
            ("lw  @01     ", x"00012083", "01", '1', '0', '0'),
            ("lw  @10     ", x"00012083", "10", '1', '0', '0'),
            ("lw  @11     ", x"00012083", "11", '1', '0', '0'),
            ("sb  @11     ", x"00310023", "11", '0', '0', '1'),
            ("sh  @10     ", x"00311023", "10", '0', '0', '1'),
            ("sh  @01     ", x"00311023", "01", '1', '0', '0'),
            ("sw  @00     ", x"00312023", "00", '0', '0', '1'),
            ("sw  @10     ", x"00312023", "10", '1', '0', '0'),
            ("sll odd     ", x"003110B3", "01", '0', '1', '0'),
            ("slt @10     ", x"003120B3", "10", '0', '1', '0'),
            ("slli odd    ", x"00111093", "11", '0', '1', '0'),
            ("sltiu @01   ", x"00113093", "01", '0', '1', '0'),
            ("bne @01     ", x"00311463", "01", '0', '0', '0'),
            ("blt @10     ", x"00314463", "10", '0', '0', '0'),
            ("load 011 @1 ", x"00013083", "01", '0', '0', '0'),
            ("jal @11     ", x"008000EF", "11", '0', '1', '0'),
            ("jalr @01    ", x"00008067", "01", '0', '1', '0'),
            ("store 011 @1", x"00313023", "01", '0', '0', '0')
        );
    begin
        for k in MIS_TABLE'range loop
            instr   <= MIS_TABLE(k).v;
            addr_lo <= MIS_TABLE(k).a;
            zero    <= '0';
            wait for 1 ns;
            checks := checks + 1;
            if misaligned /= MIS_TABLE(k).mis or reg_write /= MIS_TABLE(k).rw or mem_write /= MIS_TABLE(k).mw then
                fail(MIS_TABLE(k).name & ": misaligned=" & std_logic'image(misaligned) &
                     " reg_write=" & std_logic'image(reg_write) & " mem_write=" & std_logic'image(mem_write) &
                     " expected " & std_logic'image(MIS_TABLE(k).mis) & " " & std_logic'image(MIS_TABLE(k).rw) &
                     " " & std_logic'image(MIS_TABLE(k).mw));
            end if;
        end loop;
        addr_lo <= "00";

        for k in 0 to 3 loop
            for z in 0 to 1 loop
                case k is
                    when 0      => instr <= x"008000EF";
                    when 1      => instr <= x"FFDFF06F";
                    when 2      => instr <= x"00008067";
                    when others => instr <= x"FFF080E7";
                end case;
                if z = 0 then
                    zero <= '0';
                else
                    zero <= '1';
                end if;
                addr_lo <= "00";
                wait for 1 ns;
                checks := checks + 1;
                if pc_src /= '1' then
                    fail("jump must always set pc_src");
                end if;
                checks := checks + 1;
                if (k >= 2 and jalr /= '1') or (k < 2 and jalr /= '0') then
                    fail("jalr output wrong: " & std_logic'image(jalr));
                end if;
            end loop;
        end loop;
        instr <= x"000090E7";
        wait for 1 ns;
        checks := checks + 1;
        if pc_src /= '0' or jalr /= '0' or reg_write /= '0' then
            fail("illegal jalr funct3=001 must not jump or write");
        end if;

        for k in BR_TABLE'range loop
            for z in 0 to 1 loop
                instr <= "0000000" & "00011" & "00010" & BR_TABLE(k).f3 & "01000" & OP_B;
                if z = 0 then
                    zero <= '0';
                else
                    zero <= '1';
                end if;
                wait for 1 ns;
                checks := checks + 1;
                if (z = 0 and pc_src /= BR_TABLE(k).z0) or (z = 1 and pc_src /= BR_TABLE(k).z1) then
                    fail("branch table f3=" & to_string(BR_TABLE(k).f3) & " pc_src=" & std_logic'image(pc_src));
                end if;
            end loop;
        end loop;

        for op in 0 to 127 loop
            for f3 in 0 to 7 loop
                for f7 in 0 to 127 loop
                    v := std_logic_vector(to_unsigned(f7, 7)) & rnd5 & rnd5 &
                         std_logic_vector(to_unsigned(f3, 3)) & rnd5 &
                         std_logic_vector(to_unsigned(op, 7));
                    instr <= v;
                    for a in 0 to 3 loop
                        addr_lo <= std_logic_vector(to_unsigned(a, 2));
                        zero    <= '0';
                        wait for 1 ns;
                        check_all;
                        zero <= '1';
                        wait for 1 ns;
                        check_all;
                    end loop;
                end loop;
            end loop;
        end loop;

        report "tb_controller: " & integer'image(checks) & " checks, " & integer'image(n_br) &
               " branch vectors (" & integer'image(n_taken) & " taken), " & integer'image(n_mis) &
               " misaligned, " & integer'image(n_jump) & " jump vectors, " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_controller FAILED" severity failure;
        report "tb_controller PASSED";
        std.env.finish;
    end process;
end architecture sim;