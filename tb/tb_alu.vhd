library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all; 
  use ieee.math_real.all;
entity tb_alu is
end entity tb_alu;

architecture sim of tb_alu is
    type op_array_t is array (natural range <>) of std_logic_vector(3 downto 0);
    constant OPS : op_array_t := ("0000", "1000", "0001", "0010", "0011",
    "0100", "0101", "0110", "0111", "1101");
    
  signal value1           : std_logic_vector(31 downto 0) := (others => '0');
  signal value2           : std_logic_vector(31 downto 0) := (others => '0');
  signal zero        : std_logic                     := '0';
  signal alu_control : std_logic_vector(3 downto 0)  := (others => '0');
  signal result      : std_logic_vector(31 downto 0) := (others => '0');

begin

  dut : entity work.alu
    port map (
      a           => value1,
      b           => value2,
      alu_control => alu_control,
      result      => result,
      zero        => zero
    );

  process 
    variable seed1 : positive := 42;
     variable seed2: positive := 7;
     variable r: real;
     variable va:std_logic_vector(31 downto 0);
     variable vb: std_logic_vector(31 downto 0);
     variable vop: std_logic_vector(3 downto 0);
     variable vexp: std_logic_vector(31 downto 0);
     variable vzero:std_logic;
     variable errors: integer := 0;


     impure function rand_slv32
        return std_logic_vector is
        variable low: unsigned(15 downto 0);
        variable high: unsigned(15 downto 0);
        
     begin
        uniform(seed1, seed2, r);
        low := to_unsigned(integer(trunc(r * 65536.0)), 16);
        uniform(seed1, seed2, r); 
        high := to_unsigned(integer(trunc(r * 65536.0)), 16);
        return std_logic_vector(high & low);
     end function rand_slv32;
    
     

     impure function rand_op
        return std_logic_vector is
     
     begin
        uniform(seed1, seed2, r);
        return OPS(integer(trunc(r * real(OPS'length))));
     end function rand_op;


      function expected(a: std_logic_vector; b:std_logic_vector; op: std_logic_vector)
        return std_logic_vector is
     
     begin
        
       case op is
       when "0000" => return std_logic_vector(unsigned(a) + unsigned(b));
       when "1000" => return std_logic_vector(unsigned(a) - unsigned(b));
       when "0001" => return std_logic_vector(shift_left(unsigned(a), to_integer(unsigned(b(4 downto 0)))));
       when "0010" => case signed(a) < signed(b) is
       when true => return std_logic_vector(to_unsigned(1, 32));
       when others => return std_logic_vector(to_unsigned(0, 32));
       end case;
       when "0011" => case unsigned(a) < unsigned(b) is
       when true => return std_logic_vector(to_signed(1, 32));
      when others => return std_logic_vector(to_unsigned(0, 32));
       end case;

        when "0100" => return a xor b;

       when "0101" => return std_logic_vector(shift_right(unsigned(a), to_integer(unsigned(b(4 downto 0)))));
       when "0110" => return a or b;
       when "0111" => return a and b;
       when "1101" => return std_logic_vector(shift_right(signed(a), to_integer(unsigned(b(4 downto 0)))));
    when others => return std_logic_vector(to_unsigned(0, 32));
    end case;
     end function expected;
     
     



  begin

for i in 1 to 100000 loop
va := rand_slv32;
vb := rand_slv32;
vop := rand_op;
vexp := expected(va, vb, vop);
if vexp = x"00000000" then vzero := '1'; 
else vzero := '0';
end if;
value1
 <= va;
value2
 <= vb;
alu_control <= vop;
wait for 10 ns;
if result /= vexp then
    errors := errors + 1;
    report "FAIL #" & integer'image(i) &
              " op=" & to_string(vop) &
              " a=" & to_hstring(va) & " b=" & to_hstring(vb) &
              " exp=" & to_hstring(vexp) & " got=" & to_hstring(result)
              severity error;
end if;
if zero /= vzero then
errors := errors + 1;
 report "ZERO FAIL #" & integer'image(i) &
           " op=" & to_string(vop) &
           " a=" & to_hstring(va) & " b=" & to_hstring(vb) &
           " result=" & to_hstring(result) &
           " exp_zero=" & std_logic'image(vzero) &
           " got_zero=" & std_logic'image(zero)
           severity error;
end if;
end loop;

report "Random test finished, errors: " & integer'image(errors);

wait;

  end process;

end architecture sim;
