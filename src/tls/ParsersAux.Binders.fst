module ParsersAux.Binders

module LP = LowParse.Low.Base
module LI = LowParse.Spec.BoundedInt
module HS = FStar.HyperStack
module U32 = FStar.UInt32

(* ClientHello binders *)

module L = FStar.List.Tot
module H = ParsersAux.Handshake
module CH = Parsers.ClientHello
module CHE = ParsersAux.ClientHelloExtension

module BY = FStar.Bytes

module B = LowStar.Monotonic.Buffer
module HST = FStar.HyperStack.ST

module Psks = Parsers.OfferedPsks

module ET = Parsers.ExtensionType
module CHEs = Parsers.ClientHelloExtensions
module HT = Parsers.HandshakeType

open ParsersAux.Binders.Aux

let offeredPsks_set_binders
  (o: Psks.offeredPsks)
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize o.Psks.binders })
: Tot (o' : Psks.offeredPsks {
    o'.Psks.identities == o.Psks.identities /\
    o'.Psks.binders == b' /\
    Psks.offeredPsks_bytesize o' == Psks.offeredPsks_bytesize o
  })
= {
  Psks.identities = o.Psks.identities;
  Psks.binders = b';
}

let offeredPsks_binders_offset
  (o: Psks.offeredPsks)
: Tot (x: U32.t {
    let s = LP.serialize Psks.offeredPsks_serializer o in
    U32.v x < Seq.length s
  })
= serialize_offeredPsks_eq o;
  Psks.offeredPsks_identities_size32 o.Psks.identities

let truncate_offeredPsks
  (o: Psks.offeredPsks)
: GTot LP.bytes
= Seq.slice (LP.serialize Psks.offeredPsks_serializer o) 0 (U32.v (offeredPsks_binders_offset o))

let binders_offset_offeredPsks_set_binders
  (o: Psks.offeredPsks)
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize o.Psks.binders })
: Lemma
  (let o' = offeredPsks_set_binders o b' in
  let off = offeredPsks_binders_offset o in
  let tr = truncate_offeredPsks o in
  offeredPsks_binders_offset o' == off /\
  truncate_offeredPsks o' `Seq.equal` tr /\
  LP.serialize Psks.offeredPsks_serializer o' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let o' = offeredPsks_set_binders o b' in
  let off = offeredPsks_binders_offset o in
  serialize_offeredPsks_eq o;
  serialize_offeredPsks_eq o'

let truncate_offeredPsks_eq_left
  (o: Psks.offeredPsks)
: Lemma
  (truncate_offeredPsks o `Seq.equal` LP.serialize Psks.offeredPsks_identities_serializer o.Psks.identities)
= serialize_offeredPsks_eq o

let clientHelloExtension_CHE_pre_shared_key_set_binders
  (o: CHE.clientHelloExtension_CHE_pre_shared_key)
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize o.Psks.binders })
: Tot (o' : CHE.clientHelloExtension_CHE_pre_shared_key {
    o'.Psks.identities == o.Psks.identities /\
    o'.Psks.binders == b' /\
    CHE.clientHelloExtension_CHE_pre_shared_key_bytesize o' == CHE.clientHelloExtension_CHE_pre_shared_key_bytesize o
  })
= offeredPsks_set_binders o b'

let clientHelloExtension_CHE_pre_shared_key_binders_offset
  (o: CHE.clientHelloExtension_CHE_pre_shared_key)
: Tot (x: U32.t {
    let s = LP.serialize CHE.clientHelloExtension_CHE_pre_shared_key_serializer o in
    U32.v x < Seq.length s
  })
= serialize_clientHelloExtension_CHE_pre_shared_key_eq o;
  2ul `U32.add` offeredPsks_binders_offset o

let truncate_clientHelloExtension_CHE_pre_shared_key
  (o: CHE.clientHelloExtension_CHE_pre_shared_key)
: GTot LP.bytes
= Seq.slice (LP.serialize CHE.clientHelloExtension_CHE_pre_shared_key_serializer o) 0 (U32.v (clientHelloExtension_CHE_pre_shared_key_binders_offset o))

