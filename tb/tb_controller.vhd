library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_controller is
end entity tb_controller;

architecture sim of tb_controller is
    signal instr      : std_logic_vector(31 downto 0) := (others => '0');
    signal zero       : std_logic := '0';
    signal addr_lo    : std_logic_vector(1 downto 0) := "00";
    signal take_irq   : std_logic := '0';
    signal reg_write  : std_logic;
    signal alu_src    : std_logic;
    signal illegal    : std_logic;
    signal misaligned : std_logic;
    signal pc_src     : std_logic_vector(1 downto 0);
    signal alu_op     : std_logic_vector(3 downto 0);
    signal imm_src    : std_logic_vector(2 downto 0);
    signal mem_write  : std_logic;
    signal result_src : std_logic_vector(2 downto 0);
    signal jalr       : std_logic;
    signal alu_src_a  : std_logic;
    signal csr_we     : std_logic;
    signal mret       : std_logic;

    type exp_t is record
        illegal, reg_write, mem_write, branch, jump, jalr, mem_access, csr_we, mret : std_logic;
        alu_src, alu_src_a : std_logic;
        alu_op     : std_logic_vector(3 downto 0);
        imm_src    : std_logic_vector(2 downto 0);
        result_src : std_logic_vector(2 downto 0);
        uses_alu, uses_imm : boolean;
    end record;

    function decode(i : std_logic_vector(31 downto 0)) return exp_t is
        variable e : exp_t;
        variable op : std_logic_vector(6 downto 0) := i(6 downto 0);
        variable f3 : std_logic_vector(2 downto 0) := i(14 downto 12);
        variable f7 : std_logic_vector(6 downto 0) := i(31 downto 25);
    begin
        e := (illegal => '0', reg_write => '0', mem_write => '0', branch => '0', jump => '0',
              jalr => '0', mem_access => '0', csr_we => '0', mret => '0', alu_src => '0',
              alu_src_a => '0', alu_op => "0000", imm_src => "000", result_src => "000",
              uses_alu => false, uses_imm => false);
        case op is
            when "0110011" =>
                if f7 = "0000000" or (f7 = "0100000" and (f3 = "000" or f3 = "101")) then
                    e.reg_write := '1'; e.alu_op := f7(5) & f3; e.uses_alu := true;
                else
                    e.illegal := '1';
                end if;
            when "0010011" =>
                if f3 = "001" and f7 /= "0000000" then
                    e.illegal := '1';
                elsif f3 = "101" and f7 /= "0000000" and f7 /= "0100000" then
                    e.illegal := '1';
                else
                    e.reg_write := '1'; e.alu_src := '1'; e.uses_alu := true; e.uses_imm := true;
                    if f3 = "101" then e.alu_op := i(30) & f3; else e.alu_op := '0' & f3; end if;
                end if;
            when "1100011" =>
                case f3 is
                    when "000" | "001" => e.alu_op := "1000";
                    when "100" | "101" => e.alu_op := "0010";
                    when "110" | "111" => e.alu_op := "0011";
                    when others => e.illegal := '1';
                end case;
                if e.illegal = '0' then
                    e.branch := '1'; e.imm_src := "010"; e.uses_alu := true; e.uses_imm := true;
                end if;
            when "0000011" =>
                if f3 = "011" or f3 = "110" or f3 = "111" then
                    e.illegal := '1';
                else
                    e.reg_write := '1'; e.alu_src := '1'; e.result_src := "001"; e.mem_access := '1';
                    e.uses_alu := true; e.uses_imm := true;
                end if;
            when "0100011" =>
                if f3 = "000" or f3 = "001" or f3 = "010" then
                    e.mem_write := '1'; e.alu_src := '1'; e.imm_src := "001"; e.mem_access := '1';
                    e.uses_alu := true; e.uses_imm := true;
                else
                    e.illegal := '1';
                end if;
            when "1101111" =>
                e.reg_write := '1'; e.jump := '1'; e.imm_src := "011"; e.result_src := "010"; e.uses_imm := true;
            when "1100111" =>
                if f3 = "000" then
                    e.reg_write := '1'; e.jump := '1'; e.jalr := '1'; e.result_src := "010"; e.uses_imm := true;
                else
                    e.illegal := '1';
                end if;
            when "0110111" =>
                e.reg_write := '1'; e.imm_src := "100"; e.result_src := "011"; e.uses_imm := true;
            when "0010111" =>
                e.reg_write := '1'; e.imm_src := "100"; e.alu_src := '1'; e.alu_src_a := '1';
                e.uses_alu := true; e.uses_imm := true;
            when "1110011" =>
                case f3 is
                    when "001" | "010" | "011" | "101" | "110" | "111" =>
                        e.reg_write := '1'; e.result_src := "100";
                        if f3(1 downto 0) = "01" or i(19 downto 15) /= "00000" then
                            e.csr_we := '1';
                        end if;
                    when "000" =>
                        if i = x"30200073" then e.mret := '1'; else e.illegal := '1'; end if;
                    when others =>
                        e.illegal := '1';
                end case;
            when others =>
                e.illegal := '1';
        end case;
        return e;
    end function;
