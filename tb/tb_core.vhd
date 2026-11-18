library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_core is
    generic(
        N_RANDOM : natural := 10000;
        SEED1    : positive := 5;
        SEED2    : positive := 77;
        MEM_DEPTH : positive := 64
    );
end entity tb_core;

architecture sim of tb_core is
    constant CLK_PERIOD : time := 10 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal instr      : std_logic_vector(31 downto 0) := (others => '0');
    signal illegal    : std_logic;
    signal alu_result : std_logic_vector(31 downto 0);
    signal pc         : std_logic_vector(31 downto 0);
    signal read_data  : std_logic_vector(31 downto 0);
    signal mem_write  : std_logic;
    signal write_data : std_logic_vector(31 downto 0);
    signal be         : std_logic_vector(3 downto 0);
    signal done       : boolean := false;

    type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
    type mem_t is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);
    signal dmem : mem_t := (others => (others => '0'));

    constant OP_R    : std_logic_vector(6 downto 0) := "0110011";
    constant OP_I    : std_logic_vector(6 downto 0) := "0010011";
    constant OP_B    : std_logic_vector(6 downto 0) := "1100011";
    constant OP_L    : std_logic_vector(6 downto 0) := "0000011";
    constant OP_S    : std_logic_vector(6 downto 0) := "0100011";

    function word_of(a : std_logic_vector(31 downto 0)) return natural is
    begin
        if unsigned(a(31 downto 2)) < MEM_DEPTH then
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

    function enc_r(f7 : std_logic_vector(6 downto 0); rs2, rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
    begin
        return f7 & std_logic_vector(to_unsigned(rs2, 5)) & std_logic_vector(to_unsigned(rs1, 5)) & f3
            & std_logic_vector(to_unsigned(rd, 5)) & OP_R;
    end function;

    function enc_i(imm : integer; rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & std_logic_vector(to_unsigned(rs1, 5)) & f3
            & std_logic_vector(to_unsigned(rd, 5)) & OP_I;
    end function;

    function enc_l(imm : integer; rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(imm, 12)) & std_logic_vector(to_unsigned(rs1, 5)) & f3
            & std_logic_vector(to_unsigned(rd, 5)) & OP_L;
    end function;

    function enc_s(imm : integer; rs2, rs1 : natural; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable u : std_logic_vector(11 downto 0) := std_logic_vector(to_signed(imm, 12));
    begin
        return u(11 downto 5) & std_logic_vector(to_unsigned(rs2, 5)) & std_logic_vector(to_unsigned(rs1, 5))
            & f3 & u(4 downto 0) & OP_S;
    end function;

    function enc_b(imm : integer; rs2, rs1 : natural; f3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable u : std_logic_vector(12 downto 0) := std_logic_vector(to_signed(imm, 13));
    begin
        return u(12) & u(10 downto 5) & std_logic_vector(to_unsigned(rs2, 5)) & std_logic_vector(to_unsigned(rs1, 5))
            & f3 & u(4 downto 1) & u(11) & OP_B;
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
            be         => be
        );

    read_data <= dmem(word_of(alu_result)) when word_of(alu_result) < MEM_DEPTH else (others => '0');

    clk <= not clk after CLK_PERIOD / 2 when not done;

    stim : process
        variable s1, s2      : positive;
        variable r           : real;
        variable regs        : regs_t := (others => (others => '0'));
        variable m_pc        : unsigned(31 downto 0) := (others => '0');
        variable err         : natural := 0;
        variable cnt         : natural := 0;
        variable n_r, n_i, n_b, n_taken, n_ill, n_lw, n_sw, n_sw_mis : natural := 0;
        variable aligned     : boolean;
        variable mem         : mem_t := (others => (others => '0'));
        variable loads       : boolean;
        variable stores      : boolean;
        variable ld_val      : std_logic_vector(31 downto 0);
        variable v           : std_logic_vector(31 downto 0);
        variable opcode      : std_logic_vector(6 downto 0);
        variable f3          : std_logic_vector(2 downto 0);
        variable f7          : std_logic_vector(6 downto 0);
        variable rs1, rs2, rd : natural;
        variable imm         : std_logic_vector(31 downto 0);
        variable legal       : boolean;
        variable writes      : boolean;
        variable taken       : boolean;
        variable exp         : std_logic_vector(31 downto 0);
        variable kind        : natural;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n)));
        end function;

        impure function rnd_word return std_logic_vector is
            variable w : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 31 loop
                if rnd(2) = 1 then w(i) := '1'; else w(i) := '0'; end if;
            end loop;
            return w;
        end function;

        impure function rnd_reg return natural is
        begin
            if rnd(10) = 0 then
                return 0;
            else
                return 1 + rnd(31);
            end if;
        end function;

        procedure fail(msg : string) is
        begin
            if err < 20 then
                report "FAIL cycle " & integer'image(cnt) & " instr=0x" & to_hstring(v) & ": " & msg severity error;
            end if;
            err := err + 1;
        end procedure;

        procedure step is
        begin
            instr <= v;
            wait for 2 ns;
            cnt := cnt + 1;

            opcode := v(6 downto 0);
            f3     := v(14 downto 12);
            f7     := v(31 downto 25);
            rs1    := to_integer(unsigned(v(19 downto 15)));
            rs2    := to_integer(unsigned(v(24 downto 20)));
            rd     := to_integer(unsigned(v(11 downto 7)));
            legal  := false;
            writes := false;
            taken  := false;
            loads  := false;
            stores := false;
            exp    := (others => '0');

            if opcode = OP_R then
                if f7 = "0000000" or (f7 = "0100000" and (f3 = "000" or f3 = "101")) then
                    legal  := true;
                    writes := true;
                    exp    := ref_alu(regs(rs1), regs(rs2), f7(5) & f3);
                end if;
            elsif opcode = OP_I then
                imm := (31 downto 12 => v(31)) & v(31 downto 20);
                if f3 = "001" then
                    legal := f7 = "0000000";
                    exp   := ref_alu(regs(rs1), imm, '0' & f3);
                elsif f3 = "101" then
                    legal := f7 = "0000000" or f7 = "0100000";
                    exp   := ref_alu(regs(rs1), imm, v(30) & f3);
                else
                    legal := true;
                    exp   := ref_alu(regs(rs1), imm, '0' & f3);
                end if;
                writes := legal;
            elsif opcode = OP_B and f3 /= "010" and f3 /= "011" then
                legal := true;
                imm   := (31 downto 12 => v(31)) & v(7) & v(30 downto 25) & v(11 downto 8) & '0';
                case f3 is
                    when "000" =>
                        exp   := ref_alu(regs(rs1), regs(rs2), "1000");
                        taken := regs(rs1) = regs(rs2);
                    when "001" =>
                        exp   := ref_alu(regs(rs1), regs(rs2), "1000");
                        taken := regs(rs1) /= regs(rs2);
                    when "100" =>
                        exp   := ref_alu(regs(rs1), regs(rs2), "0010");
                        taken := signed(regs(rs1)) < signed(regs(rs2));
                    when "101" =>
                        exp   := ref_alu(regs(rs1), regs(rs2), "0010");
                        taken := signed(regs(rs1)) >= signed(regs(rs2));
                    when "110" =>
                        exp   := ref_alu(regs(rs1), regs(rs2), "0011");
                        taken := unsigned(regs(rs1)) < unsigned(regs(rs2));
                    when others =>
                        exp   := ref_alu(regs(rs1), regs(rs2), "0011");
                        taken := unsigned(regs(rs1)) >= unsigned(regs(rs2));
                end case;
            elsif opcode = OP_L and f3 = "010" then
                legal  := true;
                writes := true;
                loads  := true;
                imm    := (31 downto 12 => v(31)) & v(31 downto 20);
                exp    := ref_alu(regs(rs1), imm, "0000");
                if word_of(exp) < MEM_DEPTH then
                    ld_val := mem(word_of(exp));
                else
                    ld_val := x"00000000";
                end if;
            elsif opcode = OP_S and f3 = "010" then
                legal  := true;
                stores := true;
                imm    := (31 downto 12 => v(31)) & v(31 downto 25) & v(11 downto 7);
                exp    := ref_alu(regs(rs1), imm, "0000");
            end if;

            if pc /= std_logic_vector(m_pc) then
                fail("pc got=0x" & to_hstring(pc) & " expected=0x" & to_hstring(m_pc));
            end if;
            if legal then
                if illegal /= '0' then
                    fail("illegal=1 for legal instruction");
                end if;
                if alu_result /= exp then
                    fail("alu_result got=0x" & to_hstring(alu_result) & " expected=0x" & to_hstring(exp));
                end if;
                if stores then
                    aligned := exp(1 downto 0) = "00";
                    if aligned then
                        if be /= "1111" then
                            fail("sw be got=" & to_string(be) & " expected=1111");
                        end if;
                        if write_data /= regs(rs2) then
                            fail("sw write_data got=0x" & to_hstring(write_data) & " expected=0x" & to_hstring(regs(rs2)));
                        end if;
                    else
                        n_sw_mis := n_sw_mis + 1;
                        if be /= "0000" then
                            fail("misaligned sw be got=" & to_string(be) & " expected=0000");
                        end if;
                        if is_x(write_data) then
                            fail("misaligned sw write_data undefined: 0x" & to_hstring(write_data));
                        end if;
                    end if;
                end if;
            else
                if illegal /= '1' then
                    fail("illegal=0 for illegal instruction");
                end if;
                n_ill := n_ill + 1;
            end if;
            if stores and mem_write /= '1' then
                fail("sw: mem_write=" & std_logic'image(mem_write) & ", expected '1'");
            elsif not stores and mem_write /= '0' then
                fail("non-store: mem_write=" & std_logic'image(mem_write) & ", expected '0'");
            end if;

            wait until rising_edge(clk);

            if writes and rd /= 0 then
                if loads then
                    regs(rd) := ld_val;
                else
                    regs(rd) := exp;
                end if;
            end if;
            if stores and exp(1 downto 0) = "00" and word_of(exp) < MEM_DEPTH then
                mem(word_of(exp)) := regs(rs2);
                dmem <= mem;
            end if;
            if taken then
                m_pc := m_pc + unsigned(imm);
                n_taken := n_taken + 1;
            else
                m_pc := m_pc + 4;
            end if;

            wait until falling_edge(clk);
        end procedure;

        procedure check_regs is
        begin
            for i in 0 to 31 loop
                v := enc_r("0000000", 0, i, "000", 0);
                step;
                if alu_result /= regs(i) then
                    fail("x" & integer'image(i) & " got=0x" & to_hstring(alu_result) & " expected=0x" & to_hstring(regs(i)));
                end if;
            end loop;
        end procedure;

        type f3_arr_t is array (natural range <>) of std_logic_vector(2 downto 0);
        constant I_F3 : f3_arr_t := ("000", "010", "011", "100", "110", "111");
        constant B_F3 : f3_arr_t := ("000", "001", "100", "101", "110", "111");
        constant BAD_LS_F3 : f3_arr_t := ("000", "001", "011", "100", "101", "110", "111");

        procedure check_mem is
        begin
            for i in 0 to MEM_DEPTH - 1 loop
                v := enc_l(4 * i, 0, "010", 31);
                step;
                v := enc_r("0000000", 0, 31, "000", 0);
                step;
                if alu_result /= mem(i) then
                    fail("mem[" & integer'image(i) & "] got=0x" & to_hstring(alu_result) & " expected=0x" & to_hstring(mem(i)));
                end if;
            end loop;
        end procedure;
    begin
        s1 := SEED1;
        s2 := SEED2;

        instr <= x"00000013";
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';
        m_pc := (others => '0');

        for i in 1 to 31 loop
            v := enc_i(rnd(4096) - 2048, 0, "000", i);
            step;
        end loop;
        for i in 1 to 31 loop
            v := enc_r("0000000", i, i, "000", i);
            step;
        end loop;
        v := enc_i(1234, 0, "000", 0);
        step;
        check_regs;

        for n in 1 to N_RANDOM loop
            kind := rnd(100);
            if kind < 12 then
                n_lw := n_lw + 1;
                if rnd(4) = 0 then
                    v := enc_l(rnd(4096) - 2048, rnd_reg, "010", rnd_reg);
                else
                    v := enc_l(4 * rnd(MEM_DEPTH + 4), 0, "010", rnd_reg);
                end if;
                step;
                next;
            elsif kind < 24 then
                n_sw := n_sw + 1;
                if rnd(4) = 0 then
                    v := enc_s(rnd(4096) - 2048, rnd_reg, rnd_reg, "010");
                else
                    v := enc_s(4 * rnd(MEM_DEPTH + 4), rnd_reg, 0, "010");
                end if;
                step;
                next;
            elsif kind < 26 then
                if rnd(2) = 1 then
                    v := enc_l(4 * rnd(MEM_DEPTH), 0, BAD_LS_F3(rnd(7)), rnd_reg);
                else
                    v := enc_s(4 * rnd(MEM_DEPTH), rnd_reg, 0, BAD_LS_F3(1 + rnd(6)));
                end if;
                step;
                next;
            end if;
            kind := rnd(100);
            if kind < 35 then
                n_r := n_r + 1;
                f3 := std_logic_vector(to_unsigned(rnd(8), 3));
                if (f3 = "000" or f3 = "101") and rnd(2) = 1 then
                    f7 := "0100000";
                else
                    f7 := "0000000";
                end if;
                v := enc_r(f7, rnd_reg, rnd_reg, f3, rnd_reg);
            elsif kind < 70 then
                n_i := n_i + 1;
                case rnd(3) is
                    when 0 =>
                        v := enc_i(rnd(4096) - 2048, rnd_reg, I_F3(rnd(6)), rnd_reg);
                    when 1 =>
                        v := enc_i(rnd(32), rnd_reg, "001", rnd_reg);
                    when others =>
                        v := enc_i(rnd(32) + 1024 * rnd(2), rnd_reg, "101", rnd_reg);
                end case;
            elsif kind < 88 then
                n_b := n_b + 1;
                rs1 := rnd_reg;
                if rnd(2) = 1 then rs2 := rs1; else rs2 := rnd_reg; end if;
                v := enc_b(2 * (rnd(4096) - 2048), rs2, rs1, B_F3(rnd(6)));
            elsif kind < 92 then
                v := enc_r("0000001", rnd_reg, rnd_reg, std_logic_vector(to_unsigned(rnd(8), 3)), rnd_reg);
            elsif kind < 94 then
                v := enc_r(std_logic_vector(to_unsigned(2 + rnd(30), 7)), rnd_reg, rnd_reg, "000", rnd_reg);
            elsif kind < 96 then
                f7 := std_logic_vector(to_unsigned(1 + rnd(127), 7));
                if f7 = "0100000" then f7 := "0100001"; end if;
                if rnd(2) = 1 then f3 := "001"; else f3 := "101"; end if;
                v := f7 & std_logic_vector(to_unsigned(rnd(32), 5)) & std_logic_vector(to_unsigned(rnd_reg, 5))
                    & f3 & std_logic_vector(to_unsigned(rnd_reg, 5)) & OP_I;
            elsif kind < 98 then
                v := enc_b(8, rnd_reg, rnd_reg, std_logic_vector(to_unsigned(2 + rnd(2), 3)));
            else
                v := rnd_word;
                if v(6 downto 0) = OP_R or v(6 downto 0) = OP_I or v(6 downto 0) = OP_B
                   or v(6 downto 0) = OP_L or v(6 downto 0) = OP_S then
                    v(6 downto 0) := "0001011";
                end if;
            end if;
            step;
        end loop;

        check_regs;
        check_mem;

        report "cycles " & integer'image(cnt) & ": R " & integer'image(n_r) & ", I " & integer'image(n_i)
            & ", branch " & integer'image(n_b) & " (taken " & integer'image(n_taken) & "), lw " & integer'image(n_lw)
            & ", sw " & integer'image(n_sw) & " (misaligned " & integer'image(n_sw_mis) & "), illegal " & integer'image(n_ill) severity note;
        if err = 0 then
            report "tb_core: ALL " & integer'image(cnt) & " CYCLES PASSED" severity note;
        else
            report "tb_core: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;