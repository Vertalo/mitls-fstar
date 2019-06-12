﻿(** computational assumption: collision resistance *)
module Hashing.CRF

open Mem
include Hashing
open FStar.Bytes

//2018.04.24 SZ: to be moved elsewhere, set to false for real extraction
inline_for_extraction
val crf: alg -> Tot bool
let crf _ = false

(* Depending on a single, global idealization function, we keep a global
    inverse table for all (finalized) hash computations, and we use it to
    detect concrete collisions. Technically, this is modelled as
    non-termination of a stateful, partially-correct finalize filter.
    This may depend on some prior flag to keep the hashed input in the
    incremental hash implementation. (This is always the case for now.)  *)

module MDM = FStar.Monotonic.DependentMap 

// the precise types guarantee that the table stays empty when crf _ = false
private type range = | Computed: a: alg {crf a} -> t: tag a -> range
private type domain (r:range) =
  b:bytes {let Computed a t = r in length b <= max_input_length a /\ h a b = t}

private let inv (f:MDM.partial_dependent_map range domain) = True // a bit overkill?
private let table : MDM.t tls_tables_region range domain inv = MDM.alloc()

// witnessing that we hashed this particular content (for collision detection)
// to be replaced by a witness of inclusion in a global table of all hash computations.
// (not sure how to manage that table)

//val hashed: a:alg -> b:bytes -> Type
abstract type hashed (a:alg) (b:hashable a) =
  crf a ==> (
    let t = h a b in
    let b: domain (Computed a t) = b in
    witnessed (MDM.contains table (Computed a t) b))

val crf_injective (a:alg) (b0 b1:hashable a): ST unit  // should be STTot
  (requires fun h0 -> hashed a b0 /\ hashed a b1)
  (ensures fun t0 _ t1 -> t0 == t1 /\ (crf a /\ h a b0 =  h a b1 ==> b0 = b1))
let crf_injective a b0 b1 =
  if crf a then (
    recall table;
    let f = !table in
    testify(MDM.contains table (Computed a (h a b0)) b0);
    testify(MDM.contains table (Computed a (h a b1)) b1)
  )

/// We use [stop] to model the exclusion of "bad" events, in this case
/// a hash collision.  We should review this "flagless" style for
/// crypto modelling.

private val stop: s:string -> ST 'a
  (requires (fun h -> True))
  (ensures (fun h0 r h1 -> False))
let rec stop (s:string) = stop s


val finalize: #a:alg -> v:accv a -> ST (tag a)
  (requires (fun h0 -> True))
  (ensures (fun h0 t h1 ->
    let b = content v in
    //18-01-03 TODO modifies (Set.as_set [TLSConstants.tls_tables_region]) h0 h1 /\
    t = h a b /\ hashed a b
  ))

#set-options "--admit_smt_queries true" //18-02-26 was verified with MonotonicMap
let finalize #a v =
  let t = Hashing.finalize v in
  if crf a then (
    let x = Computed a t in
    let b = Hashing.content v in
    match MDM.lookup table x with
      | None -> MDM.extend table x b
      | Some b' -> if b <> b' then stop "hash collision detected");
  t
#reset-options 

#set-options "--z3rlimit 100"
// sanity check
private val test 
  (a:alg) 
  (b0: hashable a)
  (b1: bytes {length b1 + length b1 <= max_input_length a}): St unit
let test a b0 b1 =
  // we need to record *both* computations
  let h = finalize (extend (start a) b0) in
  let h' = finalize (extend (extend (start a) b1) b1) in

  // ...and, annoyingly, to normalize concatenations
  //18-02-25 TODO those two were at least assertable with Platform.Bytes
  assume(empty_bytes @| b0 = b0);
  assume((empty_bytes @| b1) @| b1 = b1 @| b1);

  if h <> h' then assert(b0 <> b1 @| b1);

  // ...and to apply a stateful lemma
  crf_injective a b0 (b1 @| b1);
  if h = h' then assert(crf a ==> b0 = b1 @| b1)