let binders_offset_clientHelloExtension_CHE_pre_shared_key_set_binders
  (o: CHE.clientHelloExtension_CHE_pre_shared_key)
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize o.Psks.binders })
: Lemma
  (let o' = clientHelloExtension_CHE_pre_shared_key_set_binders o b' in
  let off = clientHelloExtension_CHE_pre_shared_key_binders_offset o in
  let tr = truncate_clientHelloExtension_CHE_pre_shared_key o in
  clientHelloExtension_CHE_pre_shared_key_binders_offset o' == off /\
  truncate_clientHelloExtension_CHE_pre_shared_key o' `Seq.equal` tr /\
  LP.serialize CHE.clientHelloExtension_CHE_pre_shared_key_serializer o' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let o' = clientHelloExtension_CHE_pre_shared_key_set_binders o b' in
  let off = clientHelloExtension_CHE_pre_shared_key_binders_offset o in
  serialize_clientHelloExtension_CHE_pre_shared_key_eq o;
  serialize_clientHelloExtension_CHE_pre_shared_key_eq o';
  binders_offset_offeredPsks_set_binders o b'

let truncate_clientHelloExtension_CHE_pre_shared_key_eq_left
  (o: CHE.clientHelloExtension_CHE_pre_shared_key)
: Lemma
  (truncate_clientHelloExtension_CHE_pre_shared_key o `Seq.equal` (LP.serialize (LI.serialize_bounded_integer 2) (U32.uint_to_t (Psks.offeredPsks_bytesize o)) `Seq.append` truncate_offeredPsks o))
= serialize_clientHelloExtension_CHE_pre_shared_key_eq o;
  truncate_offeredPsks_eq_left o

let truncate_clientHelloExtension_CHE_pre_shared_key_inj_binders_bytesize
  (o1 o2: CHE.clientHelloExtension_CHE_pre_shared_key)
: Lemma
  (requires (truncate_clientHelloExtension_CHE_pre_shared_key o1 == truncate_clientHelloExtension_CHE_pre_shared_key o2))
  (ensures (
    Psks.offeredPsks_binders_bytesize o1.Psks.binders == Psks.offeredPsks_binders_bytesize o2.Psks.binders
  ))
= truncate_clientHelloExtension_CHE_pre_shared_key_eq_left o1;
  truncate_clientHelloExtension_CHE_pre_shared_key_eq_left o2;
  LP.serialize_strong_prefix (LI.serialize_bounded_integer 2) (U32.uint_to_t (Psks.offeredPsks_bytesize o1)) (U32.uint_to_t (Psks.offeredPsks_bytesize o2)) (truncate_offeredPsks o1) (truncate_offeredPsks o2);
  assert (Seq.length (truncate_offeredPsks o1) == Seq.length (truncate_offeredPsks o2));  
  Psks.offeredPsks_identities_bytesize_eq o1.Psks.identities;
  Psks.offeredPsks_identities_bytesize_eq o2.Psks.identities

let clientHelloExtension_binders_offset
  (e: CHE.clientHelloExtension {CHE.CHE_pre_shared_key? e})
: Tot (x: U32.t { U32.v x < Seq.length (LP.serialize CHE.clientHelloExtension_serializer e) })
= CHE.clientHelloExtension_bytesize_eq e;
  CHE.serialize_clientHelloExtension_eq_pre_shared_key e;
  2ul `U32.add` clientHelloExtension_CHE_pre_shared_key_binders_offset (CHE.CHE_pre_shared_key?._0 e)

let truncate_clientHelloExtension
  (e: CHE.clientHelloExtension {CHE.CHE_pre_shared_key? e})
: GTot LP.bytes
= Seq.slice (LP.serialize CHE.clientHelloExtension_serializer e) 0 (U32.v (clientHelloExtension_binders_offset e))

let clientHelloExtension_set_binders
  (e: CHE.clientHelloExtension {CHE.CHE_pre_shared_key? e})
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 e).Psks.binders})
: Tot (e' : CHE.clientHelloExtension {
    CHE.CHE_pre_shared_key? e' /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.identities == (CHE.CHE_pre_shared_key?._0 e).Psks.identities /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.binders == b' /\
    CHE.clientHelloExtension_bytesize e' == CHE.clientHelloExtension_bytesize e
  })
