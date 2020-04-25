(** Expansion of secrets into expanded secrets *)
module KDF.Salt.ODH

open FStar.Heap
open FStar.HyperStack
open FStar.Bytes
open FStar.Error

open Mem
open TLSConstants
open TLSInfo

module HS = FStar.HyperStack

(* Source index is a secret index *)
type id = secretId

type state (i:id) =
  | State: r:rgn -> state i
