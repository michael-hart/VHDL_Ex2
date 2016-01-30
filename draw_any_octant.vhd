-- Begin sub-entity swap
-- Takes two inputs and an active high boolean of whether
-- to swap. If low, outputs match inputs; if high, outputs
-- are swapped with inputs.

LIBRARY IEEE;

USE IEEE.std_logic_1164.ALL;

ENTITY swap IS 
	GENERIC (N : integer := 16);
	PORT(
		c : IN std_logic;
		xin, yin : IN std_logic_vector(N-1 DOWNTO 0);
		xout, yout : OUT std_logic_vector(N-1 DOWNTO 0)
	);
END ENTITY swap;

ARCHITECTURE rtl OF swap IS
	
	SIGNAL xout1, yout1 : std_logic_vector(N-1 DOWNTO 0);
	
	BEGIN
	-- Asynchronous combinational logic process
	C1: PROCESS(c, xin, yin)
		BEGIN
			-- Set default
			xout1 <= xin;
			yout1 <= yin;
			-- If c is asserted, swap the outputs
			IF c = '1' THEN
				xout1 <= yin;
				yout1 <= xin;
			END IF; -- c
		END PROCESS C1;
	
	-- Assign signals from process to outputs
	xout <= xout1;
	yout <= yout1;
	
	END ARCHITECTURE rtl;


---------------------------------------------------------
-- Begin sub-entity INV
-- When active high signal c is asserted, output b is the
-- inversion of input vector a; else, it is equal to a.

LIBRARY IEEE;

USE IEEE.std_logic_1164.ALL;

ENTITY inv IS
	GENERIC (N : integer := 16);
	PORT(
		a : IN std_logic_vector(N-1 DOWNTO 0);
		b : OUT std_logic_vector(N-1 DOWNTO 0);
		c : IN std_logic
	);
END ENTITY inv;

ARCHITECTURE rtl OF inv IS
	SIGNAL b1 : std_logic_vector(N-1 DOWNTO 0);
	BEGIN
	
	C1 : PROCESS (a,c) 
		BEGIN
			-- Set default as equal to input
			b1 <= a;
			-- Check for inversion
			IF c = '1' THEN 
				b1 <= not a;
			END IF; --c
		END PROCESS C1;
		
		-- Assign signals to outputs
		b <= b1;
	END ARCHITECTURE rtl;

---------------------------------------------------------
-- Begin sub-entity RD
-- 3-bit D-type register used to delay inputs by one
-- clock cycle. Disable prevents any change to outputs.

LIBRARY IEEE;

USE IEEE.std_logic_1164.ALL;

ENTITY rd IS 
	PORT(
		clk,  negx_in, negy_in, swapxy_in : IN std_logic;
		disable : IN std_logic;
		negx_out, negy_out, swapxy_out : OUT std_logic
	);
END ENTITY rd;

ARCHITECTURE behav OF rd IS
	SIGNAL negx, negy, swapxy : std_logic;
	BEGIN
		
	R1: PROCESS
		BEGIN
			-- Clocked signal, so wait until clock goes high
			WAIT UNTIL clk'EVENT AND clk = '1';
			
			-- If not disabled, assign inputs to signals
			IF disable = '0' THEN
				negx <= negx_in;
				negy <= negy_in;
				swapxy <= swapxy_in;
			END IF; --disable
			
		END PROCESS R1;
		
		-- Assign signals to outputs
		negx_out <= negx;
		negy_out <= negy;
		swapxy_out <= swapxy;

	END ARCHITECTURE behav;

---------------------------------------------------------
-- Begin entity draw_any_octant
-- Connects draw_octant hardware block to inverters, swap
-- blocks and registers to allow drawing in any octant.

LIBRARY IEEE;
LIBRARY WORK;

USE IEEE.std_logic_1164.ALL;
USE WORK.ALL;
	
-- changes 2016
-- resetx port renamed init for consistency with d-o port
-- disable port added