= CHE.CHE_pre_shared_key (clientHelloExtension_CHE_pre_shared_key_set_binders (CHE.CHE_pre_shared_key?._0 e) b')

let binders_offset_clientHelloExtension_set_binders
  (e: CHE.clientHelloExtension {CHE.CHE_pre_shared_key? e})
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 e).Psks.binders})
: Lemma
  (let e' = clientHelloExtension_set_binders e b' in
  let off = clientHelloExtension_binders_offset e in
  let tr = truncate_clientHelloExtension e in
  clientHelloExtension_binders_offset e' == off /\
  truncate_clientHelloExtension e' `Seq.equal` tr /\
  LP.serialize CHE.clientHelloExtension_serializer e' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let e' = clientHelloExtension_set_binders e b' in
  let off = clientHelloExtension_binders_offset e in
  CHE.serialize_clientHelloExtension_eq_pre_shared_key e;
  CHE.serialize_clientHelloExtension_eq_pre_shared_key e';
  binders_offset_clientHelloExtension_CHE_pre_shared_key_set_binders (CHE.CHE_pre_shared_key?._0 e) b'

let truncate_clientHelloExtension_eq_left
  (e: CHE.clientHelloExtension { CHE.CHE_pre_shared_key? e })
: Lemma
  (truncate_clientHelloExtension e `Seq.equal` (LP.serialize ET.extensionType_serializer ET.Pre_shared_key `Seq.append` truncate_clientHelloExtension_CHE_pre_shared_key (CHE.CHE_pre_shared_key?._0 e)))
= CHE.serialize_clientHelloExtension_eq_pre_shared_key e

let truncate_clientHelloExtension_inj_binders_bytesize
  (e1: CHE.clientHelloExtension { CHE.CHE_pre_shared_key? e1 })
  (e2: CHE.clientHelloExtension { CHE.CHE_pre_shared_key? e2 })
: Lemma
  (requires (truncate_clientHelloExtension e1 == truncate_clientHelloExtension e2))
  (ensures (
    Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 e1).Psks.binders == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 e2).Psks.binders
  ))
= truncate_clientHelloExtension_eq_left e1;
  truncate_clientHelloExtension_eq_left e2;
  let CHE.CHE_pre_shared_key o1 = e1 in
  let CHE.CHE_pre_shared_key o2 = e2 in
  LP.serialize_strong_prefix ET.extensionType_serializer ET.Pre_shared_key ET.Pre_shared_key (truncate_clientHelloExtension_CHE_pre_shared_key o1) (truncate_clientHelloExtension_CHE_pre_shared_key o2);
  truncate_clientHelloExtension_CHE_pre_shared_key_inj_binders_bytesize o1 o2

let parse_truncate
  (#k: LP.parser_kind)
  (#t: Type)
  (#p: LP.parser k t)
  (s: LP.serializer p { k.LP.parser_kind_subkind == Some LP.ParserStrong })
  (x: t)
  (n: nat)
: Lemma
  (requires (
    n < Seq.length (LP.serialize s x)
  ))
  (ensures (
    LP.parse p (Seq.slice (LP.serialize s x) 0 n) == None
  ))
= let sq0 = LP.serialize s x in
  let sq1 = Seq.slice sq0 0 n in
  match LP.parse p sq1 with
  | None -> ()
  | Some (x', consumed) ->
    LP.parse_strong_prefix p sq1 sq0

let parse_truncate_clientHelloExtension
  (e: CHE.clientHelloExtension { CHE.CHE_pre_shared_key? e })
: Lemma
  (LP.parse CHE.clientHelloExtension_parser (truncate_clientHelloExtension e) == None)
= parse_truncate CHE.clientHelloExtension_serializer e (U32.v (clientHelloExtension_binders_offset e))

let rec clientHelloExtensions_list_bytesize_append
  (l1 l2: list CHE.clientHelloExtension)
: Lemma
  (CHEs.clientHelloExtensions_list_bytesize (l1 `L.append` l2) == CHEs.clientHelloExtensions_list_bytesize l1 + CHEs.clientHelloExtensions_list_bytesize l2)
= match l1 with
  | [] -> ()
  | _ :: q -> clientHelloExtensions_list_bytesize_append q l2

let list_clientHelloExtension_binders_offset
  (l: list CHE.clientHelloExtension {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l) /\
    CHEs.clientHelloExtensions_list_bytesize l <= 65535
  })
: Tot (x: U32.t { U32.v x <= Seq.length (serialize_list_clientHelloExtension l) })
= serialize_list_clientHelloExtension_eq l;
  clientHelloExtensions_list_bytesize_eq' l;
  size32_list_clientHelloExtension (L.init l) `U32.add` clientHelloExtension_binders_offset (L.last l)

let truncate_list_clientHelloExtension
  (l: list CHE.clientHelloExtension {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l) /\
    CHEs.clientHelloExtensions_list_bytesize l <= 65535
  })
: GTot LP.bytes
= Seq.slice (serialize_list_clientHelloExtension l) 0 (U32.v (list_clientHelloExtension_binders_offset l))

let list_clientHelloExtension_set_binders
  (l: list CHE.clientHelloExtension {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders {
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders
  })
: Tot (l' : list CHE.clientHelloExtension {
    Cons? l' /\ (
    let e = L.last l in
    let e' = L.last l' in
    L.init l' = L.init l /\
    CHE.CHE_pre_shared_key? e' /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.identities == (CHE.CHE_pre_shared_key?._0 e).Psks.identities /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.binders == b' /\
    CHEs.clientHelloExtensions_list_bytesize l' == CHEs.clientHelloExtensions_list_bytesize l
  )})
= L.append_init_last l;
  let lt = L.init l in
  let e = L.last l in
  let e' = clientHelloExtension_set_binders (L.last l) b' in
  let l' = lt `L.append` [e'] in
  L.init_last_def lt e' ;
  clientHelloExtensions_list_bytesize_append lt [e];
  clientHelloExtensions_list_bytesize_append lt [e'];
  l'

let binders_offset_list_clientHelloExtension_set_binders
  (l: list CHE.clientHelloExtension {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l) /\
    CHEs.clientHelloExtensions_list_bytesize l <= 65535
  })
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders})
: Lemma
  (
  let l' = list_clientHelloExtension_set_binders l b' in
  let off = list_clientHelloExtension_binders_offset l in
  let tr = truncate_list_clientHelloExtension l in
  list_clientHelloExtension_binders_offset l' == off /\
  truncate_list_clientHelloExtension l' `Seq.equal` tr /\
  serialize_list_clientHelloExtension l' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let l' = list_clientHelloExtension_set_binders l b' in
  let off = list_clientHelloExtension_binders_offset l in
  serialize_list_clientHelloExtension_eq l;
  serialize_list_clientHelloExtension_eq l';
  binders_offset_clientHelloExtension_set_binders (L.last l) b';
  clientHelloExtensions_list_bytesize_eq' l

let truncate_list_clientHelloExtension_eq_left
  (l: list CHE.clientHelloExtension {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l) /\
    CHEs.clientHelloExtensions_list_bytesize l <= 65535
  })
