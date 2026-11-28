library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_hazard_unit is
end entity tb_hazard_unit;

architecture sim of tb_hazard_unit is
    signal rs1_e, rs2_e, rd_m, rd_w, rs1_d, rs2_d, rd_e : std_logic_vector(4 downto 0) := (others => '0');
    signal reg_write_m, reg_write_w, load_e             : std_logic := '0';
    signal pc_src_e                                     : std_logic_vector(1 downto 0) := "00";
    signal forward_a_e, forward_b_e                     : std_logic_vector(1 downto 0);
    signal stall_f, stall_d, flush_d, flush_e           : std_logic;

    type nat_arr_t is array (natural range <>) of natural;
    constant REGS : nat_arr_t := (0, 1, 16, 31);

    function r5(n : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(n, 5));
    end function;

    function fwd(rs, rdm, rdw : std_logic_vector(4 downto 0); wm, ww : std_logic) return std_logic_vector is
    begin
        if rs /= "00000" and rs = rdm and wm = '1' then
            return "10";
        elsif rs /= "00000" and rs = rdw and ww = '1' then
            return "01";
        else
            return "00";
        end if;
    end function;
begin
    dut : entity work.hazard_unit
        port map(
            rs1_e       => rs1_e,
            rs2_e       => rs2_e,
            rd_m        => rd_m,
            reg_write_m => reg_write_m,
            rd_w        => rd_w,
            reg_write_w => reg_write_w,
            rs1_d       => rs1_d,
            rs2_d       => rs2_d,
            rd_e        => rd_e,
            load_e      => load_e,
            pc_src_e    => pc_src_e,
            forward_a_e => forward_a_e,
            forward_b_e => forward_b_e,
            stall_f     => stall_f,
            stall_d     => stall_d,
            flush_d     => flush_d,
            flush_e     => flush_e
        );

    stim : process
        variable errors, checks : natural := 0;
        variable s1             : positive := 3;
        variable s2             : positive := 71;
        variable r              : real;
        variable n_fa, n_fb     : nat_arr_t(0 to 3) := (others => 0);
        variable n_stall        : natural := 0;
        variable n_flush        : natural := 0;
        variable wm, ww, ld     : std_logic;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        impure function rnd_sl return std_logic is
        begin
            if rnd(2) = 1 then return '1'; else return '0'; end if;
        end function;

        impure function rnd_r5 return std_logic_vector is
        begin
            if rnd(4) = 0 then
                return r5(REGS(rnd(4)));
            else
                return r5(rnd(32));
            end if;
        end function;

        procedure chk(ok : boolean; what : string) is
        begin
            checks := checks + 1;
            if not ok then
                errors := errors + 1;
                if errors <= 20 then
                    report "rs1_e=" & integer'image(to_integer(unsigned(rs1_e)))
                        & " rs2_e=" & integer'image(to_integer(unsigned(rs2_e)))
                        & " rd_m=" & integer'image(to_integer(unsigned(rd_m))) & " reg_write_m=" & std_logic'image(reg_write_m)
                        & " rd_w=" & integer'image(to_integer(unsigned(rd_w))) & " reg_write_w=" & std_logic'image(reg_write_w)
                        & " rs1_d=" & integer'image(to_integer(unsigned(rs1_d)))
                        & " rs2_d=" & integer'image(to_integer(unsigned(rs2_d)))
                        & " rd_e=" & integer'image(to_integer(unsigned(rd_e))) & " load_e=" & std_logic'image(load_e)
                        & " pc_src_e=" & to_string(pc_src_e) & ": " & what severity error;
                end if;
            end if;
        end procedure;

        procedure bit_chk(got, exp : std_logic; name : string) is
        begin
            chk(got = exp, name & " got " & std_logic'image(got) & " exp " & std_logic'image(exp));
        end procedure;

        procedure apply(a1e, a2e, am, aw, a1d, a2d, ae : std_logic_vector(4 downto 0);
                        m, w, l : std_logic; ps : std_logic_vector(1 downto 0)) is
            variable efa, efb : std_logic_vector(1 downto 0);
            variable st, fl   : std_logic;
        begin
            rs1_e <= a1e; rs2_e <= a2e; rd_m <= am; rd_w <= aw;
            rs1_d <= a1d; rs2_d <= a2d; rd_e <= ae;
            reg_write_m <= m; reg_write_w <= w; load_e <= l; pc_src_e <= ps;
            wait for 1 ns;
            efa := fwd(a1e, am, aw, m, w);
            efb := fwd(a2e, am, aw, m, w);
            if l = '1' and ae /= "00000" and (a1d = ae or a2d = ae) then st := '1'; else st := '0'; end if;
            if ps /= "00" then fl := '1'; else fl := '0'; end if;
            n_fa(to_integer(unsigned(efa))) := n_fa(to_integer(unsigned(efa))) + 1;
            n_fb(to_integer(unsigned(efb))) := n_fb(to_integer(unsigned(efb))) + 1;
            if st = '1' then n_stall := n_stall + 1; end if;
            if fl = '1' then n_flush := n_flush + 1; end if;
            chk(forward_a_e = efa, "forward_a_e got " & to_string(forward_a_e) & " exp " & to_string(efa));
            chk(forward_b_e = efb, "forward_b_e got " & to_string(forward_b_e) & " exp " & to_string(efb));
            bit_chk(stall_f, st, "stall_f");
            bit_chk(stall_d, st, "stall_d");
            bit_chk(flush_d, fl, "flush_d");
            bit_chk(flush_e, st or fl, "flush_e");
        end procedure;
    begin
        for i1e in REGS'range loop
            for i2e in REGS'range loop
                for im in REGS'range loop
                    for iw in REGS'range loop
                        for i1d in REGS'range loop
                            for i2d in REGS'range loop
                                for ie in REGS'range loop
                                    for c in 0 to 31 loop
                                        wm := std_logic(to_unsigned(c, 5)(0));
                                        ww := std_logic(to_unsigned(c, 5)(1));
                                        ld := std_logic(to_unsigned(c, 5)(2));
                                        apply(r5(REGS(i1e)), r5(REGS(i2e)), r5(REGS(im)), r5(REGS(iw)),
                                              r5(REGS(i1d)), r5(REGS(i2d)), r5(REGS(ie)), wm, ww, ld,
                                              std_logic_vector(to_unsigned(c / 8, 2)));
                                    end loop;
                                end loop;
                            end loop;
                        end loop;
                    end loop;
                end loop;
            end loop;
        end loop;

        for a in 0 to 31 loop
            for m in 0 to 31 loop
                for w in 0 to 31 loop
                    for c in 0 to 3 loop
                        apply(r5(a), r5(31 - a), r5(m), r5(w), r5(a), r5(31 - a), r5(m),
                              std_logic(to_unsigned(c, 2)(0)), std_logic(to_unsigned(c, 2)(1)), '0', "00");
                    end loop;
                    apply(r5(31 - m), r5(a), "00000", "00000", r5(a), r5(w), r5(m), '0', '0', '1', "00");
                end loop;
            end loop;
        end loop;

        for n in 1 to 300000 loop
            apply(rnd_r5, rnd_r5, rnd_r5, rnd_r5, rnd_r5, rnd_r5, rnd_r5, rnd_sl, rnd_sl, rnd_sl,
                  std_logic_vector(to_unsigned(rnd(4), 2)));
        end loop;

        report "forward_a 00/01/10 = " & integer'image(n_fa(0)) & "/" & integer'image(n_fa(1)) & "/" & integer'image(n_fa(2))
            & ", forward_b 00/01/10 = " & integer'image(n_fb(0)) & "/" & integer'image(n_fb(1)) & "/" & integer'image(n_fb(2))
            & ", stalls " & integer'image(n_stall) & ", flushes " & integer'image(n_flush) severity note;
        if errors = 0 then
            report "tb_hazard_unit: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_hazard_unit: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & ")" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;