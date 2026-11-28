library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hazard_unit is
    port(        -- forwarding
        rs1_e       : in  std_logic_vector(4 downto 0);  -- source reg 1 of instr in EX
        rs2_e       : in  std_logic_vector(4 downto 0);  -- source reg 2 of instr in EX
        rd_m        : in  std_logic_vector(4 downto 0);  -- dest reg of instr in MEM
        reg_write_m : in  std_logic;                     -- instr in MEM writes a register
        rd_w        : in  std_logic_vector(4 downto 0);  -- dest reg of instr in WB
        reg_write_w : in  std_logic;                     -- instr in WB writes a register

        -- load-use stall
        rs1_d       : in  std_logic_vector(4 downto 0);  -- source reg 1 of instr in ID
        rs2_d       : in  std_logic_vector(4 downto 0);  -- source reg 2 of instr in ID
        rd_e        : in  std_logic_vector(4 downto 0);  -- dest reg of instr in EX
        load_e      : in  std_logic;                     -- instr in EX is a load

        -- branch flush
        pc_src_e    : in  std_logic_vector(1 downto 0);  -- next-pc select, /= "00": pc redirected

        -- outputs
        forward_a_e : out std_logic_vector(1 downto 0);  -- ALU A source: 00 reg file, 01 WB, 10 MEM
        forward_b_e : out std_logic_vector(1 downto 0);  -- ALU B source: 00 reg file, 01 WB, 10 MEM
        stall_f     : out std_logic;                     -- hold pc
        stall_d     : out std_logic;                     -- hold IF/ID register
        flush_d     : out std_logic;                     -- clear IF/ID (instr becomes nop)
        flush_e     : out std_logic                      -- clear ID/EX (insert bubble)
    );
end entity hazard_unit;


architecture synth of hazard_unit is
    signal lw_stall : std_logic := '0';
    signal br_flush: std_logic := '0';
begin
    forward_a_e <= "10" when reg_write_m = '1' and rd_m = rs1_e  and rs1_e /= "00000" else 
        "01" when reg_write_w = '1' and rd_w = rs1_e and rs1_e /= "00000" else
        "00";
    forward_b_e <= "10" when reg_write_m = '1' and rd_m = rs2_e and rs2_e /= "00000" else
         "01" when reg_write_w = '1' and rd_w = rs2_e and rs2_e /= "00000" else
        "00";
    

        lw_stall <= '1' when load_e = '1' and (rd_e = rs1_d or rd_e = rs2_d) and rd_e /= "00000" else '0';
        br_flush <= '0' when pc_src_e = "00" else '1'; 
            
        stall_f <= lw_stall;
        stall_d <= lw_stall;
        flush_d <= br_flush;
        flush_e <= br_flush or lw_stall;
end architecture synth;

