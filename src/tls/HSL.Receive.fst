(*
  Copyright 2015--2019 INRIA and Microsoft Corporation

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Authors: T. Ramananandro, A. Rastogi, N. Swamy
*)
module HSL.Receive

open FStar.Integers
open FStar.HyperStack.ST

module G = FStar.Ghost
module List = FStar.List.Tot

module HS = FStar.HyperStack
module ST = FStar.HyperStack.ST
module B = LowStar.Buffer

module LP = LowParse.Low.Base

module E = FStar.Error

module HSM13 = Parsers.Handshake13
module HSM12 = Parsers.Handshake12
module HSM   = Parsers.Handshake

module HSMType = Parsers.HandshakeType
module R = MITLS.Repr

module HSM13R = MITLS.Repr.Handshake13
module HSM12R = MITLS.Repr.Handshake12
module HSMR   = MITLS.Repr.Handshake

open HSL.Common

#reset-options "--max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Tactics -FStar.Reflection'"

type inc_st_t = G.erased (bytes & in_progress_flt_t)

noeq
type hsl_state = {
  rgn: Mem.rgn;
  inc_st: (p:B.pointer inc_st_t{
    rgn `region_includes` B.loc_buffer p
  });
}

let region_of st = st.rgn

let parsed_bytes st h = fst (G.reveal (B.deref h st.inc_st))

let in_progress_flt st h = snd (G.reveal (B.deref h st.inc_st))

let invariant s h = B.live h s.inc_st

let footprint s = B.loc_buffer s.inc_st

let frame_hsl_state _ _ _ _ = ()

let create r =
  let inc_st = B.malloc r (G.hide (Seq.empty, F_none)) 1ul in
  { rgn = r; inc_st = inc_st }

assume val parsing_error : TLSError.error
assume val unexpected_flight_error : TLSError.error
assume val bytes_remain_error : TLSError.error

