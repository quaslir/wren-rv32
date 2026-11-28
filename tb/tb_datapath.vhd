library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_datapath is
    generic(
        N_RANDOM : natural  := 200000;
        SEED1    : positive := 19;
        SEED2    : positive := 23
    );
end entity tb_datapath;

architecture sim of tb_datapath is
    constant T : time := 10 ns;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal pc_src       : std_logic_vector(1 downto 0) := "00";
    signal alu_src      : std_logic := '0';
    signal reg_write    : std_logic := '0';
    signal imm_src      : std_logic_vector(2 downto 0) := "000";
    signal alu_op       : std_logic_vector(3 downto 0) := "0000";
    signal instr_f      : std_logic_vector(31 downto 0) := (others => '0');
    signal result_src   : std_logic_vector(2 downto 0) := "000";
    signal read_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal jalr         : std_logic := '0';
    signal alu_src_a    : std_logic := '0';
    signal csr_we       : std_logic := '0';
    signal mret         : std_logic := '0';
    signal irq          : std_logic := '0';
    signal result_src_m : std_logic_vector(2 downto 0) := "000";
    signal forward_a_e  : std_logic_vector(1 downto 0) := "00";
    signal forward_b_e  : std_logic_vector(1 downto 0) := "00";
    signal stall_f      : std_logic := '0';
    signal stall_d      : std_logic := '0';
    signal flush_d      : std_logic := '0';
    signal alu_result   : std_logic_vector(31 downto 0);
    signal alu_result_e : std_logic_vector(31 downto 0);
    signal instr_d      : std_logic_vector(31 downto 0);
    signal valid_d      : std_logic;
    signal zero         : std_logic;
    signal pc           : std_logic_vector(31 downto 0);
    signal write_data   : std_logic_vector(31 downto 0);
    signal take_irq     : std_logic;
    signal rs1_d, rs2_d, rs1_e, rs2_e, rd_e, rd_m, rd_w : std_logic_vector(4 downto 0);
    signal done         : boolean := false;

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
            when "011"  => return (31 downto 20 => v(31)) & v(19 downto 12) & v(20) & v(30 downto 21) & '0';
            when "100"  => return v(31 downto 12) & x"000";
            when others => return x"00000000";
        end case;
    end function;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut : entity work.datapath
        port map(
            clk          => clk,
            rst          => rst,
            pc_src       => pc_src,
            alu_src      => alu_src,
            reg_write    => reg_write,
            imm_src      => imm_src,
            alu_op       => alu_op,
            instr_f      => instr_f,
            result_src   => result_src,
            read_data    => read_data,
            jalr         => jalr,
            alu_src_a    => alu_src_a,
            csr_we       => csr_we,
            mret         => mret,
            irq          => irq,
            result_src_m => result_src_m,
            forward_a_e  => forward_a_e,
            forward_b_e  => forward_b_e,
            stall_f      => stall_f,
            stall_d      => stall_d,
            flush_d      => flush_d,
            alu_result   => alu_result,
            alu_result_e => alu_result_e,
            instr_d      => instr_d,
            valid_d      => valid_d,
            zero         => zero,
            pc           => pc,
            write_data   => write_data,
            take_irq     => take_irq,
            rs1_d        => rs1_d,
            rs2_d        => rs2_d,
            rs1_e        => rs1_e,
            rs2_e        => rs2_e,
            rd_e         => rd_e,
            rd_m         => rd_m,
            rd_w         => rd_w
        );

    stim : process
        subtype w32 is std_logic_vector(31 downto 0);
        subtype r5_t is std_logic_vector(4 downto 0);
        type regs_t is array (0 to 31) of w32;
        type known_t is array (0 to 31) of boolean;
        variable rf      : regs_t := (others => (others => '0'));
        variable k_rf    : known_t := (0 => true, others => false);
        variable m_pc    : unsigned(31 downto 0) := (others => '0');
        variable m_ins_d : w32 := (others => '0');
        variable m_val_d : std_logic := '0';
        variable pc_d, pc4_d : w32 := (others => '0');
        variable k_pcd   : boolean := false;
        variable rd1_e, rd2_e, pc_e, pc4_e, imm_e : w32 := (others => '0');
        variable k_rd1, k_rd2, k_pce, k_imm : boolean := false;
        variable m_rs1e, m_rs2e, m_rde, m_rdm, m_rdw : r5_t := (others => '0');
        variable k_re, k_rdm, k_rdw : boolean := false;
        variable alu_m, wd_m, exr_m, res_w : w32 := (others => '0');
        variable k_alum, k_wdm, k_exrm, k_resw : boolean := false;
        variable errors, checks, cycles : natural := 0;
        variable n_fwd   : natural := 0;
        variable n_stf, n_std, n_fld, n_jmp, n_jalr, n_rst, n_ld, n_w : natural := 0;
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

        impure function rnd_sl(n : positive) return std_logic is
        begin
            if rnd(n) = 0 then return '1'; else return '0'; end if;
        end function;

        procedure fail(msg : string) is
        begin
            errors := errors + 1;
            if errors <= 30 then
                report "cycle " & integer'image(cycles) & " instr_f=0x" & to_hstring(instr_f) & " pc_src=" & to_string(pc_src)
                    & " jalr=" & std_logic'image(jalr) & " fa=" & to_string(forward_a_e) & " fb=" & to_string(forward_b_e)
                    & " src_a=" & std_logic'image(alu_src_a) & " src=" & std_logic'image(alu_src) & " op=" & to_string(alu_op)
                    & " imm_src=" & to_string(imm_src) & " res_src=" & to_string(result_src) & " res_src_m=" & to_string(result_src_m)
                    & " rw=" & std_logic'image(reg_write) & " stall_f=" & std_logic'image(stall_f) & " stall_d=" & std_logic'image(stall_d)
                    & " flush_d=" & std_logic'image(flush_d) & " rst=" & std_logic'image(rst) & ": " & msg severity error;
            end if;
        end procedure;

        procedure chk_v(ok : boolean; name : string; got, exp : std_logic_vector) is
        begin
            checks := checks + 1;
            if not ok then
                fail(name & " got=0x" & to_hstring(got) & " expected=0x" & to_hstring(exp));
            end if;
        end procedure;

        procedure chk_r(got, exp : r5_t; name : string) is
        begin
            checks := checks + 1;
            if got /= exp then
                fail(name & " got=" & integer'image(to_integer(unsigned(got))) & " expected=" & integer'image(to_integer(unsigned(exp))));
            end if;
        end procedure;

        procedure fwd_val(code : std_logic_vector(1 downto 0); reg : w32; k_reg : boolean; v : out w32; k : out boolean) is
        begin
            case code is
                when "01"   => v := res_w; k := k_resw;
                when "10"   => v := exr_m; k := k_exrm;
                when others => v := reg; k := k_reg;
            end case;
        end procedure;

        procedure step(v : w32; op : std_logic_vector(3 downto 0); isrc : std_logic_vector(2 downto 0);
                       asrc, sa, jl, rw : std_logic; rsrc, rsrc_m : std_logic_vector(2 downto 0);
                       psrc_in : std_logic_vector(1 downto 0); fa_c, fb_c : std_logic_vector(1 downto 0);
                       sf, sd, fd, do_rst : std_logic; rdata : w32) is
            variable fa, fb, a, b, alu, exr, tsum, res_m, nxt : w32;
            variable k_fa, k_fb, k_a, k_b, k_alu, k_exr, k_t, k_resm : boolean;
            variable psrc : std_logic_vector(1 downto 0);
            variable jlv  : std_logic;
            variable i1, i2 : natural;
        begin
            fwd_val(fa_c, rd1_e, k_rd1, fa, k_fa);
            fwd_val(fb_c, rd2_e, k_rd2, fb, k_fb);
            jlv := jl;
            psrc := psrc_in;
            if jlv = '1' then
                tsum := std_logic_vector(unsigned(fa) + unsigned(imm_e));
                k_t := k_fa and k_imm;
            else
                tsum := std_logic_vector(unsigned(pc_e) + unsigned(imm_e));
                k_t := k_pce and k_imm;
            end if;
            if psrc = "01" and not k_t then psrc := "00"; end if;
            if sf = '1' then psrc := "00"; end if;

            instr_f      <= v;
            alu_op       <= op;
            imm_src      <= isrc;
            alu_src      <= asrc;
            alu_src_a    <= sa;
            jalr         <= jlv;
            reg_write    <= rw;
            result_src   <= rsrc;
            result_src_m <= rsrc_m;
            pc_src       <= psrc;
            forward_a_e  <= fa_c;
            forward_b_e  <= fb_c;
            stall_f      <= sf;
            stall_d      <= sd;
            flush_d      <= fd;
            rst          <= do_rst;
            read_data    <= rdata;
            wait for 2 ns;
            cycles := cycles + 1;

            if sa = '1' then a := pc_e; k_a := k_pce; else a := fa; k_a := k_fa; end if;
            if asrc = '1' then b := imm_e; k_b := k_imm; else b := fb; k_b := k_fb; end if;
            alu := ref_alu(a, b, op);
            k_alu := k_a and k_b;
            case rsrc is
                when "010"  => exr := pc4_e; k_exr := k_pce;
                when "011"  => exr := imm_e; k_exr := k_imm;
                when others => exr := alu; k_exr := k_alu;
            end case;
            if rsrc_m = "001" then
                res_m := rdata; k_resm := true;
                n_ld := n_ld + 1;
            else
                res_m := exr_m; k_resm := k_exrm;
            end if;
            if fa_c /= "00" or fb_c /= "00" then n_fwd := n_fwd + 1; end if;

            chk_v(pc = std_logic_vector(m_pc), "pc", pc, std_logic_vector(m_pc));
            chk_v(instr_d = m_ins_d, "instr_d", instr_d, m_ins_d);
            checks := checks + 1;
            if valid_d /= m_val_d then
                fail("valid_d got " & std_logic'image(valid_d) & " expected " & std_logic'image(m_val_d));
            end if;
            chk_r(rs1_d, m_ins_d(19 downto 15), "rs1_d");
            chk_r(rs2_d, m_ins_d(24 downto 20), "rs2_d");
            if k_re then
                chk_r(rs1_e, m_rs1e, "rs1_e");
                chk_r(rs2_e, m_rs2e, "rs2_e");
                chk_r(rd_e, m_rde, "rd_e");
            end if;
            if k_rdm then chk_r(rd_m, m_rdm, "rd_m"); end if;
            if k_rdw then chk_r(rd_w, m_rdw, "rd_w"); end if;
            if k_alu then
                chk_v(alu_result_e = alu, "alu_result_e", alu_result_e, alu);
                checks := checks + 1;
                if (alu = x"00000000") /= (zero = '1') then
                    fail("zero=" & std_logic'image(zero) & " for alu 0x" & to_hstring(alu));
                end if;
            end if;
            if k_alum then chk_v(alu_result = alu_m, "alu_result (M)", alu_result, alu_m); end if;
            if k_wdm then chk_v(write_data = wd_m, "write_data (M)", write_data, wd_m); end if;
            checks := checks + 1;
            if take_irq /= '0' then
                fail("take_irq=" & std_logic'image(take_irq));
            end if;

            wait until falling_edge(clk);
            if do_rst = '0' and rw = '1' and m_rdw /= "00000" then
                n_w := n_w + 1;
                if k_rdw then
                    rf(to_integer(unsigned(m_rdw))) := res_w;
                    k_rf(to_integer(unsigned(m_rdw))) := k_resw;
                else
                    k_rf := (0 => true, others => false);
                end if;
            end if;

            wait until rising_edge(clk);
            if do_rst = '1' then
                n_rst := n_rst + 1;
                m_pc := (others => '0');
                m_ins_d := (others => '0');
                m_val_d := '0';
                k_pcd := false; k_pce := false; k_rd1 := false; k_rd2 := false; k_imm := false;
                k_re := false; k_rdm := false; k_rdw := false;
                k_alum := false; k_wdm := false; k_exrm := false; k_resw := false;
            else
                res_w := res_m; k_resw := k_resm and k_rdm;
                m_rdw := m_rdm; k_rdw := k_rdm;
                alu_m := alu; k_alum := k_alu;
                wd_m := fb; k_wdm := k_fb;
                exr_m := exr; k_exrm := k_exr;
                m_rdm := m_rde; k_rdm := k_re;
                i1 := to_integer(unsigned(m_ins_d(19 downto 15)));
                i2 := to_integer(unsigned(m_ins_d(24 downto 20)));
                rd1_e := rf(i1); k_rd1 := k_rf(i1);
                rd2_e := rf(i2); k_rd2 := k_rf(i2);
                pc_e := pc_d; pc4_e := pc4_d; k_pce := k_pcd;
                imm_e := ref_ext(m_ins_d, isrc); k_imm := true;
                m_rs1e := m_ins_d(19 downto 15);
                m_rs2e := m_ins_d(24 downto 20);
                m_rde := m_ins_d(11 downto 7);
                k_re := true;
                if fd = '1' then
                    m_ins_d := (others => '0');
                    m_val_d := '0';
                    n_fld := n_fld + 1;
                    pc_d := std_logic_vector(m_pc); pc4_d := std_logic_vector(m_pc + 4); k_pcd := false;
                elsif sd = '0' then
                    m_ins_d := v;
                    m_val_d := '1';
                    pc_d := std_logic_vector(m_pc); pc4_d := std_logic_vector(m_pc + 4); k_pcd := true;
                else
                    n_std := n_std + 1;
                end if;
                if sf = '1' then
                    n_stf := n_stf + 1;
                else
                    case psrc is
                        when "01" =>
                            m_pc := unsigned(tsum(31 downto 1) & '0');
                            n_jmp := n_jmp + 1;
                            if jlv = '1' then n_jalr := n_jalr + 1; end if;
                        when "10" | "11" => m_pc := (others => '0');
                        when others => m_pc := m_pc + 4;
                    end case;
                end if;
            end if;
            wait for 1 ns;
        end procedure;

        variable v : w32;
        variable op : std_logic_vector(3 downto 0);
        variable isrc, rsrc, rsrc_m : std_logic_vector(2 downto 0);
        variable psrc, fa_c, fb_c : std_logic_vector(1 downto 0);
        variable asrc, sa, jl, rw, sf, sd, fd, rs : std_logic;
        variable k : natural;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        step(x"00000000", "0000", "000", '0', '0', '0', '0', "000", "000", "00", "00", "00", '0', '0', '0', '1', x"00000000");
        for i in 1 to 31 + 4 loop
            v := rnd_word;
            v(11 downto 7) := std_logic_vector(to_unsigned(i mod 32, 5));
            step(v, "0000", "000", '0', '0', '0', '1', "000", "001", "00", "00", "00", '0', '0', '0', '0', rnd_word);
        end loop;

        for n in 1 to N_RANDOM loop
            v := rnd_word;
            if rnd(4) = 0 then
                v(19 downto 15) := v(24 downto 20);
            end if;
            op := OPS(rnd(OPS'length));
            isrc := std_logic_vector(to_unsigned(rnd(5), 3));
            asrc := rnd_sl(2);
            sa := rnd_sl(4);
            jl := rnd_sl(3);
            rw := not rnd_sl(4);
            case rnd(3) is
                when 0 => rsrc := "000";
                when 1 => rsrc := "010";
                when others => rsrc := "011";
            end case;
            if rnd(3) = 0 then rsrc_m := "001"; else rsrc_m := "000"; end if;
            k := rnd(20);
            if k < 13 then psrc := "00";
            elsif k < 19 then psrc := "01";
            elsif k = 19 and rnd(2) = 0 then psrc := "10";
            else psrc := "11";
            end if;
            fa_c := std_logic_vector(to_unsigned(rnd(3), 2));
            fb_c := std_logic_vector(to_unsigned(rnd(3), 2));
            sf := rnd_sl(8);
            sd := rnd_sl(8);
            if sd = '0' then fd := rnd_sl(8); else fd := '0'; end if;
            rs := rnd_sl(500);
            if rs = '1' or not k_rdw then
                rw := '0';
            end if;
            if rs = '1' then
                sf := '0'; sd := '0'; fd := '0';
            end if;
            step(v, op, isrc, asrc, sa, jl, rw, rsrc, rsrc_m, psrc, fa_c, fb_c, sf, sd, fd, rs, rnd_word);
        end loop;

        report "tb_datapath: " & integer'image(cycles) & " cycles, " & integer'image(checks) & " checks, forwarding "
            & integer'image(n_fwd) & ", stall_f " & integer'image(n_stf) & ", stall_d " & integer'image(n_std)
            & ", flush_d " & integer'image(n_fld) & ", jumps " & integer'image(n_jmp) & " (jalr " & integer'image(n_jalr)
            & "), loads " & integer'image(n_ld) & ", reg writes " & integer'image(n_w) & ", resets " & integer'image(n_rst)
            & ", " & integer'image(errors) & " errors";
        assert errors = 0 report "tb_datapath FAILED" severity failure;
        report "tb_datapath PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;