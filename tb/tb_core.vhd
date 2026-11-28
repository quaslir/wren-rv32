library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_core is
    generic(
        STAGE         : natural  := 4;
        N_BODY        : natural  := 6000;
        SEED1         : positive := 5;
        SEED2         : positive := 77;
        MEM_DEPTH     : positive := 64;
        CHECK_ILLEGAL : boolean  := false
    );
end entity tb_core;

architecture sim of tb_core is
    constant CLK_PERIOD : time := 10 ns;
    constant IMEM_WORDS : positive := 16384;
    constant MEM_W      : positive := minimum(MEM_DEPTH, 511);
    constant NOP        : std_logic_vector(31 downto 0) := x"00000013";

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal instr      : std_logic_vector(31 downto 0) := NOP;
    signal illegal    : std_logic;
    signal alu_result : std_logic_vector(31 downto 0);
    signal pc         : std_logic_vector(31 downto 0);
    signal read_data  : std_logic_vector(31 downto 0);
    signal mem_write  : std_logic;
    signal write_data : std_logic_vector(31 downto 0);
    signal be         : std_logic_vector(3 downto 0);
    signal misaligned : std_logic;
    signal irq        : std_logic := '0';
    signal done       : boolean := false;

    type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
    type mem_t is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);
    type imem_t is array (0 to IMEM_WORDS - 1) of std_logic_vector(31 downto 0);
    type be_arr_t is array (0 to IMEM_WORDS - 1) of std_logic_vector(3 downto 0);
    type bool_arr_t is array (0 to IMEM_WORDS - 1) of boolean;
    type nat_arr_t is array (0 to IMEM_WORDS - 1) of natural;
    signal dmem : mem_t := (others => (others => '0'));
    signal imem : imem_t := (others => NOP);

    constant OP_R   : std_logic_vector(6 downto 0) := "0110011";
    constant OP_I   : std_logic_vector(6 downto 0) := "0010011";
    constant OP_B   : std_logic_vector(6 downto 0) := "1100011";
    constant OP_L   : std_logic_vector(6 downto 0) := "0000011";
    constant OP_S   : std_logic_vector(6 downto 0) := "0100011";
    constant OP_J   : std_logic_vector(6 downto 0) := "1101111";
    constant OP_JR  : std_logic_vector(6 downto 0) := "1100111";
    constant OP_LUI : std_logic_vector(6 downto 0) := "0110111";
    constant OP_AUI : std_logic_vector(6 downto 0) := "0010111";

    type f3_arr_t is array (natural range <>) of std_logic_vector(2 downto 0);
    constant I_F3 : f3_arr_t := ("000", "010", "011", "100", "110", "111");
    constant B_F3 : f3_arr_t := ("000", "001", "100", "101", "110", "111");
    constant L_F3 : f3_arr_t := ("000", "001", "010", "100", "101");
    constant S_F3 : f3_arr_t := ("000", "001", "010");

    function word_of(a : std_logic_vector(31 downto 0)) return natural is
    begin
        if is_x(a) then
            return MEM_DEPTH;
        elsif unsigned(a(31 downto 2)) < MEM_DEPTH then
            return to_integer(unsigned(a(31 downto 2)));
        else
            return MEM_DEPTH;
        end if;
    end function;

    function ref_alu(a, b : std_logic_vector(31 downto 0); op : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable sh : natural := to_integer(unsigned(b(4 downto 0)));
    begin
        case op is
            when "0000" => return std_logic_vector(unsigned(a) + unsigned(b));
            when "1000" => return std_logic_vector(unsigned(a) - unsigned(b));
            when "0001" => return std_logic_vector(shift_left(unsigned(a), sh));
            when "0010" =>
                if signed(a) < signed(b) then return x"00000001"; else return x"00000000"; end if;
            when "0011" =>
                if unsigned(a) < unsigned(b) then return x"00000001"; else return x"00000000"; end if;
            when "0100" => return a xor b;
            when "0101" => return std_logic_vector(shift_right(unsigned(a), sh));
            when "1101" => return std_logic_vector(shift_right(signed(a), sh));
            when "0110" => return a or b;
            when "0111" => return a and b;
            when others => return x"00000000";
        end case;
    end function;

    function ref_load(f : std_logic_vector(2 downto 0); a : std_logic_vector(1 downto 0);
                      w : std_logic_vector(31 downto 0)) return std_logic_vector is
        variable b : std_logic_vector(7 downto 0);
        variable h : std_logic_vector(15 downto 0);
        variable i : natural := to_integer(unsigned(a));
    begin
        b := w(8 * i + 7 downto 8 * i);
        if a(1) = '0' then h := w(15 downto 0); else h := w(31 downto 16); end if;
        case f is
            when "000"  => return std_logic_vector(resize(signed(b), 32));
            when "001"  => return std_logic_vector(resize(signed(h), 32));
            when "100"  => return std_logic_vector(resize(unsigned(b), 32));
            when "101"  => return std_logic_vector(resize(unsigned(h), 32));
            when others => return w;
        end case;
    end function;

    function ref_be(f : std_logic_vector(2 downto 0); a : std_logic_vector(1 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(3 downto 0) := "0000";
    begin
        case f(1 downto 0) is
            when "00" => r(to_integer(unsigned(a))) := '1';
            when "01" => if a(1) = '0' then r := "0011"; else r := "1100"; end if;
            when others => r := "1111";
        end case;
        return r;
    end function;

    function ref_lanes(f : std_logic_vector(2 downto 0); d : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        case f(1 downto 0) is
            when "00"   => return d(7 downto 0) & d(7 downto 0) & d(7 downto 0) & d(7 downto 0);
            when "01"   => return d(15 downto 0) & d(15 downto 0);
            when others => return d;
        end case;
    end function;

    function r5(n : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(n, 5));
    end function;

    function enc_r(f7 : std_logic_vector(6 downto 0); rs2, rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
    begin
        return f7 & r5(rs2) & r5(rs1) & f3 & r5(rd) & OP_R;
    end function;

    function enc_i(imm : integer; rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & r5(rs1) & f3 & r5(rd) & OP_I;
    end function;

    function enc_l(imm : integer; rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & r5(rs1) & f3 & r5(rd) & OP_L;
    end function;

    function enc_s(imm : integer; rs2, rs1 : natural; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable u : std_logic_vector(11 downto 0) := std_logic_vector(to_signed(imm, 12));
    begin
        return u(11 downto 5) & r5(rs2) & r5(rs1) & f3 & u(4 downto 0) & OP_S;
    end function;

    function enc_j(imm : integer; rd : natural) return std_logic_vector is
        variable u : std_logic_vector(20 downto 0) := std_logic_vector(to_signed(imm, 21));
    begin
        return u(20) & u(10 downto 1) & u(11) & u(19 downto 12) & r5(rd) & OP_J;
    end function;

    function enc_jr(imm : integer; rs1 : natural; rd : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & r5(rs1) & "000" & r5(rd) & OP_JR;
    end function;

    function enc_u(imm20 : natural; rd : natural; op : std_logic_vector(6 downto 0)) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(imm20, 20)) & r5(rd) & op;
    end function;

    function enc_b(imm : integer; rs2, rs1 : natural; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable u : std_logic_vector(12 downto 0) := std_logic_vector(to_signed(imm, 13));
    begin
        return u(12) & u(10 downto 5) & r5(rs2) & r5(rs1) & f3 & u(4 downto 1) & u(11) & OP_B;
    end function;
begin
    dut : entity work.core
        port map(
            clk        => clk,
            rst        => rst,
            instr      => instr,
            illegal    => illegal,
            alu_result => alu_result,
            pc         => pc,
            read_data  => read_data,
            mem_write  => mem_write,
            write_data => write_data,
            be         => be,
            misaligned => misaligned,
            irq        => irq
        );

    read_data <= dmem(word_of(alu_result)) when word_of(alu_result) < MEM_DEPTH else (others => '0');

    fetch : process(pc, imem)
    begin
        if is_x(pc) then
            instr <= NOP;
        elsif unsigned(pc(31 downto 2)) < IMEM_WORDS then
            instr <= imem(to_integer(unsigned(pc(31 downto 2))));
        else
            instr <= NOP;
        end if;
    end process;

    clk <= not clk after CLK_PERIOD / 2 when not done;

    stim : process
        variable s1      : positive := SEED1;
        variable s2      : positive := SEED2;
        variable r       : real;
        variable prog    : imem_t := (others => NOP);
        variable is_jr   : bool_arr_t := (others => false);
        variable fix_pos : nat_arr_t;
        variable fix_tgt : nat_arr_t;
        variable n_fix   : natural := 0;
        variable idx     : natural := 0;
        variable body_end, prog_len : natural;
        variable xr      : regs_t := (others => (others => '0'));
        variable mem, dm : mem_t := (others => (others => '0'));
        variable tr_addr, tr_data : imem_t;
        variable tr_be   : be_arr_t;
        variable n_tr, tidx, n_extra : natural := 0;
        variable n_exec, n_lu, n_taken, n_mis, n_ld, n_st, n_br, n_jmp : natural := 0;
        variable i_pc    : unsigned(31 downto 0);
        variable err, cyc, end_cyc, drain, n_dut_mis, n_dut_ill, exp_cyc, limit : natural := 0;
        variable reached : boolean := false;
        variable k, p, t, odd : natural;
        variable w, ln   : std_logic_vector(31 downto 0);
        variable a, b    : natural;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        impure function rnd_reg return natural is
            variable c : natural;
        begin
            c := rnd(10);
            if c = 0 then
                return 0;
            elsif c <= 5 then
                return 1 + rnd(4);
            else
                return 1 + rnd(31);
            end if;
        end function;

        procedure fail(msg : string) is
        begin
            if err < 20 then
                report "FAIL cycle " & integer'image(cyc) & ": " & msg severity error;
            end if;
            err := err + 1;
        end procedure;

        procedure emit(v : std_logic_vector(31 downto 0)) is
        begin
            assert idx < IMEM_WORDS - 64 report "tb_core: program too long, reduce N_BODY" severity failure;
            prog(idx) := v;
            idx := idx + 1;
            if STAGE <= 1 then
                prog(idx) := NOP;
                prog(idx + 1) := NOP;
                idx := idx + 2;
            elsif STAGE = 2 and v(6 downto 0) = OP_L then
                prog(idx) := NOP;
                idx := idx + 1;
            end if;
        end procedure;

        procedure gen_alu is
            variable f3 : std_logic_vector(2 downto 0);
            variable f7 : std_logic_vector(6 downto 0);
        begin
            if rnd(2) = 0 then
                f3 := std_logic_vector(to_unsigned(rnd(8), 3));
                if (f3 = "000" or f3 = "101") and rnd(2) = 1 then f7 := "0100000"; else f7 := "0000000"; end if;
                emit(enc_r(f7, rnd_reg, rnd_reg, f3, rnd_reg));
            else
                case rnd(3) is
                    when 0      => emit(enc_i(rnd(4096) - 2048, rnd_reg, I_F3(rnd(6)), rnd_reg));
                    when 1      => emit(enc_i(rnd(32), rnd_reg, "001", rnd_reg));
                    when others => emit(enc_i(rnd(32) + 1024 * rnd(2), rnd_reg, "101", rnd_reg));
                end case;
            end if;
        end procedure;

        procedure gen_mem(ld : boolean) is
            variable fn : std_logic_vector(2 downto 0);
            variable o  : natural;
        begin
            if ld then fn := L_F3(rnd(5)); else fn := S_F3(rnd(3)); end if;
            if rnd(4) = 0 then
                if ld then
                    emit(enc_l(rnd(4096) - 2048, rnd_reg, fn, rnd_reg));
                else
                    emit(enc_s(rnd(4096) - 2048, rnd_reg, rnd_reg, fn));
                end if;
            else
                o := rnd(4 * MEM_W + 3);
                if rnd(3) /= 0 then
                    if fn(1 downto 0) = "01" then o := o - o mod 2; elsif fn(1 downto 0) = "10" then o := o - o mod 4; end if;
                end if;
                if ld then
                    emit(enc_l(o, 0, fn, rnd_reg));
                else
                    emit(enc_s(o, rnd_reg, 0, fn));
                end if;
            end if;
        end procedure;

        procedure gen_pattern is
            variable ra, rb : natural;
        begin
            ra := 1 + rnd(4);
            rb := 1 + rnd(31);
            case rnd(6) is
                when 0 =>
                    emit(enc_i(4 * rnd(MEM_W) + rnd(4), 0, "000", ra));
                    if rnd(2) = 0 then
                        emit(enc_l(rnd(8), ra, L_F3(rnd(5)), rb));
                    else
                        emit(enc_s(rnd(8), rb, ra, S_F3(rnd(3))));
                    end if;
                when 1 =>
                    emit(enc_l(4 * rnd(MEM_W), 0, "010", ra));
                    emit(enc_r("0000000", ra, ra, "000", rb));
                    emit(enc_s(4 * rnd(MEM_W), ra, 0, "010"));
                when 2 =>
                    emit(enc_l(4 * rnd(MEM_W), 0, L_F3(rnd(5)), ra));
                    emit(enc_s(4 * rnd(MEM_W), ra, 0, S_F3(rnd(3))));
                when 3 =>
                    emit(enc_i(rnd(4096) - 2048, 0, "000", ra));
                    emit(enc_i(rnd(4096) - 2048, 0, "000", ra));
                    if rnd(2) = 0 then
                        emit(enc_r("0000000", 0, ra, "000", rb));
                    else
                        emit(enc_r("0100000", ra, 0, "000", rb));
                    end if;
                when 4 =>
                    emit(enc_i(rnd(4096) - 2048, 0, "000", ra));
                    emit(enc_i(rnd(4096) - 2048, 0, "000", ra));
                    emit(enc_s(4 * rnd(MEM_W), ra, 0, "010"));
                when others =>
                    emit(enc_l(4 * rnd(MEM_W), 0, "010", ra));
                    emit(enc_l(rnd(8), ra, L_F3(rnd(5)), rb));
            end case;
        end procedure;

        procedure exec_one is
            variable v, imm, ad, res, tg : std_logic_vector(31 downto 0);
            variable op7 : std_logic_vector(6 downto 0);
            variable fn3 : std_logic_vector(2 downto 0);
            variable q1, q2, d : natural;
            variable nx  : unsigned(31 downto 0);
            variable wr, misa, tk : boolean;
            variable nw  : std_logic_vector(31 downto 0);
            variable bb  : std_logic_vector(3 downto 0);
            variable lz  : std_logic_vector(31 downto 0);
        begin
            v   := prog(to_integer(i_pc(31 downto 2)));
            op7 := v(6 downto 0);
            fn3 := v(14 downto 12);
            q1  := to_integer(unsigned(v(19 downto 15)));
            q2  := to_integer(unsigned(v(24 downto 20)));
            d   := to_integer(unsigned(v(11 downto 7)));
            nx  := i_pc + 4;
            wr  := false;
            res := (others => '0');
            n_exec := n_exec + 1;
            if op7 = OP_R then
                res := ref_alu(xr(q1), xr(q2), v(30) & fn3);
                wr  := true;
            elsif op7 = OP_I then
                imm := (31 downto 12 => v(31)) & v(31 downto 20);
                if fn3 = "101" then
                    res := ref_alu(xr(q1), imm, v(30) & fn3);
                else
                    res := ref_alu(xr(q1), imm, '0' & fn3);
                end if;
                wr := true;
            elsif op7 = OP_LUI then
                res := v(31 downto 12) & x"000";
                wr  := true;
            elsif op7 = OP_AUI then
                imm := v(31 downto 12) & x"000";
                res := std_logic_vector(i_pc + unsigned(imm));
                wr  := true;
            elsif op7 = OP_L then
                n_ld := n_ld + 1;
                imm  := (31 downto 12 => v(31)) & v(31 downto 20);
                ad   := std_logic_vector(unsigned(xr(q1)) + unsigned(imm));
                misa := (fn3(1 downto 0) = "01" and ad(0) = '1') or (fn3(1 downto 0) = "10" and ad(1 downto 0) /= "00");
                if misa then
                    n_mis := n_mis + 1;
                elsif word_of(ad) < MEM_DEPTH then
                    res := ref_load(fn3, ad(1 downto 0), mem(word_of(ad)));
                    wr  := true;
                else
                    res := ref_load(fn3, ad(1 downto 0), x"00000000");
                    wr  := true;
                end if;
                nw := prog(to_integer(i_pc(31 downto 2)) + 1);
                if d /= 0 and (to_integer(unsigned(nw(19 downto 15))) = d or to_integer(unsigned(nw(24 downto 20))) = d) then
                    n_lu := n_lu + 1;
                end if;
            elsif op7 = OP_S then
                n_st := n_st + 1;
                imm  := (31 downto 12 => v(31)) & v(31 downto 25) & v(11 downto 7);
                ad   := std_logic_vector(unsigned(xr(q1)) + unsigned(imm));
                misa := (fn3(1 downto 0) = "01" and ad(0) = '1') or (fn3(1 downto 0) = "10" and ad(1 downto 0) /= "00");
                if misa then
                    n_mis := n_mis + 1;
                else
                    bb := ref_be(fn3, ad(1 downto 0));
                    lz := ref_lanes(fn3, xr(q2));
                    tr_addr(n_tr) := ad;
                    tr_be(n_tr)   := bb;
                    tr_data(n_tr) := lz;
                    n_tr := n_tr + 1;
                    if word_of(ad) < MEM_DEPTH then
                        for i in 0 to 3 loop
                            if bb(i) = '1' then
                                mem(word_of(ad))(8 * i + 7 downto 8 * i) := lz(8 * i + 7 downto 8 * i);
                            end if;
                        end loop;
                    end if;
                end if;
            elsif op7 = OP_B then
                n_br := n_br + 1;
                imm  := (31 downto 12 => v(31)) & v(7) & v(30 downto 25) & v(11 downto 8) & '0';
                case fn3 is
                    when "000"  => tk := xr(q1) = xr(q2);
                    when "001"  => tk := xr(q1) /= xr(q2);
                    when "100"  => tk := signed(xr(q1)) < signed(xr(q2));
                    when "101"  => tk := signed(xr(q1)) >= signed(xr(q2));
                    when "110"  => tk := unsigned(xr(q1)) < unsigned(xr(q2));
                    when others => tk := unsigned(xr(q1)) >= unsigned(xr(q2));
                end case;
                if tk then
                    nx := i_pc + unsigned(imm);
                    n_taken := n_taken + 1;
                end if;
            elsif op7 = OP_J then
                n_jmp := n_jmp + 1;
                imm := (31 downto 20 => v(31)) & v(19 downto 12) & v(20) & v(30 downto 21) & '0';
                res := std_logic_vector(i_pc + 4);
                wr  := true;
                nx  := i_pc + unsigned(imm);
                n_taken := n_taken + 1;
            elsif op7 = OP_JR then
                n_jmp := n_jmp + 1;
                imm := (31 downto 12 => v(31)) & v(31 downto 20);
                tg  := std_logic_vector(unsigned(xr(q1)) + unsigned(imm));
                tg(0) := '0';
                res := std_logic_vector(i_pc + 4);
                wr  := true;
                nx  := unsigned(tg);
                n_taken := n_taken + 1;
            end if;
            if wr and d /= 0 then
                xr(d) := res;
            end if;
            i_pc := nx;
        end procedure;
    begin
        for i in 1 to 31 loop
            emit(enc_u(rnd(1048576), i, OP_LUI));
            emit(enc_i(rnd(4096) - 2048, i, "000", i));
        end loop;
        for i in 0 to MEM_W - 1 loop
            emit(enc_s(4 * i, 1 + rnd(31), 0, "010"));
        end loop;

        body_end := idx + N_BODY;
        while idx + 16 < body_end loop
            k := rnd(100);
            if k < 30 then
                gen_alu;
            elsif k < 36 then
                if rnd(2) = 0 then
                    emit(enc_u(rnd(1048576), rnd_reg, OP_LUI));
                else
                    emit(enc_u(rnd(1048576), rnd_reg, OP_AUI));
                end if;
            elsif k < 50 then
                gen_mem(true);
            elsif k < 62 then
                gen_mem(false);
            elsif k < 72 then
                gen_pattern;
            elsif STAGE >= 4 and k < 88 then
                a := rnd_reg;
                if rnd(2) = 1 then b := a; else b := rnd_reg; end if;
                fix_pos(n_fix) := idx;
                fix_tgt(n_fix) := idx + 1 + rnd(8);
                n_fix := n_fix + 1;
                emit(enc_b(4, b, a, B_F3(rnd(6))));
            elsif STAGE >= 4 and k < 94 then
                fix_pos(n_fix) := idx;
                fix_tgt(n_fix) := idx + 1 + rnd(8);
                n_fix := n_fix + 1;
                if rnd(3) = 0 then emit(enc_j(4, 0)); else emit(enc_j(4, rnd_reg)); end if;
            elsif STAGE >= 4 then
                a := 1 + rnd(31);
                emit(enc_u(0, a, OP_AUI));
                fix_pos(n_fix) := idx;
                fix_tgt(n_fix) := idx + 1 + rnd(8);
                n_fix := n_fix + 1;
                is_jr(idx) := true;
                emit(enc_jr(8 + rnd(2), a, rnd_reg));
            else
                gen_alu;
            end if;
        end loop;
        while idx < body_end loop
            prog(idx) := NOP;
            idx := idx + 1;
        end loop;

        for n in 0 to n_fix - 1 loop
            p := fix_pos(n);
            t := fix_tgt(n);
            while is_jr(t) loop
                t := t + 1;
            end loop;
            w := prog(p);
            if w(6 downto 0) = OP_B then
                prog(p) := enc_b(4 * (t - p), to_integer(unsigned(w(24 downto 20))), to_integer(unsigned(w(19 downto 15))), w(14 downto 12));
            elsif w(6 downto 0) = OP_J then
                prog(p) := enc_j(4 * (t - p), to_integer(unsigned(w(11 downto 7))));
            else
                if w(20) = '1' then odd := 1; else odd := 0; end if;
                prog(p) := enc_jr(4 * (t - p + 1) + odd, to_integer(unsigned(w(19 downto 15))), to_integer(unsigned(w(11 downto 7))));
            end if;
        end loop;

        for i in 1 to 31 loop
            emit(enc_s(4 * ((i - 1) mod MEM_W), i, 0, "010"));
        end loop;
        prog_len := idx;

        i_pc := (others => '0');
        while i_pc < to_unsigned(4 * prog_len, 32) loop
            exec_one;
            assert n_exec < 4 * IMEM_WORDS report "tb_core: ISS does not terminate" severity failure;
        end loop;
        exp_cyc := n_exec + n_lu + 2 * n_taken;
        limit   := 2 * exp_cyc + 1000;

        imem <= prog;
        rst  <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        loop
            wait until rising_edge(clk);
            cyc := cyc + 1;
            if mem_write = '1' then
                if tidx >= n_tr then
                    n_extra := n_extra + 1;
                    fail("extra store addr=0x" & to_hstring(alu_result) & " be=" & to_string(be) & " data=0x" & to_hstring(write_data));
                else
                    if alu_result /= tr_addr(tidx) then
                        fail("store #" & integer'image(tidx) & " addr got=0x" & to_hstring(alu_result) & " expected=0x" & to_hstring(tr_addr(tidx)));
                    end if;
                    if be /= tr_be(tidx) then
                        fail("store #" & integer'image(tidx) & " be got=" & to_string(be) & " expected=" & to_string(tr_be(tidx)));
                    end if;
                    for i in 0 to 3 loop
                        if tr_be(tidx)(i) = '1' and write_data(8 * i + 7 downto 8 * i) /= tr_data(tidx)(8 * i + 7 downto 8 * i) then
                            fail("store #" & integer'image(tidx) & " addr=0x" & to_hstring(tr_addr(tidx)) & " lane " & integer'image(i)
                                 & " data got=0x" & to_hstring(write_data) & " expected=0x" & to_hstring(tr_data(tidx)));
                        end if;
                    end loop;
                    tidx := tidx + 1;
                end if;
                if word_of(alu_result) < MEM_DEPTH then
                    for i in 0 to 3 loop
                        if be(i) = '1' then
                            dm(word_of(alu_result))(8 * i + 7 downto 8 * i) := write_data(8 * i + 7 downto 8 * i);
                        end if;
                    end loop;
                    dmem <= dm;
                end if;
            elsif mem_write /= '0' then
                fail("mem_write=" & std_logic'image(mem_write));
            end if;
            if misaligned = '1' then
                n_dut_mis := n_dut_mis + 1;
            end if;
            if illegal = '1' then
                n_dut_ill := n_dut_ill + 1;
            end if;
            if not reached and not is_x(pc) and unsigned(pc) >= to_unsigned(4 * prog_len, 32) then
                reached := true;
                end_cyc := cyc - 1;
            end if;
            if reached then
                drain := drain + 1;
                exit when drain = 8;
            end if;
            if cyc > limit then
                fail("timeout: pc=0x" & to_hstring(pc) & " never reached 0x" & to_hstring(to_unsigned(4 * prog_len, 32)));
                exit;
            end if;
        end loop;

        if tidx /= n_tr then
            fail("stores got " & integer'image(tidx) & " expected " & integer'image(n_tr) & " (next expected addr=0x" & to_hstring(tr_addr(tidx)) & ")");
        end if;
        for i in 0 to MEM_DEPTH - 1 loop
            if dm(i) /= mem(i) then
                fail("final mem[" & integer'image(i) & "] got=0x" & to_hstring(dm(i)) & " expected=0x" & to_hstring(mem(i)));
            end if;
        end loop;
        if n_dut_mis /= n_mis then
            fail("misaligned cycles got " & integer'image(n_dut_mis) & " expected " & integer'image(n_mis));
        end if;
        if reached and end_cyc /= exp_cyc then
            fail("cycles got " & integer'image(end_cyc) & " expected " & integer'image(exp_cyc) & " = " & integer'image(n_exec)
                 & " instr + " & integer'image(n_lu) & " load-use + 2*" & integer'image(n_taken) & " taken");
        end if;
        if CHECK_ILLEGAL and n_dut_ill /= 0 then
            fail("illegal=1 in " & integer'image(n_dut_ill) & " cycles");
        end if;

        report "STAGE " & integer'image(STAGE) & ": program " & integer'image(prog_len) & " words, executed " & integer'image(n_exec)
            & ": load " & integer'image(n_ld) & ", store " & integer'image(n_st) & ", misaligned " & integer'image(n_mis)
            & ", branch " & integer'image(n_br) & ", jal/jalr " & integer'image(n_jmp) & ", taken " & integer'image(n_taken)
            & ", load-use " & integer'image(n_lu) & ", illegal cycles " & integer'image(n_dut_ill) severity note;
        if n_exec > 0 then
            report "cycles " & integer'image(end_cyc) & " (expected " & integer'image(exp_cyc) & "), CPI x1000 = "
                & integer'image((1000 * end_cyc) / n_exec) severity note;
        end if;
        if err = 0 then
            report "tb_core: ALL " & integer'image(n_tr) & " STORES AND " & integer'image(MEM_DEPTH) & " WORDS MATCH" severity note;
        else
            report "tb_core: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;