library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_controller is
    generic(
        N_RANDOM : natural  := 300000;
        SEED1    : positive := 11;
        SEED2    : positive := 13
    );
end entity tb_controller;

architecture sim of tb_controller is
    constant T : time := 10 ns;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal instr        : std_logic_vector(31 downto 0) := (others => '0');
    signal valid_d      : std_logic := '0';
    signal zero         : std_logic := '0';
    signal addr_lo      : std_logic_vector(1 downto 0) := "00";
    signal take_irq     : std_logic := '0';
    signal flush_e      : std_logic := '0';
    signal reg_write    : std_logic;
    signal reg_write_m  : std_logic;
    signal alu_src      : std_logic;
    signal illegal      : std_logic;
    signal misaligned   : std_logic;
    signal pc_src       : std_logic_vector(1 downto 0);
    signal alu_op       : std_logic_vector(3 downto 0);
    signal imm_src      : std_logic_vector(2 downto 0);
    signal mem_write    : std_logic;
    signal result_src   : std_logic_vector(2 downto 0);
    signal jalr         : std_logic;
    signal alu_src_a    : std_logic;
    signal csr_we       : std_logic;
    signal mret         : std_logic;
    signal load_e       : std_logic;
    signal funct3_m     : std_logic_vector(2 downto 0);
    signal result_src_m : std_logic_vector(2 downto 0);
    signal done         : boolean := false;

    type exp_t is record
        illegal, reg_write, mem_write, branch, jump, jalr, mem_access : std_logic;
        alu_src, alu_src_a : std_logic;
        alu_op     : std_logic_vector(3 downto 0);
        imm_src    : std_logic_vector(2 downto 0);
        result_src : std_logic_vector(2 downto 0);
        uses_alu, uses_imm : boolean;
    end record;

    constant NONE : exp_t := (illegal => '0', reg_write => '0', mem_write => '0', branch => '0', jump => '0',
                              jalr => '0', mem_access => '0', alu_src => '0', alu_src_a => '0',
                              alu_op => "0000", imm_src => "000", result_src => "000",
                              uses_alu => false, uses_imm => false);

    type stage_t is record
        e      : exp_t;
        f3     : std_logic_vector(2 downto 0);
        valid  : std_logic;
        bubble : boolean;
        mis    : std_logic;
    end record;

    constant BUBBLE : stage_t := (e => NONE, f3 => "000", valid => '0', bubble => true, mis => '0');

    function decode(i : std_logic_vector(31 downto 0)) return exp_t is
        variable e  : exp_t := NONE;
        variable op : std_logic_vector(6 downto 0) := i(6 downto 0);
        variable f3 : std_logic_vector(2 downto 0) := i(14 downto 12);
        variable f7 : std_logic_vector(6 downto 0) := i(31 downto 25);
    begin
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
                    when others =>
                        e.illegal := '1';
                end case;
            when others =>
                e.illegal := '1';
        end case;
        return e;
    end function;