begin
    dut: entity work.controller
        port map(instr => instr, zero => zero, addr_lo => addr_lo, take_irq => take_irq,
                 reg_write => reg_write, alu_src => alu_src, illegal => illegal,
                 misaligned => misaligned, pc_src => pc_src, alu_op => alu_op, imm_src => imm_src,
                 mem_write => mem_write, result_src => result_src, jalr => jalr,
                 alu_src_a => alu_src_a, csr_we => csr_we, mret => mret);

    stim: process
        variable errors, checks : natural := 0;
        variable s1, s2 : positive := 11;
        variable r : real;
        variable v : std_logic_vector(31 downto 0);

        impure function rnd_slv(w : positive) return std_logic_vector is
            variable x : std_logic_vector(w - 1 downto 0);
        begin
            for k in x'range loop
                uniform(s1, s2, r);
                if r < 0.5 then x(k) := '0'; else x(k) := '1'; end if;
            end loop;
            return x;
        end function;

        procedure chk(ok : boolean; what : string) is
        begin
            checks := checks + 1;
            if not ok then
                errors := errors + 1;
                if errors <= 20 then
                    report "instr=" & to_hstring(instr) & " zero=" & std_logic'image(zero)
                        & " addr_lo=" & to_string(addr_lo) & " take_irq=" & std_logic'image(take_irq)
                        & ": " & what severity error;
                end if;
            end if;
        end procedure;

        procedure bit_chk(got, exp : std_logic; name : string) is
        begin
            chk(got = exp, name & " got " & std_logic'image(got) & " exp " & std_logic'image(exp));
        end procedure;

        procedure apply(x : std_logic_vector(31 downto 0); z : std_logic; a : std_logic_vector(1 downto 0); t : std_logic) is
            variable e : exp_t;
            variable f3 : std_logic_vector(2 downto 0);
            variable mis, taken : std_logic;
            variable exp_pc : std_logic_vector(1 downto 0);
        begin
            instr <= x; zero <= z; addr_lo <= a; take_irq <= t;
            wait for 1 ns;
            e := decode(x);
            f3 := x(14 downto 12);
            mis := '0';
            if e.mem_access = '1' and f3(1 downto 0) = "01" and a(0) = '1' then mis := '1'; end if;
            if e.mem_access = '1' and f3(1 downto 0) = "10" and a /= "00" then mis := '1'; end if;
            taken := (e.branch and (f3(2) xor z xor f3(0))) or e.jump;
            if t = '1' then exp_pc := "10";
            elsif e.mret = '1' then exp_pc := "11";
            elsif taken = '1' then exp_pc := "01";
            else exp_pc := "00";
            end if;
            bit_chk(reg_write, e.reg_write and not mis and not t, "reg_write");
            bit_chk(mem_write, e.mem_write and not mis and not t, "mem_write");
            bit_chk(csr_we, e.csr_we and not t, "csr_we");
            bit_chk(mret, e.mret and not t, "mret");
            bit_chk(illegal, e.illegal and not t, "illegal");
            bit_chk(misaligned, mis and not t, "misaligned");
            chk(pc_src = exp_pc, "pc_src got " & to_string(pc_src) & " exp " & to_string(exp_pc));
            if e.reg_write = '1' then
                chk(result_src = e.result_src, "result_src got " & to_string(result_src) & " exp " & to_string(e.result_src));
            end if;
            if e.uses_imm then
                chk(imm_src = e.imm_src, "imm_src got " & to_string(imm_src) & " exp " & to_string(e.imm_src));
            end if;
            if e.uses_alu then
                chk(alu_op = e.alu_op, "alu_op got " & to_string(alu_op) & " exp " & to_string(e.alu_op));
                bit_chk(alu_src, e.alu_src, "alu_src");
                bit_chk(alu_src_a, e.alu_src_a, "alu_src_a");
            end if;
            if e.jump = '1' then
                bit_chk(jalr, e.jalr, "jalr");
            end if;
            chk(not (t = '1' and (reg_write = '1' or mem_write = '1' or csr_we = '1' or mret = '1'
                                  or illegal = '1' or misaligned = '1')), "invariant take_irq squashes all effects");
            chk(not (misaligned = '1' and (reg_write = '1' or mem_write = '1')), "invariant misaligned => no writes");
        end procedure;

        type f7_arr is array (natural range <>) of std_logic_vector(6 downto 0);
        constant F7S : f7_arr := ("0000000", "0100000", "0000001", "1111111", "0011000");
        variable z : std_logic;
        variable a : std_logic_vector(1 downto 0);
        variable t : std_logic;
    begin
        for op in 0 to 127 loop
            for f3 in 0 to 7 loop
                for fi in F7S'range loop
                    v := rnd_slv(32);
                    v(6 downto 0) := std_logic_vector(to_unsigned(op, 7));
                    v(14 downto 12) := std_logic_vector(to_unsigned(f3, 3));
                    v(31 downto 25) := F7S(fi);
                    if fi = 0 then v(19 downto 15) := "00000"; end if;
                    for k in 0 to 15 loop
                        z := std_logic(to_unsigned(k, 4)(0));
                        t := std_logic(to_unsigned(k, 4)(1));
                        a := std_logic_vector(to_unsigned(k / 4, 2));
                        apply(v, z, a, t);
                    end loop;
                end loop;
            end loop;
        end loop;

        for f3 in 0 to 7 loop
            for rs1 in 0 to 31 loop
                v := rnd_slv(32);
                v(6 downto 0) := "1110011";
                v(14 downto 12) := std_logic_vector(to_unsigned(f3, 3));
                v(19 downto 15) := std_logic_vector(to_unsigned(rs1, 5));
                apply(v, '0', "00", '0');
                apply(v, '1', "00", '1');
            end loop;
        end loop;

        for k in 0 to 15 loop
            z := std_logic(to_unsigned(k, 4)(0));
            t := std_logic(to_unsigned(k, 4)(1));
            a := std_logic_vector(to_unsigned(k / 4, 2));
            apply(x"30200073", z, a, t);
            apply(x"00000073", z, a, t);
            apply(x"0000006F", z, a, t);
            apply(x"00008067", z, a, t);
            apply(x"00000063", z, a, t);
            apply(x"00001063", z, a, t);
            apply(x"00002003", z, a, t);
            apply(x"00001023", z, a, t);
        end loop;

        for n in 1 to 300000 loop
            v := rnd_slv(32);
            uniform(s1, s2, r);
            if r < 0.6 then
                case integer(floor(r * 10.0)) is
                    when 0 => v(6 downto 0) := "1100011";
                    when 1 => v(6 downto 0) := "0000011";
                    when 2 => v(6 downto 0) := "0100011";
                    when 3 => v(6 downto 0) := "1110011";
                    when 4 => v(6 downto 0) := "1101111";
                    when others => v(6 downto 0) := "1100111";
                end case;
            end if;
            a := rnd_slv(2);
            z := rnd_slv(1)(0);
            t := rnd_slv(1)(0);
            apply(v, z, a, t);
        end loop;

        if errors = 0 then
            report "tb_controller: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_controller: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & ")" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;