inline_for_extraction
noextract
let parse_hsm13
  (#a:Type) (#k:R.strong_parser_kind)
  (#p:LP.parser k a) (#cl:LP.clens HSM13.handshake13 a)
  (#gacc:LP.gaccessor HSM13.handshake13_parser p cl)
  (tag:HSMType.handshakeType{
    forall (m:HSM13.handshake13).
      (HSM13.tag_of_handshake13 m == tag) <==> cl.LP.clens_cond m})
  (acc:LP.accessor gacc)
  : b:R.slice -> from:uint_32 ->
    Stack (TLSError.result (option (HSM13R.repr b & uint_32)))
    (requires fun h ->
      B.live h b.LP.base /\
      from <= b.LP.len)
    (ensures fun h0 r h1 ->
      B.modifies B.loc_none h0 h1 /\
      (match r with
       | E.Error _ -> True
       | E.Correct None -> True
       | E.Correct (Some (repr, pos)) ->
         repr.R.start_pos == from /\
         repr.R.end_pos == pos /\
         R.valid repr h1 /\
         cl.LP.clens_cond (R.value repr)))
         
  = fun b from ->
    
    let pos = HSM13.handshake13_validator b from in

    if pos <= LP.validator_max_length then begin
      let parsed_tag = HSMType.handshakeType_reader b from in
      if parsed_tag = tag then
        let r = R.mk b from pos HSM13.handshake13_parser in
        E.Correct (Some (r, pos))
      else E.Error unexpected_flight_error
    end
    else if pos = LP.validator_error_not_enough_data then E.Correct None
    else E.Error parsing_error

let reset_incremental_state (st:hsl_state)
  : Stack unit
    (requires fun h -> B.live h st.inc_st)
    (ensures fun h0 _ h1 ->
      B.modifies (footprint st) h0 h1 /\
      parsed_bytes st h1 == Seq.empty /\
      in_progress_flt st h1 == F_none)
  =  let inc_st = G.hide (Seq.empty, F_none) in
     B.upd st.inc_st 0ul inc_st

let err_or_insufficient_data
  (#a:Type) (#t:Type)
  (parse_result:TLSError.result (option a))
  (in_progress:in_progress_flt_t)
  (st:hsl_state) (b:R.slice) (from to:uint_32)
  : Stack (TLSError.result (option t))
    (requires fun h ->
      B.live h st.inc_st /\ B.live h b.LP.base /\
      B.loc_disjoint (footprint st) (B.loc_buffer b.LP.base) /\
      from <= to /\ to <= b.LP.len /\
      (E.Error? parse_result \/ parse_result == E.Correct None))
    (ensures  fun h0 r h1 ->
      B.modifies (footprint st) h0 h1 /\
      (match parse_result with
       | E.Error e -> r == E.Error e
       | E.Correct None ->
         r == E.Correct None /\
         parsed_bytes st h1 ==
           Seq.slice (B.as_seq h0 b.LP.base) (v from) (v to) /\
         in_progress_flt st h1 == in_progress))
  = match parse_result with
    | E.Error e -> E.Error e
    | E.Correct None ->
      let inc_st =
        let h = ST.get () in
        let parsed_bytes = LP.bytes_of_slice_from_to h b from to in
        G.hide (parsed_bytes, in_progress)
      in
      B.upd st.inc_st 0ul inc_st;
      E.Correct None

let parse_hsm13_ee
  =  parse_hsm13
      HSMType.Encrypted_extensions
      HSM13.handshake13_accessor_encrypted_extensions
      
let parse_hsm13_c
  = parse_hsm13
      HSMType.Certificate
      HSM13.handshake13_accessor_certificate

let parse_hsm13_cv
  = parse_hsm13
      HSMType.Certificate_verify
      HSM13.handshake13_accessor_certificate_verify

let parse_hsm13_fin
  = parse_hsm13 
      HSMType.Finished
      HSM13.handshake13_accessor_finished

let parse_hsm13_cr
  = parse_hsm13 
      HSMType.Certificate_request
      HSM13.handshake13_accessor_certificate_request

let parse_hsm13_eoed
  = parse_hsm13 
      HSMType.End_of_early_data
      HSM13.handshake13_accessor_end_of_early_data

let parse_hsm13_nst
  = parse_hsm13 
      HSMType.New_session_ticket
      HSM13.handshake13_accessor_new_session_ticket

let receive_flight13_ee_c_cv_fin st b from to =
  let r = parse_hsm13_ee b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_ee_c_cv_fin st b from to
  | E.Correct (Some (ee_repr, c_begin)) ->
    let r = parse_hsm13_c b c_begin in
    match r with
    | E.Error _ | E.Correct None ->
      err_or_insufficient_data r F13_ee_c_cv_fin st b from to
    | E.Correct (Some (c_repr, cv_begin)) ->
      let r = parse_hsm13_cv b cv_begin in
      match r with
      | E.Error _ | E.Correct None ->
        err_or_insufficient_data r F13_ee_c_cv_fin st b from to
      | E.Correct (Some (cv_repr, fin_begin)) ->
        let r = parse_hsm13_fin b fin_begin in
        match r with
        | E.Error _ | E.Correct None ->
          err_or_insufficient_data r F13_ee_c_cv_fin st b from to
        | E.Correct (Some (fin_repr, pos)) ->
          if pos <> to then E.Error bytes_remain_error
          else begin
            reset_incremental_state st;
            E.Correct (Some ({
              ee_msg = ee_repr;
              c_msg = c_repr;
              cv_msg = cv_repr;
              fin_msg = fin_repr
            }))
          end

let receive_flight13_ee_cr_c_cv_fin st b from to =
  let r = parse_hsm13_ee b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_ee_cr_c_cv_fin st b from to
  | E.Correct (Some (ee_repr, cr_begin)) ->
    let r = parse_hsm13_cr b cr_begin in
    match r with
    | E.Error _ | E.Correct None ->
      err_or_insufficient_data r F13_ee_cr_c_cv_fin st b from to
    | E.Correct (Some (cr_repr, c_begin)) ->
      let r = parse_hsm13_c b c_begin in
      match r with
      | E.Error _ | E.Correct None ->
        err_or_insufficient_data r F13_ee_cr_c_cv_fin st b from to
      | E.Correct (Some (c_repr, cv_begin)) ->
        let r = parse_hsm13_cv b cv_begin in
        match r with
        | E.Error _ | E.Correct None ->
          err_or_insufficient_data r F13_ee_cr_c_cv_fin st b from to
        | E.Correct (Some (cv_repr, fin_begin)) ->
          let r = parse_hsm13_fin b fin_begin in
          match r with
          | E.Error _ | E.Correct None ->
            err_or_insufficient_data r F13_ee_cr_c_cv_fin st b from to
          | E.Correct (Some (fin_repr, pos)) ->
            if pos <> to then E.Error bytes_remain_error
            else begin
              reset_incremental_state st;
              E.Correct (Some ({
                ee_msg = ee_repr;
                cr_msg = cr_repr;
                c_msg = c_repr;
                cv_msg = cv_repr;
                fin_msg = fin_repr
              }))
            end

let receive_flight13_ee_fin st b from to =
  let r = parse_hsm13_ee b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_ee_fin st b from to
  | E.Correct (Some (ee_repr, fin_begin)) ->
    let r = parse_hsm13_fin b fin_begin in
    match r with
    | E.Error _ | E.Correct None ->
      err_or_insufficient_data r F13_ee_fin st b from to
    | E.Correct (Some (fin_repr, pos)) ->
      if pos <> to then E.Error bytes_remain_error
      else begin
        reset_incremental_state st;
        E.Correct (Some ({
          ee_msg = ee_repr;
          fin_msg = fin_repr
        }))
      end

let receive_flight13_fin st b from to =
  let r = parse_hsm13_fin b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_fin st b from to
  | E.Correct (Some (fin_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ fin_msg = fin_repr }))
    end

let receive_flight13_c_cv_fin st b from to =
  let r = parse_hsm13_c b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_c_cv_fin st b from to
  | E.Correct (Some (c_repr, cv_begin)) ->
    let r = parse_hsm13_cv b cv_begin in
    match r with
    | E.Error _ | E.Correct None ->
      err_or_insufficient_data r F13_c_cv_fin st b from to
    | E.Correct (Some (cv_repr, fin_begin)) ->
      let r = parse_hsm13_fin b fin_begin in
      match r with
      | E.Error _ | E.Correct None ->
        err_or_insufficient_data r F13_c_cv_fin st b from to
      | E.Correct (Some (fin_repr, pos)) ->
        if pos <> to then E.Error bytes_remain_error
        else begin
          reset_incremental_state st;
          E.Correct (Some ({
            c_msg = c_repr;
            cv_msg = cv_repr;
            fin_msg = fin_repr }))
        end

let receive_flight13_eoed st b from to =
  let r = parse_hsm13_eoed b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_eoed st b from to
  | E.Correct (Some (eoed_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ eoed_msg = eoed_repr }))
    end

let receive_flight13_nst st b from to =
  let r = parse_hsm13_nst b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F13_nst st b from to
  | E.Correct (Some (nst_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ nst_msg = nst_repr }))
    end


inline_for_extraction
noextract
let parse_hsm12
  (#a:Type) (#k:R.strong_parser_kind)
  (#p:LP.parser k a) (#cl:LP.clens HSM12.handshake12 a)
  (#gacc:LP.gaccessor HSM12.handshake12_parser p cl)
  (tag:HSMType.handshakeType{
    forall (m:HSM12.handshake12).
      (HSM12.tag_of_handshake12 m == tag) <==> cl.LP.clens_cond m})
  (acc:LP.accessor gacc)
  : b:R.slice -> from:uint_32 ->
    Stack (TLSError.result (option (HSM12R.repr b & uint_32)))
    (requires fun h ->
      B.live h b.LP.base /\
      from <= b.LP.len)
    (ensures fun h0 r h1 ->
      B.modifies B.loc_none h0 h1 /\
      (match r with
       | E.Error _ -> True
       | E.Correct None -> True
       | E.Correct (Some (repr, pos)) ->
         repr.R.start_pos == from /\
         repr.R.end_pos == pos /\
         R.valid repr h1 /\
         cl.LP.clens_cond (R.value repr)))
         
  = fun b from ->
    
    let pos = HSM12.handshake12_validator b from in

    if pos <= LP.validator_max_length then begin
      let parsed_tag = HSMType.handshakeType_reader b from in
      if parsed_tag = tag then
        let r = R.mk b from pos HSM12.handshake12_parser in
        E.Correct (Some (r, pos))
      else E.Error unexpected_flight_error
    end
    else if pos = LP.validator_error_not_enough_data then E.Correct None
    else E.Error parsing_error

let parse_hsm12_c
  =  parse_hsm12
      HSMType.Certificate
      HSM12.handshake12_accessor_certificate

let parse_hsm12_ske
  = parse_hsm12
      HSMType.Server_key_exchange
      HSM12.handshake12_accessor_server_key_exchange

let parse_hsm12_shd
  = parse_hsm12
      HSMType.Server_hello_done
      HSM12.handshake12_accessor_server_hello_done

let parse_hsm12_cr
  =  parse_hsm12
      HSMType.Certificate_request
      HSM12.handshake12_accessor_certificate_request

let parse_hsm12_fin
  =  parse_hsm12
      HSMType.Finished
      HSM12.handshake12_accessor_finished

let parse_hsm12_nst
  =  parse_hsm12
      HSMType.New_session_ticket
      HSM12.handshake12_accessor_new_session_ticket

let parse_hsm12_cke
  =  parse_hsm12
      HSMType.Client_key_exchange
      HSM12.handshake12_accessor_client_key_exchange

let receive_flight12_c_ske_shd st b from to =
  let r = parse_hsm12_c b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F12_c_ske_shd st b from to
  | E.Correct (Some (c_repr, ske_begin)) ->
    let r = parse_hsm12_ske b ske_begin in
    match r with
    | E.Error _ | E.Correct None ->
      err_or_insufficient_data r F12_c_ske_shd st b from to
    | E.Correct (Some (ske_repr, shd_begin)) ->
      let r = parse_hsm12_shd b shd_begin in
      match r with
      | E.Error _ | E.Correct None ->
        err_or_insufficient_data r F12_c_ske_shd st b from to
      | E.Correct (Some (shd_repr, pos)) ->
        if pos <> to then E.Error bytes_remain_error
        else begin
          reset_incremental_state st;
          E.Correct (Some ({
            c_msg = c_repr;
            ske_msg = ske_repr;
            shd_msg = shd_repr }))
        end

let receive_flight12_c_ske_cr_shd st b from to =
  let r = parse_hsm12_c b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F12_c_ske_cr_shd st b from to
  | E.Correct (Some (c_repr, ske_begin)) ->
    let r = parse_hsm12_ske b ske_begin in
    match r with
    | E.Error _ | E.Correct None ->
      err_or_insufficient_data r F12_c_ske_cr_shd st b from to
    | E.Correct (Some (ske_repr, cr_begin)) ->
      let r = parse_hsm12_cr b cr_begin in
      match r with
      | E.Error _ | E.Correct None ->
        err_or_insufficient_data r F12_c_ske_cr_shd st b from to
      | E.Correct (Some (cr_repr, shd_begin)) ->
        let r = parse_hsm12_shd b shd_begin in
        match r with
        | E.Error _ | E.Correct None ->
          err_or_insufficient_data r F12_c_ske_cr_shd st b from to
        | E.Correct (Some (shd_repr, pos)) ->
          if pos <> to then E.Error bytes_remain_error
          else begin
            reset_incremental_state st;
            E.Correct (Some ({
              c_msg = c_repr;
              ske_msg = ske_repr;
              cr_msg = cr_repr;
              shd_msg = shd_repr
            }))
          end

let receive_flight12_fin st b from to =
  let r = parse_hsm12_fin b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F12_fin st b from to
  | E.Correct (Some (fin_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ fin_msg = fin_repr }))
    end

let receive_flight12_nst st b from to =
  let r = parse_hsm12_nst b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F12_nst st b from to
  | E.Correct (Some (nst_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ nst_msg = nst_repr }))
    end

let receive_flight12_cke st b from to =
  let r = parse_hsm12_cke b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F12_cke st b from to
  | E.Correct (Some (cke_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ cke_msg = cke_repr }))
    end


inline_for_extraction
noextract
let parse_hsm
  (#a:Type) (#k:R.strong_parser_kind)
  (#p:LP.parser k a) (#cl:LP.clens HSM.handshake a)
  (#gacc:LP.gaccessor HSM.handshake_parser p cl)
  (tag:HSMType.handshakeType{
    forall (m:HSM.handshake).
      (HSM.tag_of_handshake m == tag) <==> cl.LP.clens_cond m})
  (acc:LP.accessor gacc)
  : b:R.slice -> from:uint_32 ->
    Stack (TLSError.result (option (HSMR.repr b & uint_32)))
    (requires fun h ->
      B.live h b.LP.base /\
      from <= b.LP.len)
    (ensures fun h0 r h1 ->
      B.modifies B.loc_none h0 h1 /\
      (match r with
       | E.Error _ -> True
       | E.Correct None -> True
       | E.Correct (Some (repr, pos)) ->
         repr.R.start_pos == from /\
         repr.R.end_pos == pos /\
         R.valid repr h1 /\
         cl.LP.clens_cond (R.value repr)))
         
  = fun b from ->
    
    let pos = HSM.handshake_validator b from in

    if pos <= LP.validator_max_length then begin
      let parsed_tag = HSMType.handshakeType_reader b from in
      if parsed_tag = tag then
        let r = R.mk b from pos HSM.handshake_parser in
        E.Correct (Some (r, pos))
      else E.Error unexpected_flight_error
    end
    else if pos = LP.validator_error_not_enough_data then E.Correct None
    else E.Error parsing_error

let parse_hsm_ch
  =  parse_hsm
      HSMType.Client_hello
      HSM.handshake_accessor_client_hello

let parse_hsm_sh
  = parse_hsm
      HSMType.Server_hello
      HSM.handshake_accessor_server_hello


let receive_flight_ch st b from to =
  let r = parse_hsm_ch b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F_ch st b from to
  | E.Correct (Some (ch_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ ch_msg = ch_repr }))
    end

let receive_flight_sh st b from to =
  let r = parse_hsm_sh b from in
  match r with
  | E.Error _ | E.Correct None ->
    err_or_insufficient_data r F_sh st b from to
  | E.Correct (Some (sh_repr, pos)) ->
    if pos <> to then E.Error bytes_remain_error
    else begin
      reset_incremental_state st;
      E.Correct (Some ({ sh_msg = sh_repr }))
    end


