library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_csr is
end entity tb_csr;

architecture sim of tb_csr is
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal we       : std_logic := '0';
    signal addr     : std_logic_vector(11 downto 0) := (others => '0');
    signal op       : std_logic_vector(1 downto 0) := "00";
    signal src      : std_logic_vector(31 downto 0) := (others => '0');
    signal irq      : std_logic := '0';
    signal mret     : std_logic := '0';
    signal pc       : std_logic_vector(31 downto 0) := (others => '0');
    signal rdata    : std_logic_vector(31 downto 0);
    signal mtvec    : std_logic_vector(31 downto 0);
    signal mepc     : std_logic_vector(31 downto 0);
    signal take_irq : std_logic;

    constant A_MSTATUS : std_logic_vector(11 downto 0) := x"300";
    constant A_MIE     : std_logic_vector(11 downto 0) := x"304";
    constant A_MTVEC   : std_logic_vector(11 downto 0) := x"305";
    constant A_MEPC    : std_logic_vector(11 downto 0) := x"341";
    constant A_MCAUSE  : std_logic_vector(11 downto 0) := x"342";
    constant A_MIP     : std_logic_vector(11 downto 0) := x"344";

    constant OP_RW : std_logic_vector(1 downto 0) := "01";
    constant OP_RS : std_logic_vector(1 downto 0) := "10";
    constant OP_RC : std_logic_vector(1 downto 0) := "11";

    constant ONES  : std_logic_vector(31 downto 0) := (others => '1');
    constant ZERO  : std_logic_vector(31 downto 0) := (others => '0');
    constant CAUSE : std_logic_vector(31 downto 0) := x"8000000B";

    type addr_arr is array (natural range <>) of std_logic_vector(11 downto 0);
    constant ADDRS : addr_arr := (A_MSTATUS, A_MIE, A_MTVEC, A_MEPC, A_MCAUSE, A_MIP,
                                  x"000", x"301", x"340", x"343", x"345", x"B00", x"F14", x"7FF", x"FFF", x"344");
