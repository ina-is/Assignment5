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
--    rsSel <= IFOut(?);  -- rs Select
--    rtSel <= IFOut(?);  -- rt Select
--    Rstd <= ? & ? & ? when (rtSet = '1') else  -- rs, rt, WB.rt
--            ? & ? & ? ;  -- rs, rt, WB.rd

    RSel <= rsSel & rtSel;
    RSet <= '1' & '0' & '0' when (rtSet = '1') else  -- rt
            rdSet & rtSet & r31Set;

    RFi : RF port map (CLK, RESET, Rstd, Rsel, rC, RSet, rA, rB);  -- RF Instance

--    IDIn <= ? & ? & ?;  -- rA & rB & IFOut
    IDEX : PR generic map (128) port map (CLK, RESET, IDIn, IDOut);

-- EX : Execution
--    pc4addrSel <= IDOut(?);  -- pc + 4 + addr Select
--    addrSel <= IDOut(?);  -- addr Selct
--    rASel <= IDOut(?);  -- rAEX Select
--    ALUPlus <= IDOut(?);  -- ALU +
--    ALUMinus <= IDOut(?);  -- ALU -
--    iaSel <= IDOut(?);  -- imm/addr Select

--    imm <= X"FFFF" & IDOut(?) when (IDOut(?) = '1') else  -- imm
--           X"0000" & IDOut(?);  -- 32 bit Signed

--    AIn <= IDOut(?);  -- rA
--    BIn <= imm when (iaSel = '1') else  -- Immediate
--           IDOut(?); -- rB
    ALUi : ALU port map (AIn, BIn, ALUPlus, ALUMinus, ALUOut);  -- ALU Instance
    ALUZero <= '1' when (ALUOut = 0) else
               '0';
--    pc4EX <= IDOut(?);  -- EX pc+4
--    addr <= IDOut(?);  -- EX addr
--    rAEX <= IDOut(?);  -- EX rA

--    EXIn <= ? & ?;  -- ALUOut & IDOut
    EXMEM : PR generic map (128) port map (CLK, RESET, EXIn, EXOut);

-- MEM : Memory
--    MRead <= EXOut(?);   -- Memory Read
--    MWrite <= EXOut(?);   -- Memory Write

--    DMA <= EXOut(?);  -- ALUOut
--    DMIn <= EXOut(?);  -- rB
    DMi : DM port map (CLK, DMA, DMIn, DMOut, MRead, MWrite);  -- DM Instance

--    MEMIn <= ? & ? & ?;  -- ALUOut & DMOut & EXOut
    MEMWB : PR generic map (128) port map (CLK, RESET, MEMIn, MEMOut);

-- WB : Write Back
--    EXSel <= MEMOut(?);  -- EX Select
--    MEMSel <= MEMOut(?);  -- MEM Select
--    pc4Sel <= MEMOut(?);  -- pc + 4 Select
--    rdSet <= MEMOut(?);  -- rd Set
--    rtSet <= MEMOut(?);  -- rt Set
--    r31Set <= MEMOut(?);  -- r31 Set
--    pc4WB <= MEMOut(?);  -- WB pc + 4 Return Address

--    rC <= MEMOut(?) when (EXSel = '1') else  -- ALUout
--          MEMOut(?) when (MEMSel = '1') else  -- DMOut
--          pc4WB when (pc4Sel = '1') else  -- pc + 4
--          (others => '0');

end RTL;