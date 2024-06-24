-- Top Module of MIPS Pipeline --

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity MIPSp is
    port(
        CLK, RESET : in std_logic;
        PCOut : out std_logic_vector(7 downto 0)
    );
end MIPSp;

architecture RTL of MIPSp is
component IM is
    port(
        CLK : in std_logic;
        IMA : in std_logic_vector(31 downto 0);
        IMOut : out std_logic_vector(31 downto 0)
    );
end component;

component MP is
    port(
        CLK : in std_logic;
        OP : in std_logic_vector(5 downto 0);
        MPC : out std_logic_vector(15 downto 0)
    );
end component;

component RF is
    port(
        CLK, RESET : in std_logic;
        Rstd : in std_logic_vector(14 downto 0);  -- rs, rt, rd
        RSel : in std_logic_vector(1 downto 0);  -- rsSel, rtSel
        rC : in std_logic_vector(31 downto 0);
        RSet : in std_logic_vector(2 downto 0);  -- rdSet, rtSet, r31Set
        rA, rB : out std_logic_vector(31 downto 0)
    );
end component;

component ALU is
    port(
        AIn, BIn : in std_logic_vector(31 downto 0);
        ALUPlus, ALUMinus : in std_logic;
        ALUOut : out std_logic_vector(31 downto 0)
    );
end component;

component DM is
    port(
        CLK : in std_logic;
        DMA : in std_logic_vector(31 downto 0); 
        DMIn : in std_logic_vector(31 downto 0);
        DMOut : out std_logic_vector(31 downto 0);
        MRead, MWrite : in std_logic
    );
end component;

component PR is
    generic(N : integer);
    port(
        CLK, RESET : in std_logic;
        PRin : in std_logic_vector(N-1 downto 0);
        PROut : out std_logic_vector(N-1 downto 0)
    );
end component;

signal pc4, pc4EX, pc4WB : std_logic_vector(31 downto 0);

-- IF
signal pc : std_logic_vector(31 downto 0);  -- Address
signal IMOut : std_logic_vector(31 downto 0);  -- Instruction
signal op : std_logic_vector(5 downto 0);
signal imm : std_logic_vector(31 downto 0);
signal addr : std_logic_vector(25 downto 0);
signal IFIn, IFOut : std_logic_vector(127 downto 0);

-- MP
signal MPC : std_logic_vector(15 downto 0);  -- MP Control
signal pc4addrSel, addrSel, rASel : std_logic;  -- IF
signal rsSel, rtSel : std_logic;  -- ID
signal ALUPlus, ALUMinus, iaSel : std_logic;  -- EX
signal MRead, MWrite : std_logic;  -- MEM
signal EXSel, MEMSel, pc4Sel, rdSet, rtSet, r31Set : std_logic;  -- WB

-- ID
signal Rstd : std_logic_vector(14 downto 0);  -- rs, rt, rd
signal RSel : std_logic_vector(1 downto 0);  -- rsSel, rtSel
signal RSet : std_logic_vector(2 downto 0);  -- rdSet, rtSet, r31Set
signal rA, rB, rC : std_logic_vector(31 downto 0);
signal IDIn, IDOut : std_logic_vector(127 downto 0);

-- EX
signal AIn, BIn, ALUOut, rAEX : std_logic_vector(31 downto 0);
signal ALUzero : std_logic;
signal EXIn, EXOut : std_logic_vector(127 downto 0);

-- MEM
signal DMA : std_logic_vector(31 downto 0);
signal DMIn, DMOut : std_logic_vector(31 downto 0);
signal MEMIn, MEMOut : std_logic_vector(127 downto 0);

begin

    PCout <= pc(7 downto 0);
    pc4 <= pc + 4;

