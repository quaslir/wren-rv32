library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity csr is
    port(
        clk      : in  std_logic;
        rst      : in  std_logic;
        we       : in  std_logic;
        addr     : in  std_logic_vector(11 downto 0);
        op       : in  std_logic_vector(1 downto 0);
        src      : in  std_logic_vector(31 downto 0);
        irq      : in  std_logic;
        mret     : in  std_logic;
        pc       : in  std_logic_vector(31 downto 0);
        rdata    : out std_logic_vector(31 downto 0);
        mtvec    : out std_logic_vector(31 downto 0);
        mepc     : out std_logic_vector(31 downto 0);
        take_irq : out std_logic
    );
end entity csr;

architecture synth of csr is
    signal mie_bit    : std_logic                     := '0'; -- Interrupt switcher, 1 - enable interrupts, 0 - disable
    signal mpie_bit   : std_logic                     := '0';
    signal meie_bit   : std_logic                     := '0'; -- enable "outside" interrupts.
    signal mtvec_reg  : std_logic_vector(29 downto 0) := (others => '0'); -- handle address
    signal mepc_reg   : std_logic_vector(29 downto 0) := (others => '0'); -- return address
    signal mcause_reg : std_logic_vector(31 downto 0) := (others => '0'); -- cause of entering the interrupt

    signal read_value   : std_logic_vector(31 downto 0) := (others => '0');
    signal new_value    : std_logic_vector(31 downto 0) := (others => '0');
    signal take_irq_int : std_logic                     := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mie_bit    <= '0';
                mpie_bit   <= '0';
                meie_bit   <= '0';
                mtvec_reg  <= (others => '0');
                mepc_reg   <= (others => '0');
                mcause_reg <= (others => '0');
            else
                if take_irq_int = '1' then
                    mepc_reg   <= pc(31 downto 2);
                    mcause_reg <= x"8000000B";
                    mpie_bit   <= mie_bit;
                    mie_bit    <= '0';

                elsif mret = '1' then
                    mie_bit  <= mpie_bit;
                    mpie_bit <= '1';
                elsif we = '1' then
                    case addr is
                        when x"300" =>  --mstatus
                            mie_bit  <= new_value(3);
                            mpie_bit <= new_value(7);
                        when x"304" =>  -- machine interrupt enable
                            meie_bit <= new_value(11);
                        when x"305" =>  -- machine TRAP vector
                            mtvec_reg <= new_value(31 downto 2);
                        when x"341" =>  -- machine exception PC (return address)
                            mepc_reg <= new_value(31 downto 2);
                        when x"342" =>  -- cause of entering the interrupt
                            mcause_reg <= new_value;
        
                        when others => null;
                    end case;

                end if;
            end if;
        end if;

    end process;

    process(addr, irq, mcause_reg, meie_bit, mepc_reg, mpie_bit, mie_bit, mtvec_reg)
    begin
        read_value <= (others => '0');
        case addr is
            when x"300" =>              --mstatus
                read_value(3) <= mie_bit;
                read_value(7) <= mpie_bit;
            when x"304" =>              -- machine interrupt enable
                read_value(11) <= meie_bit;
            when x"305" =>              -- machine TRAP vector
                read_value(31 downto 2) <= mtvec_reg;
            when x"341" =>              -- machine exception PC (return address)
                read_value(31 downto 2) <= mepc_reg;
            when x"342" =>              -- cause of entering the interrupt
                read_value <= mcause_reg;
            when x"344" =>
                read_value(11) <= irq;
            when others => null;
        end case;

    end process;

    new_value <= src when op = "01" else -- csrrw
    read_value or src when op = "10" else -- csrrs
    read_value and not src when op = "11" else -- csrrc
    read_value;



    take_irq_int <= irq and meie_bit and mie_bit;


    rdata <= read_value;
    mtvec <= mtvec_reg & "00";
    mepc <= mepc_reg & "00";
    take_irq <= take_irq_int;
end architecture synth;