begin
    clk <= not clk after T / 2 when not done else '0';

    dut : entity work.controller
        port map(
            clk          => clk,
            rst          => rst,
            instr        => instr,
            valid_d      => valid_d,
            zero         => zero,
            addr_lo      => addr_lo,
            take_irq     => take_irq,
            flush_e      => flush_e,
            reg_write    => reg_write,
            reg_write_m  => reg_write_m,
            alu_src      => alu_src,
            illegal      => illegal,
            misaligned   => misaligned,
            pc_src       => pc_src,
            alu_op       => alu_op,
            imm_src      => imm_src,
            mem_write    => mem_write,
            result_src   => result_src,
            jalr         => jalr,
            alu_src_a    => alu_src_a,
            csr_we       => csr_we,
            mret         => mret,
            load_e       => load_e,
            funct3_m     => funct3_m,
            result_src_m => result_src_m
        );

    stim : process
        variable errors, checks, cycles : natural := 0;
        variable s1  : positive := SEED1;
        variable s2  : positive := SEED2;
        variable r   : real;
        variable st_e, st_m, st_w : stage_t := BUBBLE;
        variable n_flush, n_bub, n_mis, n_taken, n_ld, n_st, n_ill, n_rst : natural := 0;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n))) mod n;
        end function;

        impure function rnd_slv(w : positive) return std_logic_vector is
            variable x : std_logic_vector(w - 1 downto 0);
        begin
            for k in x'range loop
                if rnd(2) = 1 then x(k) := '1'; else x(k) := '0'; end if;
            end loop;
            return x;
        end function;

        procedure chk(ok : boolean; stage, what : string) is
        begin
            checks := checks + 1;
            if not ok then
                errors := errors + 1;
                if errors <= 30 then
                    report "cycle " & integer'image(cycles) & " instr_d=0x" & to_hstring(instr) & " valid_d=" & std_logic'image(valid_d)
                        & " zero=" & std_logic'image(zero) & " addr_lo=" & to_string(addr_lo) & " flush_e=" & std_logic'image(flush_e)
                        & " rst=" & std_logic'image(rst) & ": [" & stage & "] " & what severity error;
                end if;
            end if;
        end procedure;

        procedure bit_chk(got, exp : std_logic; stage, name : string) is
        begin
            chk(got = exp, stage, name & " got " & std_logic'image(got) & " exp " & std_logic'image(exp));
        end procedure;

        procedure vec_chk(got, exp : std_logic_vector; stage, name : string) is
        begin
            chk(got = exp, stage, name & " got " & to_string(got) & " exp " & to_string(exp));
        end procedure;

        function calc_mis(s : stage_t; a : std_logic_vector(1 downto 0)) return std_logic is
        begin
            if s.bubble or s.e.mem_access = '0' then
                return '0';
            elsif s.f3(1 downto 0) = "01" and a(0) = '1' then
                return '1';
            elsif s.f3(1 downto 0) = "10" and a /= "00" then
                return '1';
            else
                return '0';
            end if;
        end function;

        procedure step(x : std_logic_vector(31 downto 0); v, z : std_logic; a : std_logic_vector(1 downto 0);
                       fe, do_rst : std_logic) is
            variable d     : exp_t;
            variable mis_e : std_logic;
            variable tk    : std_logic;
            variable ep    : std_logic_vector(1 downto 0);
        begin
            instr   <= x;
            valid_d <= v;
            zero    <= z;
            addr_lo <= a;
            flush_e <= fe;
            rst     <= do_rst;
            take_irq <= '0';
            wait for 2 ns;
            cycles := cycles + 1;

            d := decode(x);
            if d.uses_imm then
                vec_chk(imm_src, d.imm_src, "D", "imm_src");
            end if;

            mis_e := calc_mis(st_e, a);
            if st_e.bubble then
                n_bub := n_bub + 1;
                bit_chk(load_e, '0', "E bubble", "load_e");
                bit_chk(illegal, '0', "E bubble", "illegal");
                bit_chk(misaligned, '0', "E bubble", "misaligned");
                vec_chk(pc_src, "00", "E bubble", "pc_src");
            else
                tk := (st_e.e.branch and (st_e.f3(2) xor z xor st_e.f3(0))) or st_e.e.jump;
                if tk = '1' then ep := "01"; n_taken := n_taken + 1; else ep := "00"; end if;
                vec_chk(pc_src, ep, "E", "pc_src");
                bit_chk(illegal, st_e.e.illegal and st_e.valid, "E", "illegal");
                bit_chk(misaligned, mis_e, "E", "misaligned");
                bit_chk(load_e, st_e.e.mem_access and st_e.e.reg_write, "E", "load_e");
                if st_e.e.reg_write = '1' then
                    vec_chk(result_src, st_e.e.result_src, "E", "result_src");
                end if;
                if st_e.e.uses_alu then
                    vec_chk(alu_op, st_e.e.alu_op, "E", "alu_op");
                    bit_chk(alu_src, st_e.e.alu_src, "E", "alu_src");
                    bit_chk(alu_src_a, st_e.e.alu_src_a, "E", "alu_src_a");
                end if;
                if st_e.e.jump = '1' then
                    bit_chk(jalr, st_e.e.jalr, "E", "jalr");
                end if;
                if mis_e = '1' then n_mis := n_mis + 1; end if;
                if st_e.e.illegal = '1' and st_e.valid = '1' then n_ill := n_ill + 1; end if;
            end if;

            if st_m.bubble then
                bit_chk(mem_write, '0', "M bubble", "mem_write");
                bit_chk(reg_write_m, '0', "M bubble", "reg_write_m");
            else
                bit_chk(mem_write, st_m.e.mem_write and not st_m.mis, "M", "mem_write");
                bit_chk(reg_write_m, st_m.e.reg_write and not st_m.mis, "M", "reg_write_m");
                if st_m.e.reg_write = '1' then
                    vec_chk(result_src_m, st_m.e.result_src, "M", "result_src_m");
                end if;
                if st_m.e.mem_access = '1' then
                    vec_chk(funct3_m, st_m.f3, "M", "funct3_m");
                end if;
                if st_m.e.mem_write = '1' and st_m.mis = '0' then n_st := n_st + 1; end if;
                if st_m.e.mem_access = '1' and st_m.e.reg_write = '1' then n_ld := n_ld + 1; end if;
            end if;

            if st_w.bubble then
                bit_chk(reg_write, '0', "W bubble", "reg_write");
            else
                bit_chk(reg_write, st_w.e.reg_write and not st_w.mis, "W", "reg_write");
            end if;

            wait until rising_edge(clk);
            if do_rst = '1' then
                n_rst := n_rst + 1;
                st_w := BUBBLE;
                st_m := BUBBLE;
                st_e := BUBBLE;
            else
                st_w := st_m;
                st_m := st_e;
                st_m.mis := mis_e;
                if fe = '1' then
                    n_flush := n_flush + 1;
                    st_e := BUBBLE;
                else
                    st_e := (e => d, f3 => x(14 downto 12), valid => v, bubble => false, mis => '0');
                end if;
            end if;
            wait for 1 ns;
        end procedure;

        type f7_arr is array (natural range <>) of std_logic_vector(6 downto 0);
        constant F7S : f7_arr := ("0000000", "0100000", "0000001", "1111111", "0011000");
        variable v  : std_logic_vector(31 downto 0);
        variable fe : std_logic;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        step(x"00000000", '0', '0', "00", '0', '1');
        step(x"00000000", '0', '0', "00", '0', '1');

        for op in 0 to 127 loop
            for f3 in 0 to 7 loop
                for fi in F7S'range loop
                    v := rnd_slv(32);
                    v(6 downto 0) := std_logic_vector(to_unsigned(op, 7));
                    v(14 downto 12) := std_logic_vector(to_unsigned(f3, 3));
                    v(31 downto 25) := F7S(fi);
                    if v = x"30200073" then v(20) := '0'; end if;
                    if rnd(8) = 0 then fe := '1'; else fe := '0'; end if;
                    step(v, '1', rnd_slv(1)(0), rnd_slv(2), fe, '0');
                end loop;
            end loop;
        end loop;

        for n in 1 to N_RANDOM loop
            v := rnd_slv(32);
            if rnd(10) < 6 then
                case rnd(8) is
                    when 0 => v(6 downto 0) := "1100011";
                    when 1 => v(6 downto 0) := "0000011";
                    when 2 => v(6 downto 0) := "0100011";
                    when 3 => v(6 downto 0) := "1101111";
                    when 4 => v(6 downto 0) := "1100111"; v(14 downto 12) := "000";
                    when 5 => v(6 downto 0) := "0110011"; v(31 downto 25) := "0000000";
                    when 6 => v(6 downto 0) := "0010011";
                    when others => v(6 downto 0) := "0110111";
                end case;
            end if;
            if v = x"30200073" then v(20) := '0'; end if;
            if rnd(6) = 0 then fe := '1'; else fe := '0'; end if;
            if rnd(10) = 0 then
                step(x"00000000", '0', rnd_slv(1)(0), rnd_slv(2), fe, '0');
            elsif rnd(400) = 0 then
                step(v, '1', rnd_slv(1)(0), rnd_slv(2), '0', '1');
            else
                step(v, '1', rnd_slv(1)(0), rnd_slv(2), fe, '0');
            end if;
        end loop;

        report "tb_controller: " & integer'image(cycles) & " cycles, flush_e " & integer'image(n_flush) & ", E bubbles " & integer'image(n_bub)
            & ", taken " & integer'image(n_taken) & ", misaligned " & integer'image(n_mis) & ", loads in M " & integer'image(n_ld)
            & ", stores in M " & integer'image(n_st) & ", illegal " & integer'image(n_ill) & ", resets " & integer'image(n_rst) severity note;
        if errors = 0 then
            report "tb_controller: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_controller: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & ")" severity error;
        end if;
        done <= true;
        std.env.stop;
        wait;
    end process;
end architecture sim;