-- IF : Instruction Fetch
    process(CLK, RESET)
    variable sel : std_logic_vector(2 downto 0);
    begin
        if (RESET = '0') then
            pc <= (others => '0');
        elsif (CLK'event and CLK = '1') then
            sel := (pc4addrSel and ALUZero) & addrSel & rASel;
            case (sel) is
                when "100" => pc <= pc4EX + (imm(29 downto 0) & "00");  -- beq
                when "010" => pc <= "0000" & addr & "00";  -- j, jal
                when "001" => pc <= rAEX;  -- jr
                when others => pc <= pc4;
            end case;
        end if;
    end process;

    IMi : IM port map (CLK, pc, IMOut);  -- IM Instance
    op <= IMOut(31 downto 26);

-- MP : Micro Program
    MPi : MP port map (CLK, op, MPC);  -- MP Instance

--    IFIn <= X"0000000000000000" & ? & ? & ?;  -- IMOut & pc4 & MPC
    IFID : PR generic map (128) port map (CLK, RESET, IFIn, IFOut);

-- ID : Instruction Decode
   rsSel <= IFOut(12);  -- rs Select
   rtSel <= IFOut(11);  -- rt Select
   Rstd <= IFOut(57 downto 53) & IFOut(52 downto 48) & MEMOut(52 downto 48) when (rtSet = '1') else  -- rs, rt, WB.rt
           IFOut(57 downto 53) & IFOut(52 downto 48) & MEMOut(47 downto 43) ;  -- rs, rt, WB.rd

    RSel <= rsSel & rtSel;
    RSet <= '1' & '0' & '0' when (rtSet = '1') else  -- rt
            rdSet & rtSet & r31Set;

    RFi : RF port map (CLK, RESET, Rstd, Rsel, rC, RSet, rA, rB);  -- RF Instance

   IDIn <= rA & rB & IFOut(63 downto 0);  -- rA & rB & IFOut
    IDEX : PR generic map (128) port map (CLK, RESET, IDIn, IDOut);

-- EX : Execution
   pc4addrSel <= IDOut(15);  -- pc + 4 + addr Select
   addrSel <= IDOut(14);  -- addr Selct
   rASel <= IDOut(13);  -- rAEX Select
   ALUPlus <= IDOut(10);  -- ALU +
   ALUMinus <= IDOut(9);  -- ALU -
   iaSel <= IDOut(8);  -- imm/addr Select

   imm <= X"FFFF" & IDOut(47 downto 32) when (IDOut(47) = '1') else  -- imm
          X"0000" & IDOut(47 downto 32);  -- 32 bit Signed

   AIn <= IDOut(127 downto 96);  -- rA
   BIn <= imm when (iaSel = '1') else  -- Immediate
          IDOut(95 downto 64); -- rB
    ALUi : ALU port map (AIn, BIn, ALUPlus, ALUMinus, ALUOut);  -- ALU Instance
    ALUZero <= '1' when (ALUOut = 0) else
               '0';
   pc4EX <= IDOut(31 downto 16);  -- EX pc+4
   addr <= IDOut(57 downto 32);  -- EX addr
   rAEX <= IDOut(127 downto 96);  -- EX rA

   EXIn <= ALUOut & IDOut(95 downto 0);  -- ALUOut & IDOut
    EXMEM : PR generic map (128) port map (CLK, RESET, EXIn, EXOut);

-- MEM : Memory
   MRead <= EXOut(7);   -- Memory Read
   MWrite <= EXOut(6);   -- Memory Write

   DMA <= EXOut(127 downto 96);  -- ALUOut
   DMIn <= EXOut(95 downto 64);  -- rB
    DMi : DM port map (CLK, DMA, DMIn, DMOut, MRead, MWrite);  -- DM Instance

   MEMIn <= EXOut(127 downto 96) & DMOut & EXOut(63 downto 0);  -- ALUOut & DMOut & EXOut
    MEMWB : PR generic map (128) port map (CLK, RESET, MEMIn, MEMOut);

-- WB : Write Back
   EXSel <= MEMOut(5);  -- EX Select
   MEMSel <= MEMOut(4);  -- MEM Select
   pc4Sel <= MEMOut(3);  -- pc + 4 Select
   rdSet <= MEMOut(2);  -- rd Set
   rtSet <= MEMOut(1);  -- rt Set
   r31Set <= MEMOut(0);  -- r31 Set
   pc4WB <= X"0000" & MEMOut(31 downto 16);  -- WB pc + 4 Return Address

   rC <= MEMOut(127 downto 96) when (EXSel = '1') else  -- ALUout
         MEMOut(95 downto 64) when (MEMSel = '1') else  -- DMOut
         pc4WB when (pc4Sel = '1') else  -- pc + 4
         (others => '0');

end RTL;