: Lemma
  (truncate_list_clientHelloExtension l `Seq.equal` (serialize_list_clientHelloExtension (L.init l) `Seq.append` truncate_clientHelloExtension (L.last l)))
= serialize_list_clientHelloExtension_eq l;
  clientHelloExtensions_list_bytesize_eq' l

let truncate_list_clientHelloExtension_inj_binders_bytesize
  (l1: list CHE.clientHelloExtension {
    Cons? l1 /\
    CHE.CHE_pre_shared_key? (L.last l1) /\
    CHEs.clientHelloExtensions_list_bytesize l1 <= 65535
  })
  (l2: list CHE.clientHelloExtension {
    Cons? l2 /\
    CHE.CHE_pre_shared_key? (L.last l2) /\
    CHEs.clientHelloExtensions_list_bytesize l2 <= 65535
  })
: Lemma
  (requires (truncate_list_clientHelloExtension l1 == truncate_list_clientHelloExtension l2))
  (ensures (
    Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l1)).Psks.binders == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l2)).Psks.binders
  ))
= truncate_list_clientHelloExtension_eq_left l1;
  truncate_list_clientHelloExtension_eq_left l2;
  parse_truncate_clientHelloExtension (L.last l1);
  parse_truncate_clientHelloExtension (L.last l2);
  serialize_list_clientHelloExtension_inj_prefix (L.init l1) (L.init l2) (truncate_clientHelloExtension (L.last l1)) (truncate_clientHelloExtension (L.last l2));
  truncate_clientHelloExtension_inj_binders_bytesize (L.last l1) (L.last l2)

