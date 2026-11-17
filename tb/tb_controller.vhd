library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_controller is
end entity tb_controller;

architecture sim of tb_controller is
    signal instr     : std_logic_vector(31 downto 0) := (others => '0');
    signal zero      : std_logic := '0';
    signal reg_write : std_logic;
    signal alu_src   : std_logic;
    signal illegal   : std_logic;
    signal pc_src    : std_logic;
    signal alu_op    : std_logic_vector(3 downto 0);
    signal imm_src   : std_logic_vector(1 downto 0);

    signal ref_reg_write : std_logic;
    signal ref_alu_src   : std_logic;
    signal ref_illegal   : std_logic;
    signal ref_branch    : std_logic;
    signal ref_alu_op    : std_logic_vector(3 downto 0);
    signal ref_imm_src   : std_logic_vector(1 downto 0);

    type instr_array_t is array (natural range <>) of std_logic_vector(31 downto 0);
    type name_array_t is array (natural range <>) of string(1 to 12);

    constant INSTRS : instr_array_t := (
        x"002081B3", x"40208233", x"0020F2B3", x"00500093", x"FFF00393",
        x"00504093", x"40315093", x"00208463", x"FE000CE3", x"00418C63",
        x"00209463", x"02208233", x"00002083", x"00112023", x"008000EF",
        x"00000000", x"FFFFFFFF", x"40311093"
    );
    constant NAMES : name_array_t := (
        "add         ", "sub         ", "and         ", "addi 5      ", "addi -1     ",
        "xori        ", "srai        ", "beq +8      ", "beq -8      ", "beq +24     ",
        "bne         ", "mul         ", "lw          ", "sw          ", "jal         ",
        "zero        ", "ones        ", "slli bad f7 "
    );
begin
    dut : entity work.controller
        port map(
            instr     => instr,
            zero      => zero,
            reg_write => reg_write,
            alu_src   => alu_src,
            illegal   => illegal,
            pc_src    => pc_src,
            alu_op    => alu_op,
            imm_src   => imm_src
        );

    ref : entity work.control_unit
        port map(
            instr     => instr,
            reg_write => ref_reg_write,
            alu_op    => ref_alu_op,
            alu_src   => ref_alu_src,
            illegal   => ref_illegal,
            imm_src   => ref_imm_src,
            branch    => ref_branch
        );

    stim : process
        variable err      : natural := 0;
        variable cnt      : natural := 0;
        variable exp_src  : std_logic;
        variable is_beq   : boolean;
        variable z        : std_logic;
    begin
        for i in INSTRS'range loop
            for zi in 0 to 1 loop
                if zi = 0 then
                    z := '0';
                else
                    z := '1';
                end if;
                instr <= INSTRS(i);
                zero  <= z;
                wait for 10 ns;
                cnt := cnt + 1;

                is_beq := INSTRS(i)(6 downto 0) = "1100011" and INSTRS(i)(14 downto 12) = "000";
                if is_beq and z = '1' then
                    exp_src := '1';
                else
                    exp_src := '0';
                end if;

                if pc_src /= exp_src then
                    report "FAIL " & NAMES(i) & " zero=" & std_logic'image(z)
                        & " pc_src=" & std_logic'image(pc_src) & " expected=" & std_logic'image(exp_src) severity error;
                    err := err + 1;
                end if;

                if reg_write /= ref_reg_write or alu_src /= ref_alu_src or illegal /= ref_illegal
                   or alu_op /= ref_alu_op or imm_src /= ref_imm_src then
                    report "FAIL " & NAMES(i) & " zero=" & std_logic'image(z)
                        & " outputs differ from control_unit" severity error;
                    err := err + 1;
                end if;
            end loop;
        end loop;

        if err = 0 then
            report "tb_controller: ALL " & integer'image(cnt) & " TESTS PASSED" severity note;
        else
            report "tb_controller: " & integer'image(err) & " FAILURES" severity failure;
        end if;
        std.env.finish;
    end process;
end architecture sim;