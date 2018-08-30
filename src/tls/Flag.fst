module Flag

module ST = FStar.HyperStack.ST

open FStar.HyperStack.All

open Crypto.Indexing

(* All the idealization flags that we use for the cryptographic argument *)

// TODO check that the real implementation normalizes fully.


(* CRYPTOGRAPHIC SECURITY ASSUMPTIONS.
   These are not conditioned by i. 
   They suffice to select every intermediate game in our proof.
   They are ordered as successive idealization steps in our proof.
   We used to refer to those as "algorithmic strength predicates".
*) 

// controls idealization of each cipher as a perfect random function
assume 
val cipher_prf: cipherAlg -> Tot bool 

// controls existence of logs for all MACs
assume
val mac_log: bool                

// idealizes each one-time MAC as perfectly INT-1CMA.
assume
val mac_int1cma: macAlg -> Tot bool  

// controls 2nd, perfect idealization step in enxor/dexor for all PRFs.
assume
val prf_cpa: bool


(* CONDITIONAL IDEALIZATION *) 

// guarantees fresh record keys (to be defined by TLS Handshake)
assume
val safeHS: i:id -> GTot bool 

// controls PRF idealization of ciphers (move to PRF?)
let prf (i: id): GTot bool = safeHS i && cipher_prf(cipherAlg_of_id i)

// controls INT1CMA idealization of MACs (move to MAC?)
let mac1 i: GTot bool = mac_log && mac_int1cma (macAlg_of_id i)



let idealAEAD : bool = Flags.ideal_AEAD

assume val safeId : (i:id) -> b:bool{b ==> idealAEAD}

// pne abstraction
assume val idealPNE : b:bool{b ==> idealAEAD}

assume val safePNE : i:id -> b:bool{b ==> idealPNE}

// quic abstraction
assume val idealQUIC : b:bool{b ==> idealPNE}

assume val safeQUIC : (i:id) -> b:bool{b ==> idealQUIC}


(* IDEALIZATION DEPENDENCIES *) 

// review usage of these lemmas

let mac1_implies_mac_log (i:id) : Lemma
  (requires (mac1 i))
  (ensures mac_log)
  [SMTPat (mac1 i)] = ()

assume
val mac1_implies_prf (i:id) : Lemma
  (requires (mac1 i))
  (ensures (prf i))
  [SMTPat (mac1 i)]

assume
val safeId_implies_mac1: i:id -> Lemma
  (requires (safeId i))
  (ensures (mac1 i))
  [SMTPat (safeId i)]

assume
val safeId_implies_cpa: i:id -> Lemma
  (requires (safeId i))
  (ensures (prf_cpa))
  [SMTPat (safeId i)]

assume
val aes_ct : bool

