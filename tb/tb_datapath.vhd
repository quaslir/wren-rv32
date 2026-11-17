library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_datapath is
    generic(
        N_RANDOM : natural := 5000;
        SEED1    : positive := 11;
        SEED2    : positive := 23
    );
end entity tb_datapath;

architecture sim of tb_datapath is
    constant CLK_PERIOD : time := 10 ns;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal pc_src    : std_logic := '0';
    signal alu_src   : std_logic := '0';
    signal reg_write : std_logic := '0';
    signal imm_src   : std_logic_vector(1 downto 0) := "00";
    signal alu_op    : std_logic_vector(3 downto 0) := "0000";
    signal instr     : std_logic_vector(31 downto 0) := (others => '0');
    signal result    : std_logic_vector(31 downto 0);
    signal zero      : std_logic;
    signal pc        : std_logic_vector(31 downto 0);
    signal result_src : std_logic := '0';
    signal read_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal write_data : std_logic_vector(31 downto 0);
    signal done      : boolean := false;

    type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
    type ops_t is array (0 to 9) of std_logic_vector(3 downto 0);
    constant OPS : ops_t := ("0000", "1000", "0001", "0010", "0011", "0100", "0101", "1101", "0110", "0111");

    function ref_imm(i : std_logic_vector(31 downto 0); src : std_logic_vector(1 downto 0)) return std_logic_vector is
    begin
        case src is
            when "00"   => return (31 downto 12 => i(31)) & i(31 downto 20);
            when "01"   => return (31 downto 12 => i(31)) & i(31 downto 25) & i(11 downto 7);
            when "10"   => return (31 downto 12 => i(31)) & i(7) & i(30 downto 25) & i(11 downto 8) & '0';
            when others => return x"00000000";
        end case;
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
begin
    dut : entity work.datapath
        port map(
            clk       => clk,
            rst       => rst,
            pc_src    => pc_src,
            alu_src   => alu_src,
            reg_write => reg_write,
            imm_src   => imm_src,
            alu_op    => alu_op,
            instr     => instr,
            alu_result => result,
            zero      => zero,
            pc        => pc,
            result_src => result_src,
            read_data  => read_data,
            write_data => write_data
        );

    clk <= not clk after CLK_PERIOD / 2 when not done;

    stim : process
        variable s1, s2   : positive;
        variable r        : real;
        variable regs     : regs_t := (others => (others => '0'));
        variable m_pc     : unsigned(31 downto 0) := (others => '0');
        variable err      : natural := 0;
        variable cnt      : natural := 0;
        variable n_taken  : natural := 0;
        variable n_zero   : natural := 0;
        variable v_instr  : std_logic_vector(31 downto 0);
        variable v_op     : std_logic_vector(3 downto 0);
        variable v_isrc   : std_logic_vector(1 downto 0);
        variable v_asrc   : std_logic;
        variable v_we     : std_logic;
        variable v_psrc   : std_logic;
        variable v_rsrc   : std_logic := '0';
        variable v_rdata  : std_logic_vector(31 downto 0) := (others => '0');
        variable imm      : std_logic_vector(31 downto 0);
        variable a, b     : std_logic_vector(31 downto 0);
        variable exp      : std_logic_vector(31 downto 0);
        variable exp_zero : std_logic;
        variable rs1, rs2, rd : natural;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(trunc(r * real(n)));
        end function;

        impure function rnd_bit return std_logic is
        begin
            if rnd(2) = 1 then return '1'; else return '0'; end if;
        end function;

        impure function rnd_word return std_logic_vector is
            variable w : std_logic_vector(31 downto 0);
        begin
            for i in 0 to 31 loop
                w(i) := rnd_bit;
            end loop;
            return w;
        end function;

        procedure fail(msg : string) is
        begin
            if err < 20 then
                report "FAIL cycle " & integer'image(cnt) & ": " & msg severity error;
            end if;
            err := err + 1;
        end procedure;

        procedure step is
        begin
            instr     <= v_instr;
            alu_op    <= v_op;
            imm_src   <= v_isrc;
            alu_src   <= v_asrc;
            reg_write <= v_we;
            pc_src    <= v_psrc;
            result_src <= v_rsrc;
            read_data  <= v_rdata;
            wait for 2 ns;

            rs1 := to_integer(unsigned(v_instr(19 downto 15)));
            rs2 := to_integer(unsigned(v_instr(24 downto 20)));
            rd  := to_integer(unsigned(v_instr(11 downto 7)));
            imm := ref_imm(v_instr, v_isrc);
            a   := regs(rs1);
            if v_asrc = '1' then b := imm; else b := regs(rs2); end if;
            exp := ref_alu(a, b, v_op);
            if exp = x"00000000" then exp_zero := '1'; else exp_zero := '0'; end if;

            cnt := cnt + 1;
            if pc /= std_logic_vector(m_pc) then
                fail("pc got=0x" & to_hstring(pc) & " expected=0x" & to_hstring(m_pc));
            end if;
            if result /= exp then
                fail("result got=0x" & to_hstring(result) & " expected=0x" & to_hstring(exp)
                    & " op=" & to_string(v_op) & " alu_src=" & std_logic'image(v_asrc)
                    & " rs1=x" & integer'image(rs1) & " rs2=x" & integer'image(rs2));
            end if;
            if write_data /= regs(rs2) then
                fail("write_data got=0x" & to_hstring(write_data) & " expected rs2=x" & integer'image(rs2) & "=0x" & to_hstring(regs(rs2)));
            end if;
            if zero /= exp_zero then
                fail("zero got=" & std_logic'image(zero) & " expected=" & std_logic'image(exp_zero));
            end if;
            if exp_zero = '1' then
                n_zero := n_zero + 1;
            end if;

            wait until rising_edge(clk);

            if v_we = '1' and rd /= 0 then
                if v_rsrc = '1' then
                    regs(rd) := v_rdata;
                else
                    regs(rd) := exp;
                end if;
            end if;
            if v_psrc = '1' then
                m_pc := m_pc + unsigned(imm);
                n_taken := n_taken + 1;
            else
                m_pc := m_pc + 4;
            end if;

            wait until falling_edge(clk);
        end procedure;
    begin
        s1 := SEED1;
        s2 := SEED2;

        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';
        m_pc := (others => '0');

        for i in 1 to 31 loop
            v_instr := rnd_word;
            v_instr(19 downto 15) := "00000";
            v_instr(11 downto 7)  := std_logic_vector(to_unsigned(i, 5));
            v_op   := "0000";
            v_isrc := "00";
            v_asrc := '1';
            v_we   := '1';
            v_psrc := '0';
            step;
        end loop;

        for i in 1 to 31 loop
            v_instr := rnd_word;
            v_instr(11 downto 7) := "00000";
            v_op   := "0000";
            v_isrc := "00";
            v_asrc := '0';
            v_we   := '1';
            v_psrc := '0';
            step;
        end loop;

        v_instr := x"00000000";
        v_instr(19 downto 15) := "00000";
        v_instr(24 downto 20) := "00000";
        v_op := "0000"; v_isrc := "00"; v_asrc := '0'; v_we := '0'; v_psrc := '0';
        step;

        for i in 1 to 31 loop
            v_instr := rnd_word;
            v_instr(11 downto 7) := std_logic_vector(to_unsigned(i, 5));
            v_op   := "0000";
            v_isrc := "00";
            v_asrc := '1';
            v_we   := '1';
            v_psrc := '0';
            v_rsrc := '1';
            v_rdata := rnd_word;
            step;
        end loop;
        v_rsrc := '0';

        for i in 1 to N_RANDOM loop
            v_instr := rnd_word;
            v_op    := OPS(rnd(10));
            v_isrc  := std_logic_vector(to_unsigned(2 * rnd(2), 2));
            v_asrc  := rnd_bit;
            v_we    := rnd_bit;
            v_psrc  := rnd_bit;
            v_rsrc  := rnd_bit;
            v_rdata := rnd_word;
            if rnd(4) = 0 then
                v_instr(24 downto 20) := v_instr(19 downto 15);
                v_op   := "1000";
                v_asrc := '0';
            end if;
            if rnd(8) = 0 then
                v_instr(19 downto 15) := "00000";
                v_instr(24 downto 20) := "00000";
            end if;
            step;
        end loop;

        report "cycles: " & integer'image(cnt) & ", zero=1: " & integer'image(n_zero)
            & ", pc_src=1: " & integer'image(n_taken) severity note;
        if err = 0 then
            report "tb_datapath: ALL " & integer'image(cnt) & " CYCLES PASSED" severity note;
        else
            report "tb_datapath: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;