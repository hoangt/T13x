library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.riscv_klessydra.all;
use work.thread_parameters_klessydra.all;
entity Scratchpad_memory_interface is
  port (
    clk_i, rst_ni              : in std_logic;
    data_rvalid_i              : in std_logic;
    dsp_parallel_read          : in std_logic_vector(1 downto 0);
    dsp_parallel_write         : in std_logic_vector(1 downto 0);
    ls_sc_data_write_wire      : in std_logic_vector(Data_Width/4 -1 downto 0);
    dsp_sc_data_write_wire     : in std_logic_vector(Data_Width -1 downto 0);
    ls_sc_read_addr            : in std_logic_vector(Addr_Width -1 downto 0);
    ls_sc_write_addr           : in std_logic_vector(Addr_Width -1 downto 0);
    dsp_sc_write_addr          : in std_logic_vector(Addr_Width -1 downto 0);
    ls_sci_req                 : in std_logic_vector(Num_SCs-1 downto 0);
    ls_sci_we                  : in std_logic_vector(Num_SCs-1 downto 0);
    dsp_sci_req                : in std_logic_vector(Num_SCs-1 downto 0);
    dsp_sci_we                 : in std_logic_vector(Num_SCs-1 downto 0);
    dsp_to_sc                  : in  array_2d(Num_Scs-1 downto 0)(1 downto 0);
    dsp_sc_read_addr           : in  array_2d(1 downto 0)(Addr_Width -1 downto 0);
    dsp_sc_data_read_wire      : out array_2d(1 downto 0)(Data_Width -1 downto 0);
    ls_sc_data_read_wire       : out std_logic_vector(Data_Width/4 - 1 downto 0);
    dsp_data_gnt_i             : out std_logic_vector(Num_SCs-1 downto 0);
    ls_data_gnt_i              : out std_logic_vector(Num_SCs-1 downto 0);
    halt_DSP                   : out std_logic;
    sci_err                    : out std_logic
	);
end entity;  
architecture SCI of Scratchpad_memory_interface is
signal data_rvalid_i_lat : std_logic;
signal sc_cycle_lat      : std_logic_vector(1 downto 0);
signal sc_cycle          : std_logic_vector(1 downto 0);
signal sc_addr_rd        : array_2d(4*Num_SCs-1 downto 0)(Addr_Width -1 downto 0);
signal sc_addr_wr        : array_2d(4*Num_SCs-1 downto 0)(Addr_Width -1 downto 0);
signal sc_data_rd        : array_2d(4*Num_SCs-1 downto 0)(31 downto 0);
signal sc_data_wr        : array_2d(4*Num_SCs-1 downto 0)(31 downto 0);
signal sc_we             : std_logic_vector(4*Num_SCs-1 downto 0);
signal halt_DSP_lat      : std_logic;
component Scratchpad_memory
  port(
       clk_i                                 : in   std_logic;
       sc_we                                 : in   std_logic_vector(4*Num_SCs-1 downto 0);
       sc_addr_rd                            : in   array_2d(4*Num_SCs-1 downto 0)(Addr_Width -1 downto 0);
       sc_addr_wr                            : in   array_2d(4*Num_SCs-1 downto 0)(Addr_Width -1 downto 0);
       sc_data_rd                            : out  array_2d(4*Num_SCs-1 downto 0)(31 downto 0);
       sc_data_wr                            : in   array_2d(4*Num_SCs-1 downto 0)(31 downto 0)
       );
