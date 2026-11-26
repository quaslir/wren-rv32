library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity alu is
  port (
    a           : in    std_logic_vector(31 downto 0);
    b           : in    std_logic_vector(31 downto 0);
    alu_control : in    std_logic_vector(3 downto 0);
    result      : out   std_logic_vector(31 downto 0);
    zero        : out   std_logic
  );
end entity alu;

architecture synth of alu is

  signal res_int : std_logic_vector(31 downto 0);

  function from_bool_to_logic_vector (
    value : boolean
  )
        return std_logic_vector is
  begin

    if (value) then
      return std_logic_vector(to_unsigned(1, 32));
    else
      return std_logic_vector(to_unsigned(0, 32));
    end if;

  end function from_bool_to_logic_vector;

begin

  res_int <= std_logic_vector(unsigned(a) + unsigned(b)) when alu_control = "0000" else
             std_logic_vector(unsigned(a) - unsigned(b)) when alu_control = "1000" else
             std_logic_vector(shift_left(unsigned(a), to_integer(unsigned(b(4 downto 0))))) when alu_control = "0001" else
             from_bool_to_logic_vector(signed(a) < signed(b)) when alu_control = "0010" else
             from_bool_to_logic_vector(unsigned(a) < unsigned(b)) when alu_control = "0011" else
             a xor b when alu_control = "0100" else
             std_logic_vector(shift_right(unsigned(a), to_integer(unsigned(b(4 downto 0))))) when alu_control = "0101" else
             a or b when alu_control = "0110" else
             a and b when alu_control = "0111" else
             std_logic_vector(shift_right(signed(a), to_integer(unsigned(b(4 downto 0))))) when alu_control = "1101" else
             (others => '0');

  result <= res_int;

  zero <= '1' when res_int = std_logic_vector(to_unsigned(0, 32)) else
          '0';

end architecture synth;
