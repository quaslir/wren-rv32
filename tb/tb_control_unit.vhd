library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
 
entity tb_control_unit is
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
    signal result_src : std_logic_vector(2 downto 0);
    signal mem_access : std_logic;
    signal alu_src_a  : std_logic;
    signal jump       : std_logic;
    signal jalr       : std_logic;
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
    dut: entity work.control_unit
        port map(instr => instr, reg_write => reg_write, alu_op => alu_op, alu_src => alu_src,
                 illegal => illegal, imm_src => imm_src, branch => branch, mem_write => mem_write,
                 result_src => result_src, mem_access => mem_access, alu_src_a => alu_src_a,
                 jump => jump, jalr => jalr, csr_we => csr_we, mret => mret);
 
    stim: process
        variable errors, checks : natural := 0;
        variable s1, s2 : positive := 7;
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
                    report "instr=" & to_hstring(instr) & ": " & what severity error;
                end if;
            end if;
        end procedure;
 
        procedure bit_chk(got, exp : std_logic; name : string) is
        begin
            chk(got = exp, name & " got " & std_logic'image(got) & " exp " & std_logic'image(exp));
        end procedure;
 
        procedure apply(x : std_logic_vector(31 downto 0)) is
            variable e : exp_t;
        begin
            instr <= x;
            wait for 1 ns;
            e := decode(x);
            bit_chk(illegal, e.illegal, "illegal");
            bit_chk(reg_write, e.reg_write, "reg_write");
            bit_chk(mem_write, e.mem_write, "mem_write");
            bit_chk(branch, e.branch, "branch");
            bit_chk(jump, e.jump, "jump");
            bit_chk(jalr, e.jalr, "jalr");
            bit_chk(mem_access, e.mem_access, "mem_access");
            bit_chk(csr_we, e.csr_we, "csr_we");
            bit_chk(mret, e.mret, "mret");
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
            chk(not (jalr = '1' and jump = '0'), "invariant jalr => jump");
            chk(not (jump = '1' and (reg_write = '0' or result_src /= "010")), "invariant jump => rd <- pc+4");
            chk(not (csr_we = '1' and result_src /= "100"), "invariant csr_we => result_src 100");
            chk(not (mret = '1' and (reg_write = '1' or jump = '1' or branch = '1' or mem_write = '1' or csr_we = '1')),
                "invariant mret has no other effects");
            chk(not (illegal = '1' and (reg_write = '1' or mem_write = '1' or branch = '1' or jump = '1'
                                        or mem_access = '1' or csr_we = '1' or mret = '1')),
                "invariant illegal has no effects");
            chk(not (mem_write = '1' and mem_access = '0'), "invariant mem_write => mem_access");
            chk(not (result_src = "001" and reg_write = '1' and mem_access = '0'), "invariant load result => mem_access");
        end procedure;
    begin
        for op in 0 to 127 loop
            for f3 in 0 to 7 loop
                for f7 in 0 to 127 loop
                    for k in 0 to 2 loop
                        v := rnd_slv(32);
                        v(6 downto 0) := std_logic_vector(to_unsigned(op, 7));
                        v(14 downto 12) := std_logic_vector(to_unsigned(f3, 3));
                        v(31 downto 25) := std_logic_vector(to_unsigned(f7, 7));
                        if k = 0 then v(19 downto 15) := "00000"; end if;
                        apply(v);
                    end loop;
                end loop;
            end loop;
        end loop;
 
        for f3 in 0 to 7 loop
            for rs1 in 0 to 31 loop
                for k in 0 to 15 loop
                    v := rnd_slv(32);
                    v(6 downto 0) := "1110011";
                    v(14 downto 12) := std_logic_vector(to_unsigned(f3, 3));
                    v(19 downto 15) := std_logic_vector(to_unsigned(rs1, 5));
                    apply(v);
                end loop;
            end loop;
        end loop;
 
        apply(x"30200073");
        apply(x"00000073");
        apply(x"00100073");
        apply(x"10500073");
        apply(x"10200073");
        apply(x"30200473");
        for b in 0 to 31 loop
            v := x"30200073";
            v(b) := not v(b);
            apply(v);
        end loop;
        apply(x"34002573");
        apply(x"30046073");
        apply(x"30047073");
        apply(x"30001073");
        apply(x"30002073");
        apply(x"30003073");
        apply(x"30005073");
        apply(x"30006073");
        apply(x"30007073");
 
        for n in 1 to 200000 loop
            apply(rnd_slv(32));
        end loop;
 
        if errors = 0 then
            report "tb_control_unit: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_control_unit: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & ")" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;
 