end component;
begin
  SC : Scratchpad_memory
    port map(
       sc_we        => sc_we,
       clk_i        => clk_i,
       sc_addr_rd   => sc_addr_rd,
       sc_addr_wr   => sc_addr_wr,
       sc_data_wr   => sc_data_wr,
       sc_data_rd   => sc_data_rd
      );
  
  SCI_Exec_Unit : process(clk_i, rst_ni)  
  begin
    if rst_ni = '0' then
      ls_data_gnt_i <= (others => '0');
      dsp_data_gnt_i <= (others => '0');
      sc_cycle_lat  <= (others => '0');
      data_rvalid_i_lat <= '0';
      halt_DSP_lat  <= '0';
      sc_cycle <= (others => '0');
    elsif rising_edge(clk_i) then
      data_rvalid_i_lat <= data_rvalid_i;
      halt_DSP_lat  <= halt_DSP;
      sc_cycle <= "00";
      for i in 0 to 3 loop
        sc_cycle_lat <= sc_cycle;
        if ls_sci_we(i) = '1' then            
          if data_rvalid_i_lat = '1' then
            if sc_cycle /= "11" then
              sc_cycle <= std_logic_vector(unsigned(sc_cycle)+'1');
            else
              sc_cycle <= "00";
            end if;      
          end if;
        elsif ls_sci_we(i) = '0' and ls_sci_req(i) = '1' then
          if ls_sci_req(i) = '1' then
            if sc_cycle /= "11" then
              sc_cycle <= std_logic_vector(unsigned(sc_cycle)+'1');
            else
              sc_cycle <= "00";
            end if; 
          end if;
        end if;
          
        if ls_sci_req(i) = '1' then      
          ls_data_gnt_i(i) <= '1';
        elsif ls_sci_req(i) = '0' then
          ls_data_gnt_i(i) <= '0';
        end if;
		if dsp_sci_req(i) = '1' then
          dsp_data_gnt_i(i) <= '1';
	    elsif dsp_sci_req(i) = '0' then
		  dsp_data_gnt_i(i) <= '0';
	    end if;
			
      end loop;
    end if;
  end process;
  SCI_Exec_Unit_comb : process(all)
  begin
    halt_DSP      <= '0';
    sc_we         <= (others => '0');
			
    if rst_ni = '0' then
      ls_sc_data_read_wire  <= (others => '0');
      dsp_sc_data_read_wire <= (others => (others => '0'));
	  sc_data_wr            <= (others => (others => '0'));
	  sc_addr_rd            <= (others => (others => '0'));
	  sc_addr_wr            <= (others => (others => '0'));      
    else      
      for i in 0 to 3 loop	
		  
        if data_rvalid_i_lat = '1' then        
          if ls_sci_req(i) = '1' then
            if ls_sci_we(i) = '1' then
              sc_we(4*i + to_integer(unsigned(sc_cycle))) <= '1';
		      sc_data_wr(to_integer(unsigned(sc_cycle)) + 4*i) <= ls_sc_data_write_wire(31 downto 0);
              sc_addr_wr(to_integer(unsigned(sc_cycle)) + 4*i) <= ls_sc_write_addr;
            end if;
          end if;   
        end if;
	      if dsp_sci_req(i) = '1' then         
          for j in 0 to 3 loop        
            if dsp_sci_we(i) = '1' then
			        if to_integer(unsigned(dsp_parallel_write)) >= j then
                sc_we(4*i+(to_integer(unsigned(dsp_parallel_write))-j)) <= '1';
                sc_addr_wr(4*i+(to_integer(unsigned(dsp_parallel_write))-j)) <= dsp_sc_write_addr;
                sc_data_wr(4*i+(to_integer(unsigned(dsp_parallel_write))-j)) <= dsp_sc_data_write_wire((31+32*(to_integer(unsigned(dsp_parallel_write))-j)) downto 32*(to_integer(unsigned(dsp_parallel_write))-j));
              end if;
            end if;
	        end loop;
        end if;   
        if ls_sci_req(i) = '1' then         
          if ls_data_gnt_i(i) = '1' then
	          ls_sc_data_read_wire <= sc_data_rd(4*i + to_integer(unsigned(sc_cycle_lat)));  
          end if;
          sc_addr_rd(to_integer(unsigned(sc_cycle)) + 4*i) <= ls_sc_read_addr;
        end if;
	      if dsp_sci_req(i) = '1' and dsp_to_sc(i)(0) = '1' then         
            for j in 0 to 3 loop        
              if to_integer(unsigned(dsp_parallel_read)) >= j then
                if dsp_data_gnt_i(i) = '1' and halt_DSP_lat = '0' then
                  dsp_sc_data_read_wire(0)((31+32*(to_integer(unsigned(dsp_parallel_read))-j)) downto 32*(to_integer(unsigned(dsp_parallel_read))-j)) <= sc_data_rd(4*i+(to_integer(unsigned(dsp_parallel_read))-j));
                end if;
				if halt_DSP = '0' then
                  sc_addr_rd(4*i+(to_integer(unsigned(dsp_parallel_read))-j)) <= dsp_sc_read_addr(0);
				end if;
              end if;
	        end loop;
          elsif dsp_sci_req(i) = '1' and dsp_to_sc(i)(1) = '1' then       
            for j in 0 to 3 loop        
              if to_integer(unsigned(dsp_parallel_read)) >= j then
                if dsp_data_gnt_i(i) = '1' and halt_DSP_lat = '0' then
                  dsp_sc_data_read_wire(1)((31+32*(to_integer(unsigned(dsp_parallel_read))-j)) downto 32*(to_integer(unsigned(dsp_parallel_read))-j)) <= sc_data_rd(4*i+(to_integer(unsigned(dsp_parallel_read))-j));
                end if;
                if halt_DSP = '0' then
                  sc_addr_rd(4*i+(to_integer(unsigned(dsp_parallel_read))-j)) <= dsp_sc_read_addr(1);
				end if;
              end if;
	        end loop;			  
          end if;
        if dsp_sci_req(i) = '1' and ls_sci_we(i) = '1' then  
          if dsp_sc_read_addr(0) = ls_sc_write_addr  or  dsp_sc_read_addr(1) = ls_sc_write_addr  then
            halt_DSP <= '1';
          end if;
        end if;
        sci_err <= '1' when ls_sci_we(i) = '1' and dsp_sci_we(i) = '1' else '0';  
			
      end loop;	
    end if;
  end process;
			  
end SCI;
