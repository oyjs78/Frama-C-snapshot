(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2012                                               *)
(*    CEA (Commissariat � l'�nergie atomique et aux �nergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Locations
open Eval_exprs

(** Main function of the value plugin for the kernel *)

let display_results () =
  if Db.Value.is_computed () && Value_parameters.verbose_atleast 1 then begin
    Value_parameters.result "====== VALUES COMPUTED ======";
    (* Val display and Inout compute/display *)
    !Db.Semantic_Callgraph.topologically_iter_on_functions
      (fun kf ->
         if Kernel_function.is_definition kf then
           begin
             Value_parameters.result "%a" Db.Value.display kf ;
           end)
  end

let () = Value_parameters.ForceValues.set_output_dependencies [Db.Value.self]

let main () =
  (* Value computations *)
  if Value_parameters.ForceValues.get () then begin
    !Db.Value.compute ();
    Value_parameters.ForceValues.output display_results;
  end

let () = Db.Main.extend main


(** Functions to register in Db.Value *)

let lval_to_loc_with_deps_state ~with_alarms state ~deps lv =
  let _state, deps, r =
    lval_to_loc_with_deps
      ~with_alarms
      ~deps
      ~reduce_valid_index:(Kernel.SafeArrays.get ())
      state
      lv
  in
  Zone.out_some_or_bottom deps, r

let lval_to_loc_with_deps kinstr ~with_alarms ~deps lv =
  CilE.start_stmt kinstr;
  let state = Db.Value.noassert_get_state kinstr in
  let result =
    lval_to_loc_with_deps_state ~with_alarms  state ~deps lv in
  CilE.end_stmt ();
  result

let lval_to_loc_kinstr kinstr ~with_alarms lv =
  CilE.start_stmt kinstr;
  let state = Db.Value.noassert_get_state kinstr in
  (*    Format.printf "@\ngot state when lval_to_loc:%a@."
        Cvalue.Model.pretty state; *)
  let r = lval_to_loc ~with_alarms state lv in
  CilE.end_stmt ();
  r

let lval_to_zone kinstr ~with_alarms lv =
  Locations.valid_enumerate_bits
    ~for_writing:false
    (lval_to_loc_kinstr ~with_alarms kinstr lv)

let lval_to_zone_state state lv =
  Locations.valid_enumerate_bits
    ~for_writing:false
    (lval_to_loc ~with_alarms:CilE.warn_none_mode state lv)

let expr_to_kernel_function_state ~with_alarms state ~deps exp =
  let r, deps = resolv_func_vinfo ~with_alarms deps state exp in
  Zone.out_some_or_bottom deps, r

let expr_to_kernel_function kinstr ~with_alarms ~deps exp =
  CilE.start_stmt kinstr;
  let state = Db.Value.noassert_get_state kinstr in
  (* Format.printf "STATE IS %a@\n" Cvalue.Model.pretty state;*)
  let r =
    expr_to_kernel_function_state  ~with_alarms state ~deps exp
  in
  CilE.end_stmt ();
  r

let expr_to_kernel_function_state =
  expr_to_kernel_function_state ~with_alarms:CilE.warn_none_mode

let eval_error_reason fmt e =
  if e <> Eval_terms.CAlarm
  then Eval_terms.pretty_logic_evaluation_error fmt e

let assigns_inputs_to_zone state assigns =
  let env = Eval_terms.env_pre_f state in
  let treat_asgn acc (_,ins as asgn) =
    match ins with
      | FromAny -> Zone.top
      | From l ->
        try
          List.fold_left
            (fun acc t ->
              let z = Eval_terms.eval_tlval_as_zone
                ~with_alarms:Eval_terms.warn_raise_mode
                ~for_writing:false env None t.it_content in
              Zone.join acc z)
            acc
            l
        with Eval_terms.LogicEvalError e ->
          Value_parameters.warning ~current:true ~once:true
            "Failed to interpret inputs in assigns clause '%a'%a"
            Cil.d_from asgn eval_error_reason e;
          Zone.top
  in
  match assigns with
    | WritesAny -> Zone.top
    | Writes l  -> List.fold_left treat_asgn Zone.bottom l

let assigns_outputs_aux ~eval ~bot ~top ~join state ~result assigns =
  let env = Eval_terms.env_pre_f state in
  let treat_asgn acc ({it_content = out},_) =
    if Logic_utils.is_result out && result = None
    then acc
    else
      try
        let z = eval env result out in
        join z acc
      with Eval_terms.LogicEvalError e ->
        Value_parameters.warning ~current:true ~once:true
          "Failed to interpret assigns clause '%a'%a"
          Cil.d_term out eval_error_reason e;
        join top acc
  in
  match assigns with
    | WritesAny -> join top bot
    | Writes l  -> List.fold_left treat_asgn bot l

let assigns_outputs_to_zone =
  assigns_outputs_aux
    ~eval:(Eval_terms.eval_tlval_as_zone
             ~with_alarms:Eval_terms.warn_raise_mode ~for_writing:true)
    ~bot:Locations.Zone.bottom ~top:Locations.Zone.top ~join:Locations.Zone.join

let assigns_outputs_to_locations =
  assigns_outputs_aux
    ~eval:(Eval_terms.eval_tlval_as_location
             ~with_alarms:Eval_terms.warn_raise_mode)
    ~bot:[] ~top:(Locations.make_loc Locations.Location_Bits.top Int_Base.top)
    ~join:(fun v l -> v :: l)


let lval_to_offsetmap kinstr lv ~with_alarms =
  CilE.start_stmt kinstr;
  let state = Db.Value.noassert_get_state kinstr in
  let loc = Locations.valid_part ~for_writing:false
    (lval_to_loc ~with_alarms state lv)
  in
  let offsetmap =
    Cvalue.Model.copy_offsetmap ~with_alarms loc state
  in
  CilE.end_stmt ();
  offsetmap

let lval_to_offsetmap_state state lv =
  let with_alarms = CilE.warn_none_mode in
  let loc =
    Locations.valid_part ~for_writing:false
      (lval_to_loc ~with_alarms state lv)
  in
  Cvalue.Model.copy_offsetmap ~with_alarms loc state


(* If the function is a builtin, or if the user has requested it, use
   \assigns and \from clauses, that give an approximation of the result *)
let use_spec_instead_of_definition kf =
  not (Kernel_function.is_definition kf) ||
    (let name = Kernel_function.get_name kf in
     Builtins.overridden_by_builtin name ||
     Datatype.String.Set.mem name (Value_parameters.UsePrototype.get ())
    )

let () =
  Db.Value.use_spec_instead_of_definition := use_spec_instead_of_definition;
  Db.Value.lval_to_loc_with_deps := lval_to_loc_with_deps;
  Db.Value.lval_to_loc_with_deps_state :=
    lval_to_loc_with_deps_state ~with_alarms:CilE.warn_none_mode;
  Db.Value.expr_to_kernel_function := expr_to_kernel_function;
  Db.Value.expr_to_kernel_function_state := expr_to_kernel_function_state;
  Db.Value.lval_to_loc := lval_to_loc_kinstr;
  Db.Value.lval_to_loc_state := lval_to_loc ~with_alarms:CilE.warn_none_mode ;
  Db.Value.lval_to_zone_state := lval_to_zone_state;
  Db.Value.lval_to_zone := lval_to_zone;
  Db.Value.lval_to_offsetmap := lval_to_offsetmap;
  Db.Value.lval_to_offsetmap_state := lval_to_offsetmap_state;
  Db.Value.assigns_outputs_to_zone := assigns_outputs_to_zone;
  Db.Value.assigns_outputs_to_locations := assigns_outputs_to_locations;
  Db.Value.assigns_inputs_to_zone := assigns_inputs_to_zone;
  Db.Value.eval_expr := eval_expr;
  Db.Value.eval_expr_with_state :=
    (fun ~with_alarms state expr ->
      let (s,_,v) = eval_expr_with_deps_state ~with_alarms None state expr in
      s,v);
  Db.Value.eval_lval :=
    (fun ~with_alarms deps state lval ->
      let _, deps, r = eval_lval ~conflate_bottom:true ~with_alarms deps state lval in
      deps, r);
  Db.Value.find_lv_plus :=
    (fun ~with_alarms state e ->
      try [find_lv_plus_offset ~with_alarms state e]
      with Cannot_find_lv -> []);
;;


(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
