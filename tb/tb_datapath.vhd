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
    signal pc_src     : std_logic_vector(1 downto 0) := "00";
    signal alu_src    : std_logic := '0';
    signal reg_write  : std_logic := '0';
    signal imm_src    : std_logic_vector(2 downto 0) := "000";
    signal alu_op     : std_logic_vector(3 downto 0) := "0000";
    signal instr      : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_result : std_logic_vector(31 downto 0);
    signal zero       : std_logic;
    signal pc         : std_logic_vector(31 downto 0);
    signal result_src : std_logic_vector(2 downto 0) := "000";
    signal jalr       : std_logic := '0';
    signal alu_src_a  : std_logic := '0';
    signal read_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data : std_logic_vector(31 downto 0);
    signal csr_we     : std_logic := '0';
    signal mret       : std_logic := '0';
    signal irq        : std_logic := '0';
    signal take_irq   : std_logic;
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
            when "011"  => return (31 downto 20 => v(31)) & v(19 downto 12) & v(20) & v(30 downto 21) & '0';
            when "100"  => return v(31 downto 12) & x"000";
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
            jalr       => jalr,
            alu_src_a  => alu_src_a,
            write_data => write_data,
            csr_we     => csr_we,
            mret       => mret,
            irq        => irq,
            take_irq   => take_irq
        );

    stim : process
        type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
        type valid_t is array (0 to 31) of boolean;
        type cnt4_t is array (0 to 7) of natural;
        variable regs    : regs_t := (others => (others => '0'));
        variable valid   : valid_t := (0 => true, others => false);
        variable m_pc    : unsigned(31 downto 0) := (others => '0');
        variable errors  : natural := 0;
        variable checks  : natural := 0;
        variable cycles  : natural := 0;
        variable n_rst   : natural := 0;
        variable n_jump  : natural := 0;
        variable n_jalr  : natural := 0;
        variable n_odd   : natural := 0;
        variable n_srca  : natural := 0;
        variable n_res   : cnt4_t := (others => 0);
        variable s1      : positive := SEED1;
        variable s2      : positive := SEED2;
        variable r       : real;
        variable c_mie, c_mpie, c_meie : std_logic := '0';
        variable c_mtvec, c_mepc, c_mcause : std_logic_vector(31 downto 0) := (others => '0');
        variable c_known : boolean := true;
        variable n_trap, n_mret, n_cwe, n_cread : natural := 0;

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
                report "cycle " & integer'image(cycles) & " instr=0x" & to_hstring(instr) & " jalr=" & std_logic'image(jalr) &
                       " pc_src=" & to_string(pc_src) & " csr_we=" & std_logic'image(csr_we) & " mret=" & std_logic'image(mret) & " irq=" & std_logic'image(irq) & " src_a=" & std_logic'image(alu_src_a) & " op=" & to_string(alu_op) &
                       " src=" & std_logic'image(alu_src) & " imm_src=" & to_string(imm_src) &
                       " res_src=" & to_string(result_src) & ": " & msg severity error;
            end if;
        end procedure;

        procedure step(v       : std_logic_vector(31 downto 0);
                       op      : std_logic_vector(3 downto 0);
                       isrc    : std_logic_vector(2 downto 0);
                       asrc    : std_logic;
                       rw      : std_logic;
                       rsrc    : std_logic_vector(2 downto 0);
                       psrc    : std_logic_vector(1 downto 0);
                       rdata   : std_logic_vector(31 downto 0);
                       do_rst  : std_logic;
                       jl      : std_logic := '0';
                       sa      : std_logic := '0';
                       cwe     : std_logic := '0';
                       mr      : std_logic := '0';
                       iq      : std_logic := '0') is
            variable rs1, rs2, rd : natural;
            variable a, b, imm   : std_logic_vector(31 downto 0);
            variable exp, res    : std_logic_vector(31 downto 0);
            variable pc4         : std_logic_vector(31 downto 0);
            variable known       : boolean;
            variable base, tsum  : std_logic_vector(31 downto 0);
            variable tgt_known   : boolean;
            variable caddr       : std_logic_vector(11 downto 0);
            variable cold, cnew, csrc : std_logic_vector(31 downto 0);
            variable csrc_known  : boolean;
            variable ti          : std_logic;
            variable o_mtvec, o_mepc : std_logic_vector(31 downto 0);
            variable o_pc        : unsigned(31 downto 0);
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
            jalr       <= jl;
            alu_src_a  <= sa;
            csr_we     <= cwe;
            mret       <= mr;
            irq        <= iq;
            wait for 1 ns;
            cycles := cycles + 1;

            rs1 := to_integer(unsigned(v(19 downto 15)));
            rs2 := to_integer(unsigned(v(24 downto 20)));
            rd  := to_integer(unsigned(v(11 downto 7)));
            imm := ref_ext(v, isrc);
            if sa = '1' then
                a := std_logic_vector(m_pc);
            else
                a := regs(rs1);
            end if;
            if asrc = '1' then
                b := imm;
                known := sa = '1' or valid(rs1);
            else
                b := regs(rs2);
                known := (sa = '1' or valid(rs1)) and valid(rs2);
            end if;
            if sa = '1' then
                n_srca := n_srca + 1;
            end if;
            exp := ref_alu(a, b, op);
            pc4 := std_logic_vector(m_pc + 4);
            if jl = '1' then
                base := regs(rs1);
                tgt_known := valid(rs1);
            else
                base := std_logic_vector(m_pc);
                tgt_known := true;
            end if;
            tsum := std_logic_vector(unsigned(base) + unsigned(imm));

            caddr := v(31 downto 20);
            cold := (others => '0');
            case caddr is
                when x"300" => cold(3) := c_mie; cold(7) := c_mpie;
                when x"304" => cold(11) := c_meie;
                when x"305" => cold := c_mtvec;
                when x"341" => cold := c_mepc;
                when x"342" => cold := c_mcause;
                when x"344" => cold(11) := iq;
                when others => null;
            end case;
            if v(14) = '1' then
                csrc := (31 downto 5 => '0') & v(19 downto 15);
                csrc_known := true;
            else
                csrc := regs(rs1);
                csrc_known := valid(rs1);
            end if;
            case v(13 downto 12) is
                when "01"   => cnew := csrc;
                when "10"   => cnew := cold or csrc;
                when "11"   => cnew := cold and not csrc;
                when others => cnew := cold;
            end case;
            ti := iq and c_meie and c_mie;
            if c_known then
                checks := checks + 1;
                if take_irq /= ti then
                    fail("take_irq got " & std_logic'image(take_irq) & " expected " & std_logic'image(ti));
                end if;
            end if;

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
                when "000"  => res := exp;
                when "001"  => res := rdata;
                when "010"  => res := pc4;
                when "011"  => res := imm;
                when "100"  => res := cold; n_cread := n_cread + 1;
                when others => res := x"00000000";
            end case;
            n_res(to_integer(unsigned(rsrc))) := n_res(to_integer(unsigned(rsrc))) + 1;

            wait until rising_edge(clk);
            wait for 1 ns;

            if rw = '1' and rd /= 0 then
                regs(rd) := res;
                if rsrc = "000" then
                    valid(rd) := known;
                elsif rsrc = "100" then
                    valid(rd) := c_known;
                else
                    valid(rd) := true;
                end if;
            end if;
            o_mtvec := c_mtvec;
            o_mepc := c_mepc;
            o_pc := m_pc;
            if do_rst = '1' then
                c_mie := '0'; c_mpie := '0'; c_meie := '0';
                c_mtvec := (others => '0'); c_mepc := (others => '0'); c_mcause := (others => '0');
                c_known := true;
            elsif ti = '1' then
                c_mepc := std_logic_vector(o_pc(31 downto 2)) & "00";
                c_mcause := x"8000000B";
                c_mpie := c_mie;
                c_mie := '0';
                n_trap := n_trap + 1;
            elsif mr = '1' then
                c_mie := c_mpie;
                c_mpie := '1';
                n_mret := n_mret + 1;
            elsif cwe = '1' then
                n_cwe := n_cwe + 1;
                if not csrc_known then
                    c_known := false;
                else
                    case caddr is
                        when x"300" => c_mie := cnew(3); c_mpie := cnew(7);
                        when x"304" => c_meie := cnew(11);
                        when x"305" => c_mtvec := cnew(31 downto 2) & "00";
                        when x"341" => c_mepc := cnew(31 downto 2) & "00";
                        when x"342" => c_mcause := cnew;
                        when others => null;
                    end case;
                end if;
            end if;

            if do_rst = '1' then
                m_pc := (others => '0');
                n_rst := n_rst + 1;
            elsif psrc = "10" then
                if c_known or do_rst = '1' then m_pc := unsigned(o_mtvec); else m_pc := unsigned(pc); end if;
            elsif psrc = "11" then
                if c_known then m_pc := unsigned(o_mepc); else m_pc := unsigned(pc); end if;
            elsif psrc = "01" then
                m_pc := unsigned(tsum(31 downto 1) & '0');
                n_jump := n_jump + 1;
                if jl = '1' then
                    n_jalr := n_jalr + 1;
                end if;
                if tsum(0) = '1' then
                    n_odd := n_odd + 1;
                end if;
                if not tgt_known then
                    m_pc := unsigned(pc);
                end if;
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

        function csr_word(csr : natural; rs1 : natural; f3 : std_logic_vector(2 downto 0); rd : natural) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(csr, 12)) & std_logic_vector(to_unsigned(rs1, 5)) & f3 &
                   std_logic_vector(to_unsigned(rd, 5)) & "1110011";
        end function;

        procedure sweep is
        begin
            for i in 0 to 31 loop
                step(r_word(0, i, 0), "0000", "000", '0', '0', "000", "00", rnd_word, '0');
                step(r_word(i, 0, 0), "0000", "000", '0', '0', "000", "00", rnd_word, '0');
            end loop;
        end procedure;

        variable v    : std_logic_vector(31 downto 0);
        variable op   : std_logic_vector(3 downto 0);
        variable isrc : std_logic_vector(2 downto 0);
        variable rsrc : std_logic_vector(2 downto 0);
        variable psrc : std_logic_vector(1 downto 0);
        variable asrc, rw, rs, jl, sa, cwe, mr, iq : std_logic;
        variable k    : natural;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        m_pc := (others => '0');

        step(x"00000000", "0000", "000", '0', '1', "001", "00", x"DEADBEEF", '1');
        for i in 1 to 31 loop
            step(i_word(0, i, x"000"), "0000", "000", '1', '1', "001", "00", rnd_word, '0');
        end loop;
        step(i_word(0, 0, x"7FF"), "0000", "000", '1', '1', "001", "00", x"FFFFFFFF", '0');
        sweep;

        step(i_word(0, 1, x"7FF"), "0000", "000", '1', '1', "000", "00", rnd_word, '0');
        step(i_word(0, 2, x"800"), "0000", "000", '1', '1', "000", "00", rnd_word, '0');
        step(r_word(2, 1, 3), "1000", "000", '0', '1', "000", "00", rnd_word, '0');
        step(r_word(1, 1, 4), "1000", "000", '0', '1', "000", "00", rnd_word, '0');
        step(i_word(0, 5, x"123"), "0000", "000", '1', '1', "010", "00", rnd_word, '0');
        step(i_word(0, 6, x"FFF"), "0000", "000", '1', '1', "011", "00", rnd_word, '0');
        step(i_word(0, 7, x"001"), "0000", "001", '1', '1', "011", "00", rnd_word, '0');
        step(x"FE000FE3", "1000", "010", '0', '0', "000", "01", rnd_word, '0');
        step(x"00000463", "1000", "010", '0', '0', "000", "01", rnd_word, '0');
        step(x"80000063", "1000", "010", '0', '0', "000", "01", rnd_word, '0');
        step(x"7E000FE3", "1000", "010", '0', '0', "000", "01", rnd_word, '0');
        step(i_word(0, 8, x"7FF"), "0000", "000", '1', '1', "000", "01", rnd_word, '0');
        step(i_word(0, 9, x"000"), "0000", "000", '1', '1', "001", "00", x"80000000", '1');
        step(i_word(0, 10, x"000"), "0000", "000", '1', '1', "001", "00", x"00001001", '0');
        step(i_word(10, 0, x"000"), "0000", "000", '1', '0', "000", "01", rnd_word, '0', '1');
        step(i_word(0, 11, x"000"), "0000", "000", '1', '1', "001", "00", x"00000200", '0');
        step(i_word(11, 11, x"004"), "0000", "000", '1', '1', "010", "01", rnd_word, '0', '1');
        step(i_word(0, 12, x"000"), "0000", "000", '1', '1', "001", "00", x"00000100", '0');
        step(i_word(12, 1, x"FFF"), "0000", "000", '1', '1', "010", "01", rnd_word, '0', '1');
        step(i_word(12, 0, x"7FF"), "0000", "000", '1', '0', "000", "00", rnd_word, '0', '1');
        step(i_word(0, 13, x"000"), "0000", "000", '1', '1', "001", "00", x"FFFFFFFF", '0');
        step(i_word(13, 0, x"002"), "0000", "000", '1', '0', "000", "01", rnd_word, '0', '1');
        step(x"FE000FE3", "1000", "010", '0', '0', "000", "01", rnd_word, '0', '0');
        step(x"00001097", "0000", "100", '1', '1', "000", "00", rnd_word, '0', '0', '1');
        step(x"FFFFF117", "0000", "100", '1', '1', "000", "00", rnd_word, '0', '0', '1');
        step(x"80000197", "0000", "100", '1', '1', "000", "00", rnd_word, '0', '0', '1');
        step(x"800002B7", "0000", "100", '1', '1', "011", "00", rnd_word, '0', '0', '0');
        step(x"123450B7", "0000", "100", '1', '1', "011", "00", rnd_word, '0', '0', '0');
        step(x"0FF00217", "0000", "100", '1', '1', "000", "00", rnd_word, '0', '0', '1');
        step(i_word(0, 14, x"000"), "0000", "000", '1', '1', "001", "00", x"00000301", '0');
        step(i_word(14, 0, x"010"), "0000", "000", '1', '0', "000", "01", rnd_word, '0', '1', '1');
        step(x"00000397", "0000", "100", '1', '1', "000", "00", rnd_word, '0', '0', '1');
        sweep;

        step(i_word(0, 1, x"100"), "0000", "000", '1', '1', "000", "00", rnd_word, '0');
        step(csr_word(16#305#, 1, "001", 0), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(csr_word(16#305#, 0, "010", 2), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(i_word(0, 3, x"000"), "0000", "000", '1', '1', "001", "00", x"00000800", '0');
        step(csr_word(16#304#, 3, "001", 0), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(csr_word(16#344#, 0, "010", 15), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '0', '0', '1');
        step(csr_word(16#300#, 8, "110", 0), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(i_word(0, 16, x"7FF"), "0000", "000", '1', '0', "000", "10", rnd_word, '0', '0', '0', '0', '0', '1');
        step(csr_word(16#341#, 0, "010", 4), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#342#, 0, "010", 5), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#300#, 0, "010", 6), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '0', '0', '1');
        step(csr_word(16#300#, 0, "010", 17), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '0', '0', '1');
        step(x"30200073", "0000", "000", '0', '0', "000", "11", rnd_word, '0', '0', '0', '0', '1', '0');
        step(csr_word(16#300#, 0, "010", 7), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#300#, 8, "111", 0), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(csr_word(16#300#, 0, "010", 18), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#342#, 1, "001", 8), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(csr_word(16#342#, 0, "010", 19), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#340#, 5, "101", 9), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(csr_word(16#342#, 31, "011", 20), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(csr_word(16#342#, 0, "010", 21), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#300#, 8, "110", 0), "0000", "000", '0', '1', "100", "00", rnd_word, '0', '0', '0', '1');
        step(i_word(0, 22, x"001"), "0000", "000", '1', '1', "000", "10", rnd_word, '0', '0', '0', '1', '0', '1');
        step(csr_word(16#341#, 0, "010", 23), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(csr_word(16#300#, 0, "010", 24), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        step(x"30200073", "0000", "000", '0', '0', "000", "11", rnd_word, '0', '0', '0', '0', '1', '0');
        step(i_word(0, 25, x"000"), "0000", "000", '1', '1', "000", "00", rnd_word, '1');
        step(csr_word(16#305#, 0, "010", 26), "0000", "000", '0', '1', "100", "00", rnd_word, '0');
        sweep;

        for n in 1 to N_RANDOM loop
            v := rnd_word;
            if rnd(6) = 0 then
                v(19 downto 15) := v(24 downto 20);
            end if;
            op := OPS(rnd(OPS'length));
            isrc := std_logic_vector(to_unsigned(rnd(5), 3));
            k := rnd(12);
            if k < 8 then rsrc := std_logic_vector(to_unsigned(k mod 5, 3)); else rsrc := std_logic_vector(to_unsigned(k - 4, 3)); end if;
            case rnd(8) is
                when 0 => v(31 downto 20) := x"300";
                when 1 => v(31 downto 20) := x"304";
                when 2 => v(31 downto 20) := x"305";
                when 3 => v(31 downto 20) := x"341";
                when 4 => v(31 downto 20) := x"342";
                when 5 => v(31 downto 20) := x"344";
                when others => null;
            end case;
            if rnd(2) = 0 then asrc := '0'; else asrc := '1'; end if;
            if rnd(4) = 0 then rw := '0'; else rw := '1'; end if;
            case rnd(10) is
                when 0 | 1 => psrc := "01";
                when 2 => psrc := "10";
                when 3 => psrc := "11";
                when others => psrc := "00";
            end case;
            if rnd(3) = 0 and (v(14) = '1' or valid(to_integer(unsigned(v(19 downto 15))))) then cwe := '1'; else cwe := '0'; end if;
            if rnd(8) = 0 then mr := '1'; else mr := '0'; end if;
            if rnd(3) = 0 then iq := '1'; else iq := '0'; end if;
            if rnd(50) = 0 then rs := '1'; rw := '0'; else rs := '0'; end if;
            if rnd(3) = 0 then jl := '1'; else jl := '0'; end if;
            if rnd(3) = 0 then sa := '1'; else sa := '0'; end if;
            step(v, op, isrc, asrc, rw, rsrc, psrc, rnd_word, rs, jl, sa, cwe, mr, iq);
            if n mod 2000 = 0 then
                sweep;
            end if;
        end loop;
        sweep;

        report "tb_datapath: " & integer'image(cycles) & " cycles, " & integer'image(checks) & " checks, result_src 000..100 = " &
               integer'image(n_res(0)) & "/" & integer'image(n_res(1)) & "/" & integer'image(n_res(2)) & "/" &
               integer'image(n_res(3)) & "/" & integer'image(n_res(4)) & ", traps " & integer'image(n_trap) & ", mret " & integer'image(n_mret) & ", csr writes " & integer'image(n_cwe) & ", jumps " & integer'image(n_jump) & " (jalr " & integer'image(n_jalr) & ", odd target " &
               integer'image(n_odd) & "), src_a=pc " & integer'image(n_srca) & ", resets " & integer'image(n_rst) & ", " &
               integer'image(errors) & " errors";
        assert errors = 0 report "tb_datapath FAILED" severity failure;
        report "tb_datapath PASSED";
        done <= true;
        std.env.finish;
    end process;
end architecture sim;