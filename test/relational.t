  $ electrod --na --pg $TESTDIR/relational.elo
  electrod* (glob)
  Processing file:* (glob)
  Generated file:
  -- Generated* (glob)
  MODULE main
  JUSTICE TRUE;
  
  
  -- ((s.r) = (s.r))
  INVAR
  TRUE;
  
  -- ((m ++ n) = m_plusplus_n)
  INVAR
  TRUE;
  
  -- ((r ++ t) = r_overriden_by_t)
  INVAR
  TRUE;
  
  -- ((s <: (^r)) = s_proj_tc)
  INVAR
  TRUE;
  
  -- ((^(~r)) = (~(^r)))
  INVAR
  TRUE;
  
  -- ((s.r) = ((~r).s))
  INVAR
  TRUE;
  
  -- (iden_plus_tc_r = (iden + (^r)))
  INVAR
  TRUE;
  
  -- ((*r) = iden_plus_tc_r)
  INVAR
  TRUE;
  
  -- ((s.(*r)) = (s.(iden + (^r))))
  INVAR
  TRUE;
  
  -- (tc_r = (^r))
  INVAR
  TRUE;
  
  -- (symmetric = (~symmetric))
  INVAR
  TRUE;
  
  -- ((reflexive - iden) in none)
  INVAR
  TRUE;
  
  
  
  
  -- (not (eventually (some some/0 : z {true})))
  LTLSPEC
  !(F z$l);
  
  
  VAR z$l : boolean;
  
  
  Elapsed* (glob)