ENTITY draw_any_octant IS

  -- swapxy negx  negy  octant
  --  0      0      0     ENE
  --  1      0      0     NNE
  --  1      1      0     NNW
  --  0      1      0     WNW
  --  0      1      1     WSW
  --  1      1      1     SSW
  --  1      0      1     SSE
  --  0      0      1     ESE

  -- swapxy: x & y swap round on inputs & outputs
  -- negx:   invert bits of x on inputs & outputs
  -- negy:   invert bits of y on inputs & outputs

  -- xbias always give bias in x axis direction, so swapxy must invert xbias
  GENERIC(
    vsize: INTEGER := 16
  );
  
  PORT(
    clk, init, draw, xbias, disable : IN  std_logic;
    xin, yin                 : IN  std_logic_vector(vsize-1 DOWNTO 0);
    done                     : OUT std_logic;
    x, y                     : OUT std_logic_vector(vsize-1 DOWNTO 0);
    swapxy, negx, negy       : IN  std_logic
    );
END ENTITY draw_any_octant;

ARCHITECTURE comb OF draw_any_octant IS
	-- Outputs of RD module
	SIGNAL negx_delayed, negy_delayed, swapxy_delayed : std_logic;
	-- Outputs of first swap module, _s1 suffix is stage 1
	SIGNAL xin_s1, yin_s1 : std_logic_vector(vsize-1 DOWNTO 0);
	-- Outputs of first inverters, _s2 suffix denotes stage 2
	SIGNAL xin_s2, yin_s2 : std_logic_vector(vsize-1 DOWNTO 0);
	-- Outputs of draw_octant, _s1 suffix
	SIGNAL xout_s1, yout_s1 : std_logic_vector(vsize-1 DOWNTO 0);
	-- Outputs of second stage inverters, _s2 suffix
	SIGNAL xout_s2, yout_s2 : std_logic_vector(vsize-1 DOWNTO 0);
	
	SIGNAL xbias_i : std_logic;
	
BEGIN

	-- Apply inputs to RD
	RD1 : ENTITY rd PORT MAP (
		clk => clk, 
		negx_in => negx, 
		negy_in => negy, 
		swapxy_in => swapxy, 
		disable => disable,
		negx_out => negx_delayed, 
		negy_out => negy_delayed, 
		swapxy_out => swapxy_delayed
		);
	-- Map inputs through swap module to _s1 signals
	SWAP1 : ENTITY swap GENERIC MAP(N => vsize) PORT MAP (
		c => swapxy,
		xin => xin,
		yin => yin,
		xout => xin_s1,
		yout => yin_s1
	);
	-- Map stage 1 outputs through inverters
	INV1 : ENTITY inv GENERIC MAP(N => vsize) PORT MAP (
		c => negx,
		a => xin_s1,
		b => xin_s2
	);
	INV2 : ENTITY inv GENERIC MAP(N => vsize) PORT MAP (
		c => negy,
		a => yin_s1,
		b => yin_s2
	);
	
	XOR1: PROCESS(swapxy, xbias)
	BEGIN
		xbias_i <= swapxy XOR xbias;
	END PROCESS XOR1;
	
	-- Map all inputs to draw_octant
	DRAW1 : ENTITY draw_octant GENERIC MAP(vsize => vsize) PORT MAP (
		clk => clk,
		init => init,
		draw => draw,
		xbias => xbias_i,
		disable => disable,
		xin => xin_s2,
		yin => yin_s2,
		done => done,
		x => xout_s1,
		y => yout_s1
	);
	
	-- Map stage 1 outputs through second stage inverters
	INV3 : ENTITY inv GENERIC MAP(N => vsize) PORT MAP (
		c => negx_delayed,
		a => xout_s1,
		b => xout_s2
	);
	INV4 : ENTITY inv GENERIC MAP(N => vsize) PORT MAP (
		c => negy_delayed,
		a => yout_s1,
		b => yout_s2
	);
	
	-- Map stage 2 outputs through swap module to final outputs
	SWAP2 : ENTITY swap GENERIC MAP(N => vsize) PORT MAP (
		c => swapxy_delayed,
		xin => xout_s2,
		yin => yout_s2,
		xout => x,
		yout => y
	);
	
END ARCHITECTURE comb;