let clientHelloExtensions_binders_offset
  (l: CHEs.clientHelloExtensions {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
: Tot (x: U32.t { U32.v x <= Seq.length (LP.serialize CHEs.clientHelloExtensions_serializer l) })
= serialize_clientHelloExtensions_eq l;
  clientHelloExtensions_list_bytesize_eq' l;
  2ul `U32.add` list_clientHelloExtension_binders_offset l

let truncate_clientHelloExtensions
  (l: CHEs.clientHelloExtensions {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
: GTot LP.bytes
= Seq.slice (LP.serialize CHEs.clientHelloExtensions_serializer l) 0 (U32.v (clientHelloExtensions_binders_offset l))

let clientHelloExtensions_set_binders
  (l: CHEs.clientHelloExtensions {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders {
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders
  })
: Tot (l' : CHEs.clientHelloExtensions {
    Cons? l' /\ (
    let e = L.last l in
    let e' = L.last l' in
    L.init l' = L.init l /\
    CHE.CHE_pre_shared_key? e' /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.identities == (CHE.CHE_pre_shared_key?._0 e).Psks.identities /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.binders == b' /\
    CHEs.clientHelloExtensions_bytesize l' == CHEs.clientHelloExtensions_bytesize l
  )})
= list_clientHelloExtension_set_binders l b'

let binders_offset_clientHelloExtensions_set_binders
  (l: CHEs.clientHelloExtensions {
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders})
: Lemma
  (let l' = clientHelloExtensions_set_binders l b' in
  let off = clientHelloExtensions_binders_offset l in
  let tr = truncate_clientHelloExtensions l in
  clientHelloExtensions_binders_offset l' == off /\
  truncate_clientHelloExtensions l' `Seq.equal` tr /\
  LP.serialize CHEs.clientHelloExtensions_serializer l' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let l' = clientHelloExtensions_set_binders l b' in
  serialize_clientHelloExtensions_eq l;
  serialize_clientHelloExtensions_eq l';
  binders_offset_list_clientHelloExtension_set_binders l b'

let clientHello_binders_offset
  (c: CH.clientHello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
: Tot (x: U32.t { U32.v x <= Seq.length (LP.serialize CH.clientHello_serializer c) })
= serialize_clientHello_eq c;
  Parsers.ProtocolVersion.protocolVersion_size32 c.CH.version `U32.add`
  Parsers.Random.random_size32 c.CH.random `U32.add`
  Parsers.SessionID.sessionID_size32 c.CH.session_id `U32.add`
  Parsers.ClientHello_cipher_suites.clientHello_cipher_suites_size32 c.CH.cipher_suites `U32.add` Parsers.ClientHello_compression_method.clientHello_compression_method_size32 c.CH.compression_method `U32.add`
  clientHelloExtensions_binders_offset c.CH.extensions

let truncate_clientHello
  (c: CH.clientHello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
: GTot LP.bytes
= Seq.slice (LP.serialize CH.clientHello_serializer c) 0 (U32.v (clientHello_binders_offset c))

let clientHello_set_binders
  (c: CH.clientHello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders {
    let l = c.CH.extensions in
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders
  })
: Tot (c' : CH.clientHello {
    let l' = c'.CH.extensions in
    c'.CH.version == c.CH.version /\
    c'.CH.random == c.CH.random /\
    c'.CH.session_id == c.CH.session_id /\
    c'.CH.cipher_suites == c.CH.cipher_suites /\
    c'.CH.compression_method == c.CH.compression_method /\
    Cons? l' /\ (
    let l = c.CH.extensions in
    let e = L.last l in
    let e' = L.last l' in
    L.init l' = L.init l /\
    CHE.CHE_pre_shared_key? e' /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.identities == (CHE.CHE_pre_shared_key?._0 e).Psks.identities /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.binders == b' /\
    CH.clientHello_bytesize c' == CH.clientHello_bytesize c
  )})
= {
    CH.version = c.CH.version;
    CH.random = c.CH.random;
    CH.session_id = c.CH.session_id;
    CH.cipher_suites = c.CH.cipher_suites;
    CH.compression_method = c.CH.compression_method;
    CH.extensions = clientHelloExtensions_set_binders c.CH.extensions b'
  }

let binders_offset_clientHello_set_binders
  (c: CH.clientHello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders {
    let l = c.CH.extensions in
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders})
: Lemma
  (let c' = clientHello_set_binders c b' in
  let off = clientHello_binders_offset c in
  let tr = truncate_clientHello c in
  clientHello_binders_offset c' == off /\
  truncate_clientHello c' `Seq.equal` tr /\
  LP.serialize CH.clientHello_serializer c' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let c' = clientHello_set_binders c b' in
  serialize_clientHello_eq c;
  serialize_clientHello_eq c';
  binders_offset_clientHelloExtensions_set_binders c.CH.extensions b'

let handshake_m_client_hello_binders_offset
  (c: H.handshake_m_client_hello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
: Tot (x: U32.t { U32.v x <= Seq.length (LP.serialize H.handshake_m_client_hello_serializer c) })
= serialize_handshake_m_client_hello_eq c;
  3ul `U32.add` clientHello_binders_offset c

let truncate_handshake_m_client_hello
  (c: H.handshake_m_client_hello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
: GTot LP.bytes
= Seq.slice (LP.serialize H.handshake_m_client_hello_serializer c) 0 (U32.v (handshake_m_client_hello_binders_offset c))

let handshake_m_client_hello_set_binders
  (c: H.handshake_m_client_hello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders {
    let l = c.CH.extensions in
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders
  })
: Tot (c' : H.handshake_m_client_hello {
    let l' = c'.CH.extensions in
    c'.CH.version == c.CH.version /\
    c'.CH.random == c.CH.random /\
    c'.CH.session_id == c.CH.session_id /\
    c'.CH.cipher_suites == c.CH.cipher_suites /\
    c'.CH.compression_method == c.CH.compression_method /\
    Cons? l' /\ (
    let l = c.CH.extensions in
    let e = L.last l in
    let e' = L.last l' in
    L.init l' = L.init l /\
    CHE.CHE_pre_shared_key? e' /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.identities == (CHE.CHE_pre_shared_key?._0 e).Psks.identities /\
    (CHE.CHE_pre_shared_key?._0 e').Psks.binders == b' /\
    H.handshake_m_client_hello_bytesize c' == H.handshake_m_client_hello_bytesize c
  )})
= clientHello_set_binders c b'

#push-options "--z3rlimit 16"

let binders_offset_handshake_m_client_hello_set_binders
  (c: H.handshake_m_client_hello {
    let l = c.CH.extensions in
    Cons? l /\
    CHE.CHE_pre_shared_key? (L.last l)
  })
  (b' : Psks.offeredPsks_binders {
    let l = c.CH.extensions in
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (CHE.CHE_pre_shared_key?._0 (L.last l)).Psks.binders})
: Lemma
  (let c' = handshake_m_client_hello_set_binders c b' in
  let off = handshake_m_client_hello_binders_offset c in
  let tr = truncate_handshake_m_client_hello c in
  handshake_m_client_hello_binders_offset c' == off /\
  truncate_handshake_m_client_hello c' `Seq.equal` tr /\
  LP.serialize H.handshake_m_client_hello_serializer c' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let c' = handshake_m_client_hello_set_binders c b' in
  serialize_handshake_m_client_hello_eq c;
  serialize_handshake_m_client_hello_eq c';
  binders_offset_clientHello_set_binders c b'

#pop-options

let set_binders m b' =
  let c = H.M_client_hello?._0 m in
  H.M_client_hello (handshake_m_client_hello_set_binders c b')

let set_binders_bytesize m b' = ()

let binders_offset h =
  H.handshake_bytesize_eq h;
  H.serialize_handshake_eq_client_hello h;
  1ul `U32.add` handshake_m_client_hello_binders_offset (H.M_client_hello?._0 h)

let truncate_handshake
  (h: H.handshake {has_binders h})
: GTot LP.bytes
= Seq.slice (LP.serialize H.handshake_serializer h) 0 (U32.v (binders_offset h))

#push-options "--z3rlimit 16"

let binders_offset_handshake_set_binders
  (h: H.handshake {has_binders h})
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders h)})
: Lemma
  (let h' = set_binders h b' in
  let off = binders_offset h in
  let tr = truncate_handshake h in
  binders_offset h' == off /\
  truncate_handshake h' `Seq.equal` tr /\
  LP.serialize H.handshake_serializer h' `Seq.equal`
  (tr `Seq.append` LP.serialize Psks.offeredPsks_binders_serializer b'))
= let h' = set_binders h b' in
  let off = binders_offset h in
  H.serialize_handshake_eq_client_hello h;
  H.serialize_handshake_eq_client_hello h';
  binders_offset_handshake_m_client_hello_set_binders (H.M_client_hello?._0 h) b'

#pop-options

let binders_offset_set_binder m b' = binders_offset_handshake_set_binders m b'

let truncate_clientHello_bytes_correct m =
  set_binders_get_binders m;
  binders_offset_handshake_set_binders m (get_binders m)

let truncate_clientHello_bytes_set_binders m b' = binders_offset_handshake_set_binders m b'

#set-options "--z3rlimit 16"

let truncate_clientHello_bytes_inj_binders_bytesize m1 m2 = admit ()

let binders_pos #rrel #rel sl pos = admit ()