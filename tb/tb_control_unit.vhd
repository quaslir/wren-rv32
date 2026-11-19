library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_control_unit is
    generic(
        PASSES : positive := 2;
        SEED1  : positive := 11;
        SEED2  : positive := 29
    );
end entity tb_control_unit;

architecture sim of tb_control_unit is
    signal instr      : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_write  : std_logic;
    signal alu_op     : std_logic_vector(3 downto 0);
    signal alu_src    : std_logic;
    signal illegal    : std_logic;
    signal imm_src    : std_logic_vector(2 downto 0);
    signal branch     : std_logic;
    signal mem_write  : std_logic;
    signal result_src : std_logic_vector(1 downto 0);
    signal mem_access : std_logic;
    signal jump       : std_logic;
    signal jalr       : std_logic;

    constant OP_R : std_logic_vector(6 downto 0) := "0110011";
    constant OP_I : std_logic_vector(6 downto 0) := "0010011";
    constant OP_B : std_logic_vector(6 downto 0) := "1100011";
    constant OP_L : std_logic_vector(6 downto 0) := "0000011";
    constant OP_S : std_logic_vector(6 downto 0) := "0100011";
    constant OP_J : std_logic_vector(6 downto 0) := "1101111";
    constant OP_JR : std_logic_vector(6 downto 0) := "1100111";

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
    end record;

    constant ILLEGAL_CTRL : ctrl_t := (
        reg_write => '0', alu_src => '-', illegal => '1', branch => '0',
        mem_write => '0', mem_access => '0', jump => '0', jalr => '0', alu_op => "----", imm_src => "---",
        result_src => "--", c_alu_src => false, c_alu_op => false,
        c_imm_src => false, c_result => false
    );

    function ref_ctrl(v : std_logic_vector(31 downto 0)) return ctrl_t is
        variable op : std_logic_vector(6 downto 0) := v(6 downto 0);
        variable f3 : std_logic_vector(2 downto 0) := v(14 downto 12);
        variable f7 : std_logic_vector(6 downto 0) := v(31 downto 25);
        variable c  : ctrl_t := ILLEGAL_CTRL;
    begin
        if op = OP_R then
            if f7 = "0000000" or (f7 = "0100000" and (f3 = "000" or f3 = "101")) then
                c := ('1', '0', '0', '0', '0', '0', '0', '0', f7(5) & f3, "---", "00", true, true, false, true);
            end if;
        elsif op = OP_I then
            if f3 = "001" then
                if f7 = "0000000" then
                    c := ('1', '1', '0', '0', '0', '0', '0', '0', "0001", "000", "00", true, true, true, true);
                end if;
            elsif f3 = "101" then
                if f7 = "0000000" then
                    c := ('1', '1', '0', '0', '0', '0', '0', '0', "0101", "000", "00", true, true, true, true);
                elsif f7 = "0100000" then
                    c := ('1', '1', '0', '0', '0', '0', '0', '0', "1101", "000", "00", true, true, true, true);
                end if;
            else
                c := ('1', '1', '0', '0', '0', '0', '0', '0', '0' & f3, "000", "00", true, true, true, true);
            end if;
        elsif op = OP_B then
            case f3 is
                when "000" | "001" =>
                    c := ('0', '0', '0', '1', '0', '0', '0', '0', "1000", "010", "--", true, true, true, false);
                when "100" | "101" =>
                    c := ('0', '0', '0', '1', '0', '0', '0', '0', "0010", "010", "--", true, true, true, false);
                when "110" | "111" =>
                    c := ('0', '0', '0', '1', '0', '0', '0', '0', "0011", "010", "--", true, true, true, false);
                when others =>
                    null;
            end case;
        elsif op = OP_L then
            case f3 is
                when "000" | "001" | "010" | "100" | "101" =>
                    c := ('1', '1', '0', '0', '0', '1', '0', '0', "0000", "000", "01", true, true, true, true);
                when others =>
                    null;
            end case;
        elsif op = OP_J then
            c := ('1', '-', '0', '0', '0', '0', '1', '0', "----", "011", "10", false, false, true, true);
        elsif op = OP_JR then
            if f3 = "000" then
                c := ('1', '-', '0', '0', '0', '0', '1', '1', "----", "000", "10", false, false, true, true);
            end if;
        elsif op = OP_S then
            case f3 is
                when "000" | "001" | "010" =>
                    c := ('0', '1', '0', '0', '1', '1', '0', '0', "0000", "001", "--", true, true, true, false);
                when others =>
                    null;
            end case;
        end if;
        return c;
    end function;

    function enc_r(f7 : std_logic_vector(6 downto 0); f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        return f7 & "00011" & "00010" & f3 & "00001" & OP_R;
    end function;

    function enc_i(imm : integer; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & "00010" & f3 & "00001" & OP_I;
    end function;

    function enc_sh(f7 : std_logic_vector(6 downto 0); sh : natural; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        return f7 & std_logic_vector(to_unsigned(sh, 5)) & "00010" & f3 & "00001" & OP_I;
    end function;

    function enc_b(f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        return "0000000" & "00011" & "00010" & f3 & "01000" & OP_B;
    end function;

    function enc_l(imm : integer; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & "00010" & f3 & "00001" & OP_L;
    end function;

    function enc_s(imm : integer; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable u : std_logic_vector(11 downto 0) := std_logic_vector(to_signed(imm, 12));
    begin
        return u(11 downto 5) & "00011" & "00010" & f3 & u(4 downto 0) & OP_S;
    end function;

    type vec_t is record
        name : string(1 to 12);
        v    : std_logic_vector(31 downto 0);
        rw   : std_logic;
        src  : std_logic;
        op   : std_logic_vector(3 downto 0);
        imm  : std_logic_vector(2 downto 0);
        br   : std_logic;
        mw   : std_logic;
        rs   : std_logic_vector(1 downto 0);
        ma   : std_logic;
        il   : std_logic;
        jp   : std_logic;
        jr   : std_logic;
    end record;
    type vec_arr_t is array (natural range <>) of vec_t;

    constant DIRECTED : vec_arr_t := (
        ("add         ", enc_r("0000000", "000"), '1', '0', "0000", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("sub         ", enc_r("0100000", "000"), '1', '0', "1000", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("sll         ", enc_r("0000000", "001"), '1', '0', "0001", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("slt         ", enc_r("0000000", "010"), '1', '0', "0010", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("sltu        ", enc_r("0000000", "011"), '1', '0', "0011", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("xor         ", enc_r("0000000", "100"), '1', '0', "0100", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("srl         ", enc_r("0000000", "101"), '1', '0', "0101", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("sra         ", enc_r("0100000", "101"), '1', '0', "1101", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("or          ", enc_r("0000000", "110"), '1', '0', "0110", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("and         ", enc_r("0000000", "111"), '1', '0', "0111", "---", '0', '0', "00", '0', '0', '0', '0'),
        ("addi +      ", enc_i(2047, "000"), '1', '1', "0000", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("addi -      ", enc_i(-2048, "000"), '1', '1', "0000", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("addi -1     ", enc_i(-1, "000"), '1', '1', "0000", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("slti -      ", enc_i(-1024, "010"), '1', '1', "0010", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("sltiu -1    ", enc_i(-1, "011"), '1', '1', "0011", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("xori -1     ", enc_i(-1, "100"), '1', '1', "0100", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("ori -       ", enc_i(-1366, "110"), '1', '1', "0110", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("andi -      ", enc_i(-2048, "111"), '1', '1', "0111", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("slli 31     ", enc_sh("0000000", 31, "001"), '1', '1', "0001", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("srli 31     ", enc_sh("0000000", 31, "101"), '1', '1', "0101", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("srai 31     ", enc_sh("0100000", 31, "101"), '1', '1', "1101", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("srai 0      ", enc_sh("0100000", 0, "101"), '1', '1', "1101", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("nop         ", x"00000013", '1', '1', "0000", "000", '0', '0', "00", '0', '0', '0', '0'),
        ("beq         ", enc_b("000"), '0', '0', "1000", "010", '1', '0', "--", '0', '0', '0', '0'),
        ("bne         ", enc_b("001"), '0', '0', "1000", "010", '1', '0', "--", '0', '0', '0', '0'),
        ("blt         ", enc_b("100"), '0', '0', "0010", "010", '1', '0', "--", '0', '0', '0', '0'),
        ("bge         ", enc_b("101"), '0', '0', "0010", "010", '1', '0', "--", '0', '0', '0', '0'),
        ("bltu        ", enc_b("110"), '0', '0', "0011", "010", '1', '0', "--", '0', '0', '0', '0'),
        ("bgeu        ", enc_b("111"), '0', '0', "0011", "010", '1', '0', "--", '0', '0', '0', '0'),
        ("lb -        ", enc_l(-1, "000"), '1', '1', "0000", "000", '0', '0', "01", '1', '0', '0', '0'),
        ("lh +        ", enc_l(2046, "001"), '1', '1', "0000", "000", '0', '0', "01", '1', '0', '0', '0'),
        ("lw -        ", enc_l(-2048, "010"), '1', '1', "0000", "000", '0', '0', "01", '1', '0', '0', '0'),
        ("lbu +       ", enc_l(3, "100"), '1', '1', "0000", "000", '0', '0', "01", '1', '0', '0', '0'),
        ("lhu -       ", enc_l(-2, "101"), '1', '1', "0000", "000", '0', '0', "01", '1', '0', '0', '0'),
        ("sb -        ", enc_s(-1, "000"), '0', '1', "0000", "001", '0', '1', "--", '1', '0', '0', '0'),
        ("sh +        ", enc_s(2046, "001"), '0', '1', "0000", "001", '0', '1', "--", '1', '0', '0', '0'),
        ("sw -        ", enc_s(-2048, "010"), '0', '1', "0000", "001", '0', '1', "--", '1', '0', '0', '0'),
        ("mul         ", enc_r("0000001", "000"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("div         ", enc_r("0000001", "100"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("R f7=0100000", enc_r("0100000", "001"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("R f7=0100000", enc_r("0100000", "111"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("R f7=1000000", enc_r("1000000", "000"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("slli f7 bad ", enc_sh("0100000", 1, "001"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("slli f7 bad ", enc_sh("0000001", 1, "001"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("srli f7 bad ", enc_sh("0000001", 1, "101"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("srai f7 bad ", enc_sh("0110000", 1, "101"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("B f3=010    ", enc_b("010"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("B f3=011    ", enc_b("011"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("load f3=011 ", enc_l(0, "011"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("load f3=110 ", enc_l(0, "110"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("load f3=111 ", enc_l(0, "111"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("store f3=011", enc_s(0, "011"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("store f3=100", enc_s(0, "100"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("store f3=101", enc_s(0, "101"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("store f3=110", enc_s(0, "110"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("store f3=111", enc_s(0, "111"), '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("jal x1,8    ", x"008000EF", '1', '-', "----", "011", '0', '0', "10", '0', '0', '1', '0'),
        ("jal x0,-4   ", x"FFDFF06F", '1', '-', "----", "011", '0', '0', "10", '0', '0', '1', '0'),
        ("jal f3 bits ", x"0000706F", '1', '-', "----", "011", '0', '0', "10", '0', '0', '1', '0'),
        ("jal all ones", x"FFFFFFEF", '1', '-', "----", "011", '0', '0', "10", '0', '0', '1', '0'),
        ("jalr ret    ", x"00008067", '1', '-', "----", "000", '0', '0', "10", '0', '0', '1', '1'),
        ("jalr x1,-1  ", x"FFF080E7", '1', '-', "----", "000", '0', '0', "10", '0', '0', '1', '1'),
        ("jalr f3=001 ", x"000090E7", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("jalr f3=111 ", x"0000F0E7", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("lui         ", x"123450B7", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("auipc       ", x"12345097", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("fence       ", x"0FF0000F", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("ecall       ", x"00000073", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("ebreak      ", x"00100073", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("zero word   ", x"00000000", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("all ones    ", x"FFFFFFFF", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0'),
        ("custom-0    ", x"0000000B", '0', '-', "----", "---", '0', '0', "--", '0', '1', '0', '0')
    );

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
    dut : entity work.control_unit
        port map(
            instr      => instr,
            reg_write  => reg_write,
            alu_op     => alu_op,
            alu_src    => alu_src,
            illegal    => illegal,
            imm_src    => imm_src,
            branch     => branch,
            mem_write  => mem_write,
            result_src => result_src,
            mem_access => mem_access,
            jump       => jump,
            jalr       => jalr
        );

    stim : process
        variable errors  : natural := 0;
        variable checks  : natural := 0;
        variable n_legal : natural := 0;
        variable n_ill   : natural := 0;
        variable s1      : positive := SEED1;
        variable s2      : positive := SEED2;
        variable r       : real;
        variable v       : std_logic_vector(31 downto 0);
        variable c       : ctrl_t;

        impure function rnd5 return std_logic_vector is
        begin
            uniform(s1, s2, r);
            return std_logic_vector(to_unsigned(integer(trunc(r * 32.0)) mod 32, 5));
        end function;

        procedure fail(tag : string; msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report tag & " instr=0x" & to_hstring(instr) & ": " & msg severity error;
            end if;
        end procedure;

        procedure chk1(tag, name : string; got, exp : std_logic) is
        begin
            checks := checks + 1;
            if exp /= '-' and got /= exp then
                fail(tag, name & " got=" & std_logic'image(got) & " expected=" & std_logic'image(exp));
            end if;
        end procedure;

        procedure chkv(tag, name : string; got, exp : std_logic_vector) is
        begin
            checks := checks + 1;
            if not std_match_v(got, exp) then
                fail(tag, name & " got=" & to_string(got) & " expected=" & to_string(exp));
            end if;
        end procedure;

        procedure check_defined(tag : string) is
        begin
            checks := checks + 1;
            if is_x(reg_write & alu_op & alu_src & illegal & imm_src & branch & mem_write & result_src & mem_access & jump & jalr) then
                fail(tag, "undefined output: rw=" & std_logic'image(reg_write) & " op=" & to_string(alu_op) &
                     " src=" & std_logic'image(alu_src) & " il=" & std_logic'image(illegal) &
                     " imm=" & to_string(imm_src) & " br=" & std_logic'image(branch) &
                     " mw=" & std_logic'image(mem_write) & " rs=" & to_string(result_src) &
                     " ma=" & std_logic'image(mem_access) & " jp=" & std_logic'image(jump) &
                     " jr=" & std_logic'image(jalr));
            end if;
        end procedure;

        procedure check_invariants(tag : string) is
        begin
            checks := checks + 1;
            if illegal = '1' and (reg_write = '1' or mem_write = '1' or branch = '1' or mem_access = '1' or jump = '1' or jalr = '1') then
                fail(tag, "illegal instruction has side effects");
            end if;
            if mem_write = '1' and mem_access = '0' then
                fail(tag, "mem_write=1 without mem_access");
            end if;
            if mem_write = '1' and reg_write = '1' then
                fail(tag, "store writes register");
            end if;
            if branch = '1' and (reg_write = '1' or mem_write = '1' or mem_access = '1') then
                fail(tag, "branch has side effects");
            end if;
            if jalr = '1' and jump = '0' then
                fail(tag, "jalr=1 without jump");
            end if;
            if jump = '1' and (branch = '1' or mem_write = '1' or mem_access = '1') then
                fail(tag, "jump combined with branch or memory access");
            end if;
            if jump = '1' and (reg_write = '0' or result_src /= "10") then
                fail(tag, "jump does not write pc+4");
            end if;
            if mem_access = '1' and alu_src /= '1' then
                fail(tag, "memory access without immediate operand");
            end if;
            if mem_access = '1' and alu_op /= "0000" then
                fail(tag, "memory address not computed with ADD");
            end if;
            if reg_write = '1' and result_src = "01" and mem_access = '0' then
                fail(tag, "load result selected without mem_access");
            end if;
        end procedure;

        procedure check_ref(tag : string) is
        begin
            c := ref_ctrl(instr);
            chk1(tag, "reg_write", reg_write, c.reg_write);
            chk1(tag, "illegal", illegal, c.illegal);
            chk1(tag, "branch", branch, c.branch);
            chk1(tag, "mem_write", mem_write, c.mem_write);
            chk1(tag, "mem_access", mem_access, c.mem_access);
            chk1(tag, "jump", jump, c.jump);
            chk1(tag, "jalr", jalr, c.jalr);
            if c.c_alu_src then
                chk1(tag, "alu_src", alu_src, c.alu_src);
            end if;
            if c.c_alu_op then
                chkv(tag, "alu_op", alu_op, c.alu_op);
            end if;
            if c.c_imm_src then
                chkv(tag, "imm_src", imm_src, c.imm_src);
            end if;
            if c.c_result then
                chkv(tag, "result_src", result_src, c.result_src);
            end if;
            check_defined(tag);
            check_invariants(tag);
            if c.illegal = '1' then
                n_ill := n_ill + 1;
            else
                n_legal := n_legal + 1;
            end if;
        end procedure;
    begin
        for k in DIRECTED'range loop
            instr <= DIRECTED(k).v;
            wait for 1 ns;
            chk1(DIRECTED(k).name, "reg_write", reg_write, DIRECTED(k).rw);
            chk1(DIRECTED(k).name, "alu_src", alu_src, DIRECTED(k).src);
            chkv(DIRECTED(k).name, "alu_op", alu_op, DIRECTED(k).op);
            chkv(DIRECTED(k).name, "imm_src", imm_src, DIRECTED(k).imm);
            chk1(DIRECTED(k).name, "branch", branch, DIRECTED(k).br);
            chk1(DIRECTED(k).name, "mem_write", mem_write, DIRECTED(k).mw);
            chkv(DIRECTED(k).name, "result_src", result_src, DIRECTED(k).rs);
            chk1(DIRECTED(k).name, "mem_access", mem_access, DIRECTED(k).ma);
            chk1(DIRECTED(k).name, "illegal", illegal, DIRECTED(k).il);
            chk1(DIRECTED(k).name, "jump", jump, DIRECTED(k).jp);
            chk1(DIRECTED(k).name, "jalr", jalr, DIRECTED(k).jr);
            check_defined(DIRECTED(k).name);
            check_invariants(DIRECTED(k).name);
        end loop;

        for p in 1 to PASSES loop
            for op in 0 to 127 loop
                for f3 in 0 to 7 loop
                    for f7 in 0 to 127 loop
                        v := std_logic_vector(to_unsigned(f7, 7)) & rnd5 & rnd5 &
                             std_logic_vector(to_unsigned(f3, 3)) & rnd5 &
                             std_logic_vector(to_unsigned(op, 7));
                        instr <= v;
                        wait for 1 ns;
                        check_ref("exhaustive");
                    end loop;
                end loop;
            end loop;
        end loop;

        for op in 0 to 127 loop
            for f3 in 0 to 7 loop
                for f7 in 0 to 127 loop
                    v := std_logic_vector(to_unsigned(f7, 7)) & "11111" & "11111" &
                         std_logic_vector(to_unsigned(f3, 3)) & "11111" &
                         std_logic_vector(to_unsigned(op, 7));
                    instr <= v;
                    wait for 1 ns;
                    check_ref("fields=1");
                    v(24 downto 15) := (others => '0');
                    v(11 downto 7)  := (others => '0');
                    instr <= v;
                    wait for 1 ns;
                    check_ref("fields=0");
                end loop;
            end loop;
        end loop;

        report "tb_control_unit: " & integer'image(checks) & " checks (" & integer'image(n_legal) &
               " legal, " & integer'image(n_ill) & " illegal vectors), " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_control_unit FAILED" severity failure;
        report "tb_control_unit PASSED";
        std.env.finish;
    end process;
end architecture sim;