begin
    dut: entity work.csr
        port map(clk => clk, rst => rst, we => we, addr => addr, op => op, src => src,
                 irq => irq, mret => mret, pc => pc, rdata => rdata, mtvec => mtvec,
                 mepc => mepc, take_irq => take_irq);

    stim: process
        variable m_mie, m_mpie, m_meie : std_logic := '0';
        variable m_mtvec, m_mepc, m_mcause : std_logic_vector(31 downto 0) := (others => '0');
        variable errors : natural := 0;
        variable checks : natural := 0;
        variable started : boolean := false;
        variable s1, s2 : positive := 42;
        variable r : real;

        impure function rnd(n : positive) return natural is
        begin
            uniform(s1, s2, r);
            return integer(floor(r * real(n)));
        end function;

        impure function rnd_slv(w : positive) return std_logic_vector is
            variable v : std_logic_vector(w - 1 downto 0);
        begin
            for i in v'range loop
                if rnd(2) = 1 then v(i) := '1'; else v(i) := '0'; end if;
            end loop;
            return v;
        end function;

        function hex(v : std_logic_vector) return string is
        begin
            return to_hstring(v);
        end function;

        impure function m_read(a : std_logic_vector(11 downto 0); i : std_logic) return std_logic_vector is
            variable v : std_logic_vector(31 downto 0) := (others => '0');
        begin
            case a is
                when x"300" => v(3) := m_mie; v(7) := m_mpie;
                when x"304" => v(11) := m_meie;
                when x"305" => v := m_mtvec;
                when x"341" => v := m_mepc;
                when x"342" => v := m_mcause;
                when x"344" => v(11) := i;
                when others => null;
            end case;
            return v;
        end function;

        procedure check(cond : boolean; msg : string) is
        begin
            checks := checks + 1;
            if not cond then
                errors := errors + 1;
                if errors <= 20 then
                    report msg severity error;
                end if;
            end if;
        end procedure;

        procedure check_outputs(tag : string) is
            variable exp_r : std_logic_vector(31 downto 0);
            variable exp_t : std_logic;
        begin
            exp_r := m_read(addr, irq);
            exp_t := irq and m_meie and m_mie;
            check(rdata = exp_r, tag & ": rdata addr=" & hex(addr) & " got " & hex(rdata) & " exp " & hex(exp_r));
            check(mtvec = m_mtvec, tag & ": mtvec got " & hex(mtvec) & " exp " & hex(m_mtvec));
            check(mepc = m_mepc, tag & ": mepc got " & hex(mepc) & " exp " & hex(m_mepc));
            check(take_irq = exp_t, tag & ": take_irq got " & std_logic'image(take_irq) & " exp " & std_logic'image(exp_t)
                  & " (irq=" & std_logic'image(irq) & " meie=" & std_logic'image(m_meie) & " mie=" & std_logic'image(m_mie) & ")");
        end procedure;

        procedure model_edge is
            variable old, nv : std_logic_vector(31 downto 0);
            variable ti : std_logic;
        begin
            ti := irq and m_meie and m_mie;
            old := m_read(addr, irq);
            case op is
                when "01" => nv := src;
                when "10" => nv := old or src;
                when "11" => nv := old and not src;
                when others => nv := old;
            end case;
            if rst = '1' then
                m_mie := '0'; m_mpie := '0'; m_meie := '0';
                m_mtvec := ZERO; m_mepc := ZERO; m_mcause := ZERO;
            elsif ti = '1' then
                m_mepc := pc(31 downto 2) & "00";
                m_mcause := CAUSE;
                m_mpie := m_mie;
                m_mie := '0';
            elsif mret = '1' then
                m_mie := m_mpie;
                m_mpie := '1';
            elsif we = '1' then
                case addr is
                    when x"300" => m_mie := nv(3); m_mpie := nv(7);
                    when x"304" => m_meie := nv(11);
                    when x"305" => m_mtvec := nv(31 downto 2) & "00";
                    when x"341" => m_mepc := nv(31 downto 2) & "00";
                    when x"342" => m_mcause := nv;
                    when others => null;
                end case;
            end if;
        end procedure;

        procedure tick(tag : string) is
        begin
            wait for 1 ns;
            if started then
                check_outputs(tag);
            end if;
            model_edge;
            clk <= '1';
            wait for 5 ns;
            clk <= '0';
            wait for 4 ns;
            check_outputs(tag & " after edge");
            started := true;
        end procedure;

        procedure idle is
        begin
            we <= '0'; mret <= '0'; rst <= '0';
        end procedure;

        procedure do_write(a : std_logic_vector(11 downto 0); o : std_logic_vector(1 downto 0);
                           v : std_logic_vector(31 downto 0); tag : string) is
        begin
            idle;
            addr <= a; op <= o; src <= v; we <= '1';
            tick(tag);
            we <= '0';
        end procedure;

        procedure expect_read(a : std_logic_vector(11 downto 0); v : std_logic_vector(31 downto 0); tag : string) is
        begin
            addr <= a; we <= '0';
            wait for 1 ns;
            checks := checks + 1;
            if rdata /= v then
                errors := errors + 1;
                if errors <= 20 then
                    report tag & ": read " & hex(a) & " got " & hex(rdata) & " exp " & hex(v) severity error;
                end if;
            end if;
        end procedure;

        procedure do_reset is
        begin
            idle;
            rst <= '1';
            tick("reset");
            rst <= '0';
        end procedure;

        variable v : std_logic_vector(31 downto 0);
        variable a : std_logic_vector(11 downto 0);
        variable p : natural;
    begin
        irq <= '1';
        do_reset;
        for i in ADDRS'range loop
            if ADDRS(i) /= A_MIP then
                expect_read(ADDRS(i), ZERO, "after reset");
            end if;
        end loop;
        expect_read(A_MIP, x"00000800", "mip irq=1");
        irq <= '0';
        expect_read(A_MIP, ZERO, "mip irq=0");
        check(take_irq = '0', "take_irq after reset");

        do_write(A_MSTATUS, OP_RW, ONES, "rw mstatus ones");
        expect_read(A_MSTATUS, x"00000088", "mstatus only bits 3,7");
        do_write(A_MIE, OP_RW, ONES, "rw mie ones");
        expect_read(A_MIE, x"00000800", "mie only bit 11");
        do_write(A_MTVEC, OP_RW, ONES, "rw mtvec ones");
        expect_read(A_MTVEC, x"FFFFFFFC", "mtvec low bits 00");
        do_write(A_MEPC, OP_RW, ONES, "rw mepc ones");
        expect_read(A_MEPC, x"FFFFFFFC", "mepc low bits 00");
        do_write(A_MCAUSE, OP_RW, ONES, "rw mcause ones");
        expect_read(A_MCAUSE, ONES, "mcause full 32 bits");
        do_write(A_MIP, OP_RW, ONES, "rw mip ignored");
        expect_read(A_MIP, ZERO, "mip read-only");
        do_write(x"343", OP_RW, ONES, "rw unknown ignored");
        expect_read(x"343", ZERO, "unknown reads 0");
        expect_read(A_MTVEC, x"FFFFFFFC", "unknown write did not alias");

        do_write(A_MCAUSE, OP_RW, x"12345678", "rw mcause");
        do_write(A_MCAUSE, OP_RS, x"0000F00F", "rs mcause");
        expect_read(A_MCAUSE, x"1234F67F", "rs = or");
        do_write(A_MCAUSE, OP_RC, x"FF00000F", "rc mcause");
        expect_read(A_MCAUSE, x"0034F670", "rc = and not");
        do_write(A_MSTATUS, OP_RC, x"00000008", "rc mstatus.MIE");
        expect_read(A_MSTATUS, x"00000080", "mstatus MIE cleared");
        do_write(A_MSTATUS, OP_RS, x"00000008", "rs mstatus.MIE");
        expect_read(A_MSTATUS, x"00000088", "mstatus MIE set");
        do_write(A_MSTATUS, OP_RW, ZERO, "rw mstatus zero");

        idle;
        addr <= A_MCAUSE; op <= OP_RW; src <= x"DEADBEEF"; we <= '0';
        tick("we=0 no write");
        expect_read(A_MCAUSE, x"0034F670", "we=0 kept mcause");

        do_reset;
        for i in ADDRS'range loop
            if ADDRS(i) /= A_MIP then
                expect_read(ADDRS(i), ZERO, "reset clears");
            end if;
        end loop;

        for k in 0 to 7 loop
            do_reset;
            if (k mod 2) = 1 then do_write(A_MSTATUS, OP_RW, x"00000008", "en mie"); end if;
            if ((k / 2) mod 2) = 1 then do_write(A_MIE, OP_RW, x"00000800", "en meie"); end if;
            if (k / 4) = 1 then irq <= '1'; else irq <= '0'; end if;
            wait for 1 ns;
            check(take_irq = std_logic(to_unsigned(k, 3)(0) and to_unsigned(k, 3)(1) and to_unsigned(k, 3)(2)),
                  "take_irq truth table k=" & integer'image(k));
            irq <= '0';
        end loop;

        do_reset;
        do_write(A_MTVEC, OP_RW, x"00000100", "set mtvec");
        do_write(A_MIE, OP_RW, x"00000800", "set meie");
        do_write(A_MSTATUS, OP_RW, x"00000008", "set mie");
        check(mtvec = x"00000100", "mtvec out");
        idle;
        pc <= x"0000004E"; irq <= '1';
        addr <= A_MSTATUS; op <= OP_RW; src <= ZERO; we <= '1';
        wait for 1 ns;
        check(take_irq = '1', "take_irq high");
        tick("trap entry with csr write");
        we <= '0'; irq <= '0';
        expect_read(A_MEPC, x"0000004C", "mepc = pc low bits 00");
        check(mepc = x"0000004C", "mepc out port");
        expect_read(A_MCAUSE, CAUSE, "mcause on trap");
        expect_read(A_MSTATUS, x"00000080", "MPIE=1 MIE=0 after trap");
        check(take_irq = '0', "take_irq low after trap (MIE=0)");
        irq <= '1';
        wait for 1 ns;
        check(take_irq = '0', "no nested trap while MIE=0");
        do_write(A_MIP, OP_RW, ZERO, "mip write ignored");
        expect_read(A_MIP, x"00000800", "mip still shows irq");
        irq <= '0';
        idle;
        mret <= '1';
        addr <= A_MSTATUS; op <= OP_RW; src <= ZERO; we <= '1';
        tick("mret beats csr write");
        idle;
        expect_read(A_MSTATUS, x"00000088", "after mret MIE=1 MPIE=1");
        expect_read(A_MEPC, x"0000004C", "mret keeps mepc");

        do_write(A_MSTATUS, OP_RW, x"00000080", "MIE=0 MPIE=1");
        idle; mret <= '1'; tick("mret restores 1");
        idle; expect_read(A_MSTATUS, x"00000088", "mret MIE<-MPIE=1");
        do_write(A_MSTATUS, OP_RW, x"00000000", "MIE=0 MPIE=0");
        idle; mret <= '1'; tick("mret restores 0");
        idle; expect_read(A_MSTATUS, x"00000080", "mret MIE<-MPIE=0, MPIE<-1");

        do_write(A_MSTATUS, OP_RW, x"00000008", "MIE=1 MPIE=0");
        idle; irq <= '1'; mret <= '1'; pc <= x"00000200";
        tick("trap beats mret");
        idle; irq <= '0';
        expect_read(A_MSTATUS, x"00000080", "trap won over mret");
        expect_read(A_MEPC, x"00000200", "trap won: mepc");

        do_write(A_MSTATUS, OP_RW, x"00000008", "MIE=1");
        idle; irq <= '1'; pc <= x"00000300"; rst <= '1';
        tick("reset beats trap");
        idle; irq <= '0';
        expect_read(A_MSTATUS, ZERO, "reset won: mstatus");
        expect_read(A_MEPC, ZERO, "reset won: mepc");
        expect_read(A_MCAUSE, ZERO, "reset won: mcause");

        do_reset;
        for n in 1 to 30000 loop
            idle;
            p := rnd(16);
            if p < 12 then a := ADDRS(p); else a := ADDRS(rnd(ADDRS'length)); end if;
            addr <= a;
            op <= rnd_slv(2);
            case rnd(4) is
                when 0 => src <= ZERO;
                when 1 => src <= ONES;
                when 2 => v := ZERO; v(rnd(32)) := '1'; src <= v;
                when others => src <= rnd_slv(32);
            end case;
            if rnd(3) /= 0 then we <= '1'; end if;
            if rnd(8) = 0 then mret <= '1'; end if;
            if rnd(3) = 0 then irq <= '1'; else irq <= '0'; end if;
            if rnd(500) = 0 then rst <= '1'; end if;
            pc <= rnd_slv(32);
            tick("random #" & integer'image(n));
        end loop;

        if errors = 0 then
            report "tb_csr: PASS (" & integer'image(checks) & " checks)" severity note;
        else
            report "tb_csr: FAIL (" & integer'image(errors) & " of " & integer'image(checks) & " checks)" severity error;
        end if;
        std.env.stop;
        wait;
    end process;
end architecture sim;