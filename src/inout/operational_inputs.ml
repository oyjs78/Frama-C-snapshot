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
open Db
open Locations

(* Computation of over-approximed operational inputs:
   An acurate computation of these inputs needs the computation of
   under-approximed outputs.
*)

type tt = Inout_type.tt = {
  over_inputs: Locations.Zone.t;
  over_inputs_if_termination: Locations.Zone.t;
  under_outputs_if_termination: Locations.Zone.t;
  over_outputs: Locations.Zone.t;
  over_outputs_if_termination: Locations.Zone.t;
}

let top = {
  over_inputs = Zone.top;
  over_inputs_if_termination = Zone.top;
  under_outputs_if_termination = Zone.bottom;
  over_outputs = Zone.top;
  over_outputs_if_termination = Zone.top;
}

(* [_if_termination] fields of the type above, which are the one propagated by
   the dataflow analysis of this module. It is meaningless to store the other
   ones, as they come from branches that are by construction not propagated
   until the end by the dataflow. *)
type compute_t = {
  over_inputs_d : Zone.t ;
  under_outputs_d : Zone.t;
  over_outputs_d: Zone.t;
}

(* Initial value for the computation *)
let empty = {
  over_inputs_d = Zone.bottom;
  under_outputs_d = Zone.bottom;
  over_outputs_d = Zone.bottom;
}

let bottom = {
  over_inputs_d = Zone.bottom;
  under_outputs_d = Zone.top;
  over_outputs_d = Zone.bottom;
}

let join c1 c2 = {
  over_inputs_d = Zone.join c1.over_inputs_d c2.over_inputs_d;
  under_outputs_d = Zone.meet c1.under_outputs_d c2.under_outputs_d;
  over_outputs_d = Zone.join c1.over_outputs_d c2.over_outputs_d;
}

let is_included c1 c2 =
  Zone.is_included c1.over_inputs_d   c2.over_inputs_d &&
  Zone.is_included c2.under_outputs_d c1.under_outputs_d &&
  Zone.is_included c1.over_outputs_d  c2.over_outputs_d

let catenate c1 c2 = {
  over_inputs_d =
    Zone.join c1.over_inputs_d (Zone.diff c2.over_inputs_d c1.under_outputs_d);
  under_outputs_d = Zone.link c1.under_outputs_d c2.under_outputs_d;
  over_outputs_d = Zone.join  c1.over_outputs_d c2.over_outputs_d;
}


let externalize_zone ~with_formals kf =
  Zone.filter_base
    (Value_aux.accept_base ~with_formals ~with_locals:false kf)

(* This code evaluates an assigns, computing in particular a sound approximation
   of sure outputs. For an assigns [locs_out \from locs_from], the process
   is the following:
   - evaluate locs_out to locations; discard those that are not exact, as
     we cannot guarantee that they are always assigned
   - evaluate locs_from, as a zone (no need for locations)
   - compute the difference between the out and the froms, ie remove the
     zones that are such that [z \from z] holds

   (Note: large parts of this code are inspired/redundant with
   [assigns_to_zone_foobar_state] in Value/register.ml)
*)
let eval_assigns state assigns =
  let treat_one_zone acc (out, froms as asgn) = (* treat a single assign *)
    (* Return a list of independent output zones, plus a zone indicating
       that the zone has been overwritten in a sure way *)
    let outputs =
      try
        if Logic_utils.is_result out.it_content
        then []
        else
          let locs_out = !Db.Properties.Interp.loc_to_locs ~result:None
            state out.it_content
          in
          let conv loc =
            let z = valid_enumerate_bits ~for_writing:true loc in
            let sure = Locations.cardinal_zero_or_one loc in
            z, sure
          in
          List.map conv locs_out
      with Invalid_argument _ ->
        Inout_parameters.warning ~current:true ~once:true
          "Failed to interpret assigns clause '%a'" Cil.d_term out.it_content;
        [Locations.Zone.top, false]
    in
    (* Compute all inputs as a zone *)
    let inputs =
      try
        match froms with
          | FromAny -> Zone.top
          | From l ->
              let aux acc { it_content = from } =
                let loc = !Db.Properties.Interp.loc_to_loc None state from in
                let z = valid_enumerate_bits ~for_writing:false loc in
                Zone.join z acc
              in
              List.fold_left aux Zone.bottom l
      with Invalid_argument _ ->
        Inout_parameters.warning ~current:true ~once:true
          "Failed to interpret inputs in assigns clause '%a'"
          Cil.d_from asgn;
        Zone.top
    in
    (* Fuse all outputs. An output is sure if it was certainly overwritten,
       and if it is not amongst its from *)
    let extract_sure (sure_out, all_out) (out, exact) =
      let all_out' = Zone.join out all_out in
      if exact then
        let sure = Locations.Zone.diff out inputs in
        Zone.join sure sure_out, all_out'
      else
        sure_out, all_out'
    in
    let sure_out, all_out =
      List.fold_left extract_sure (Zone.bottom, Zone.bottom) outputs
    in (* Join all three kinds of locations. The use a join (not a meet) for
          under_outputs is correct here (and in fact required for precision) *)
    {
      under_outputs_d = Zone.join acc.under_outputs_d sure_out;
      over_inputs_d = Zone.join acc.over_inputs_d inputs;
      over_outputs_d = Zone.join acc.over_outputs_d all_out;
    }
  in
  match assigns with
    | WritesAny -> top
    | Writes l  ->
        let init = { bottom with under_outputs_d = Zone.bottom } in
        let r = List.fold_left treat_one_zone init l in {
          over_inputs = r.over_inputs_d;
          over_inputs_if_termination = r.over_inputs_d;
          under_outputs_if_termination = r.under_outputs_d;
          over_outputs = r.over_outputs_d;
          over_outputs_if_termination = r.over_outputs_d;
        }

let compute_using_prototype_state state kf =
  let behaviors = !Value.valid_behaviors kf state in
  let assigns = Ast_info.merge_assigns behaviors in
  eval_assigns state assigns

let compute_using_prototype ?stmt kf =
  let state = Cumulative_analysis.specialize_state_on_call ?stmt kf in
  compute_using_prototype_state state kf

(* Results of this module, consolidated by functions. Formals and locals
   are stored *)
module Internals =
  Kernel_function.Make_Table(Inout_type)
    (struct
       let name = "Internal inouts full"
       let dependencies = [ Value.self ]
       let size = 17
     end)

module CallsiteHash = Value_aux.Callsite.Hashtbl

(* Results of an an entire call, represented by a pair (stmt, kernel_function]).
   This table is filled by the [-inout-callwise] option, or for functions for
   which only the specification is used. *)
module CallwiseResults =
  State_builder.Hashtbl
  (CallsiteHash)
  (Inout_type)
  (struct
    let size = 17
    let dependencies = [Internals.self;
                        Inout_parameters.ForceCallwiseInout.self]
    let name = "Operational_inputs.CallwiseResults"
   end)


module Computer (X:sig
  val version: string (* Callwise or functionwise *)
  val kf: kernel_function (* Function being analyzed *)
  val stmt_state: stmt -> Db.Value.state (* Memory state at the given stmt *)
  val at_call: stmt -> kernel_function -> Inout_type.t (* Results of the
      analysis for the given call. Must not contain locals or formals *)
end) = struct
  let name = "InOut context " ^ X.version

  let debug = ref false

  let stmt_can_reach = Stmts_graph.stmt_can_reach X.kf

  let non_terminating_callees_inputs = ref Zone.bottom
  let non_terminating_callees_outputs = ref Zone.bottom

  type t = compute_t

  let pretty fmt x =
    Format.fprintf fmt
      "@[Over-approximated operational inputs: %a@]@\n\
       @[Under-approximated operational outputs: %a@]"
      Zone.pretty x.over_inputs_d
      Zone.pretty x.under_outputs_d

  module StmtStartData =
    Dataflow.StartData(struct type t = compute_t let size = 107 end)

  let copy (d: t) = d

  let computeFirstPredecessor (s: stmt) data =
    match s.skind with
      | Switch (exp,_,_,_)
      | If (exp,_,_,_)
      | Return (Some exp, _) ->
          let state = X.stmt_state s in
          let inputs = !From.find_deps_no_transitivity_state state exp in
          let new_inputs = Zone.diff inputs data.under_outputs_d in
          {data with over_inputs_d = Zone.join data.over_inputs_d new_inputs}
      | _ -> data

  let combinePredecessors (s: stmt) ~old new_ =
    let new_c = computeFirstPredecessor s new_ in
    let result = join new_c old in
    if is_included result old
    then None
    else Some result

  let doInstr stmt (i: instr) (_d: t) =
    let state = X.stmt_state stmt in
    let add_out lv deps data =
      let deps, loclv = !Value.lval_to_loc_with_deps_state ~deps state lv in
      let new_inputs = Zone.diff deps data.under_outputs_d in
      let new_outs = Locations.valid_enumerate_bits ~for_writing:true loclv in
      let new_sure_outs =
        if Locations.valid_cardinal_zero_or_one ~for_writing:true loclv then
          (* There is only one modified zone. So, this is an exact output.
             Add it into the under-approximed outputs. *)
          Zone.link data.under_outputs_d new_outs
        else data.under_outputs_d
      in {
        under_outputs_d = new_sure_outs;
        over_inputs_d = Zone.join data.over_inputs_d new_inputs;
        over_outputs_d = Zone.join data.over_outputs_d new_outs }
    in
    match i with
    | Set (lv, exp, _) ->
        Dataflow.Post
          (fun data ->
             let state = X.stmt_state stmt in
             let e_inputs = !From.find_deps_no_transitivity_state state exp in
             add_out lv e_inputs data)

    | Call (lvaloption,funcexp,argl,_) ->
        let state = X.stmt_state stmt in
        Dataflow.Post
          (fun data ->
             let funcexp_inputs, called =
               !Db.Value.expr_to_kernel_function_state
                 ~deps:(Some Zone.bottom)
                 state
                 funcexp
             in

             let acc_funcexp_arg_inputs =
               (* add the inputs of [argl] to the inputs of the
                  function expression *)
               List.fold_right
                 (fun arg inputs ->
                    let arg_inputs = !From.find_deps_no_transitivity_state
                      state arg
                    in Zone.join inputs arg_inputs)
                 argl
                 funcexp_inputs
             in
             let data =
               catenate
                 data
                 { over_inputs_d = acc_funcexp_arg_inputs ;
                   under_outputs_d = Zone.bottom;
                   over_outputs_d = Zone.bottom; }
             in
             let for_functions =
               Kernel_function.Hptset.fold
                 (fun kf acc  ->
                    let res = X.at_call stmt kf in
                    non_terminating_callees_inputs :=
                      Zone.join
                        !non_terminating_callees_inputs
                        (Zone.diff res.Inout_type.over_inputs
                           data.under_outputs_d);
                    non_terminating_callees_outputs :=
                      Zone.join
                        !non_terminating_callees_outputs
                        res.over_outputs;
                    let for_function = {
                      over_inputs_d = res.over_inputs_if_termination;
                      under_outputs_d = res.under_outputs_if_termination;
                      over_outputs_d = res.over_outputs_if_termination;
                    } in
                    join for_function acc)
                 called
                 bottom
             in
             let result = catenate data for_functions in
             let result =
               (* Treatment for the possible assignment of the call result *)
               (match lvaloption with
                | None -> result
                | Some lv -> add_out lv Zone.bottom result)
             in result
          )
    | _ -> Dataflow.Default

  let doStmt (_s: stmt) (_d: t) =
    Dataflow.SDefault

  let filterStmt stmt =
    let state = X.stmt_state stmt in
    Value.is_reachable state

  let doGuard stmt e _t =
    let state = X.stmt_state stmt in
    let v_e = !Db.Value.eval_expr ~with_alarms:CilE.warn_none_mode state e in
    let t1 = Cil.unrollType (Cil.typeOf e) in
    let do_then, do_else =
      if Cil.isIntegralType t1 || Cil.isPointerType t1
      then Cvalue.V.contains_non_zero v_e,
           Cvalue.V.contains_zero v_e
      else true, true (* TODO: a float condition is true iff != 0.0 *)
      in
      (if do_then
       then Dataflow.GDefault
       else Dataflow.GUnreachable),
      (if do_else
       then Dataflow.GDefault
       else Dataflow.GUnreachable)

  let doEdge _ _ d = d

  let init_dataflow () = (* TODO. Less ugly way? *)
    let start = List.hd (Kernel_function.get_definition X.kf).sbody.bstmts in
    StmtStartData.add start (computeFirstPredecessor start empty);
    start

  let end_dataflow () =
    let res_if_termination =
      try StmtStartData.find (Kernel_function.find_return X.kf)
      with Not_found -> bottom
    in
    StmtStartData.iter
      (fun _ data ->
        non_terminating_callees_inputs :=
          Zone.join data.over_inputs_d !non_terminating_callees_inputs;
        non_terminating_callees_outputs :=
          Zone.join data.over_outputs_d !non_terminating_callees_outputs;
      );
    {
      over_inputs_if_termination = res_if_termination.over_inputs_d;
      under_outputs_if_termination = res_if_termination.under_outputs_d ;
      over_inputs = !non_terminating_callees_inputs;
      over_outputs_if_termination = res_if_termination.over_outputs_d;
      over_outputs = !non_terminating_callees_outputs;
    }

end


let externalize ~with_formals kf v =
  let filter = externalize_zone ~with_formals kf in
  Inout_type.map filter v

let compute_externals_using_prototype ?stmt kf =
  let internals = compute_using_prototype ?stmt kf in
  externalize ~with_formals:false kf internals

let get_internal_aux ?stmt kf =
  match stmt with
    | None -> !Db.Operational_inputs.get_internal kf
    | Some stmt ->
        try CallwiseResults.find (kf, Kstmt stmt)
        with Not_found ->
          if !Db.Value.use_spec_instead_of_definition kf then
            compute_using_prototype ~stmt kf
          else !Db.Operational_inputs.get_internal kf

let get_external_aux ?stmt kf =
  match stmt with
    | None -> !Db.Operational_inputs.get_external kf
    | Some stmt ->
        try
          let internals = CallwiseResults.find (kf, Kstmt stmt) in
          externalize ~with_formals:false kf internals
        with Not_found ->
          if !Db.Value.use_spec_instead_of_definition kf then
            let r = compute_externals_using_prototype ~stmt kf in
            CallwiseResults.add (kf, Kstmt stmt) r;
            r
          else !Db.Operational_inputs.get_external kf


module Callwise = struct

  let compute_callwise () =
    Inout_parameters.ForceCallwiseInout.get () ||
      Dynamic.Parameter.Bool.get "-memexec-all" ()

  let merge_call_in_local_table call local_table v =
    let prev =
      try CallsiteHash.find local_table call
      with Not_found -> Inout_type.bottom
    in
    let joined = Inout_type.join v prev in
    CallsiteHash.replace local_table call joined

  let merge_call_in_global_tables (kf, _ as call) v =
    (* Global callwise table *)
    let prev =
      try CallwiseResults.find call
      with Not_found -> Inout_type.bottom
    in
    CallwiseResults.replace call (Inout_type.join v prev);
    (* Global, kf-indexed, table *)
    let prev =
      try Internals.find kf
      with Not_found -> Inout_type.bottom
    in
    Internals.replace kf (Inout_type.join v prev);
  ;;

  let merge_local_table_in_global_ones =
    CallsiteHash.iter merge_call_in_global_tables
  ;;


  let call_inout_stack = ref []

  let call_for_callwise_inout (state, call_stack) =
    if compute_callwise () then begin
      let (current_function, ki as call_site) = List.hd call_stack in
      if not (!Db.Value.use_spec_instead_of_definition current_function) then
        let table_current_function = CallsiteHash.create 7 in
        call_inout_stack :=
          (current_function, table_current_function) :: !call_inout_stack
      else
        try
          let _above_function, table = List.hd !call_inout_stack in
          let inout = compute_using_prototype_state state current_function in
          if ki = Kglobal then
            merge_call_in_global_tables call_site inout
          else
            merge_call_in_local_table call_site table inout;
      with Failure "hd" ->
        Inout_parameters.fatal "inout: empty stack"
          Kernel_function.pretty current_function
    end

  module MemExec =
    State_builder.Hashtbl
      (Datatype.Int.Hashtbl)
      (Inout_type)
      (struct
         let size = 17
         let dependencies = [Internals.self]
         let name = "Operational_inputs.MemExec"
   end)


  let end_record call_stack inout =
    merge_local_table_in_global_ones (snd (List.hd !call_inout_stack));

    let (current_function, _ as call_site) = List.hd call_stack in
    (* pop + record in top of stack the inout of function that just finished*)
    match !call_inout_stack with
      | (current_function2, _) :: (((_caller, table) :: _) as tail) ->
          if current_function2 != current_function then
            Inout_parameters.fatal "callwise inout %a != %a@."
              Kernel_function.pretty current_function (* g *)
              Kernel_function.pretty current_function2 (* f *);
          call_inout_stack := tail;
          merge_call_in_local_table call_site table inout;

      | _ ->  (* the entry point, probably *)
          merge_call_in_global_tables call_site inout;
          call_inout_stack := [];
          CallwiseResults.mark_as_computed ()

  let compute_call_from_value_states kf states =
    let module Computer = Computer(
      struct
        let version = "callwise"
        let kf = kf

        let stmt_state stmt =
          try Cil_datatype.Stmt.Hashtbl.find states stmt
          with Not_found -> Cvalue.Model.bottom

        let at_call stmt kf =
          let _cur_kf, table = List.hd !call_inout_stack in
          try
            let with_internals = CallsiteHash.find table (kf, Kstmt stmt) in
            match kf.fundec with
              | Definition (fundec, _) ->
                  let filter = Zone.filter_base
                    (fun b -> not (Base.is_formal_or_local b fundec))
                  in
                  Inout_type.map filter with_internals
              | _ -> with_internals
          with Not_found -> Inout_type.bottom
      end) in

    let module Compute = Dataflow.Forwards(Computer) in
    let start_stmt = Computer.init_dataflow () in
    Compute.compute [start_stmt];
    Computer.end_dataflow ()


  let record_for_callwise_inout ((call_stack: Db.Value.callstack), value_res) =
    if compute_callwise () then
      let inout = match value_res with
        | Value_aux.Normal states | Value_aux.NormalStore (states, _) ->
            let kf = fst (List.hd call_stack) in
            let inout =
              if !Db.Value.no_results (Kernel_function.get_definition kf) then
                top
              else
                compute_call_from_value_states kf (Lazy.force states)
            in
            Db.Operational_inputs.Record_Inout_Callbacks.apply
              (call_stack, inout);
            (match value_res with
               | Value_aux.NormalStore (_, memexec_counter) ->
                   MemExec.replace memexec_counter inout
               | _ -> ());
            inout

        | Value_aux.Reuse counter ->
            MemExec.find counter
      in
      end_record call_stack inout


  (* Register our callbacks inside the value analysis *)

  let add_hooks () =
    Db.Value.Record_Value_Callbacks_New.extend_once record_for_callwise_inout;
    Db.Value.Call_Value_Callbacks.extend_once call_for_callwise_inout

  let () = Inout_parameters.ForceCallwiseInout.add_set_hook
    (fun bold bnew ->
      if bnew then add_hooks ();
      if bold = false && bnew then
        Project.clear
          ~selection:(State_selection.with_dependencies Db.Value.self) ();
    )

end


(* Functionwise version of the computations. *)
module FunctionWise = struct

  (* Stack of function being processed *)
  let call_stack : kernel_function Stack.t = Stack.create ()

  let compute_internal_using_cfg kf =
    try
      let module Computer = Computer (struct
        let version = "functionwise"
        let kf = kf
        let stmt_state = Db.Value.get_stmt_state
        let at_call stmt kf = get_external_aux ~stmt kf
      end) in
      let module Compute = Dataflow.Forwards(Computer) in
      Stack.iter
        (fun g -> if kf == g then begin
          if Db.Value.ignored_recursive_call kf then
            Inout_parameters.warning ~current:true
              "During inout context analysis of %a:@ \
                  ignoring probable recursive call."
              Kernel_function.pretty kf;
          raise Exit
        end)
        call_stack;
      Stack.push kf call_stack;
      let start_stmt = Computer.init_dataflow () in
      Compute.compute [start_stmt];
      let r = Computer.end_dataflow () in
      ignore (Stack.pop call_stack);
      r
    with Exit -> Inout_type.bottom (*TODO*) (*{
    Inout_type.over_inputs_if_termination = empty.over_inputs_d ;
    under_outputs_if_termination = empty.under_outputs_d;
    over_inputs = empty.over_inputs_d;
    over_outputs = empty.over_outputs_d;
    over_outputs_if_termination = empty.over_outputs_d;
  }*)

  let compute_internal_using_cfg kf =
    Inout_parameters.feedback ~level:2 "computing for function %a%s"
      Kernel_function.pretty kf
      (let s = ref "" in
       Stack.iter
         (fun kf -> s := !s^" <-"^
           (Pretty_utils.sfprintf "%a" Kernel_function.pretty kf))
         call_stack;
       !s);
    let r = compute_internal_using_cfg kf in
    Inout_parameters.feedback ~level:2 "done for function %a"
      Kernel_function.pretty kf;
    r
end


let get_internal =
  Internals.memo
    (fun kf ->
       !Value.compute ();
       try Internals.find kf (* If [-inout-callwise] is set, the results may
                              have been computed by the call to Value.compute *)
       with
         | Not_found ->
             if!Db.Value.use_spec_instead_of_definition kf then
               compute_using_prototype kf
             else
               FunctionWise.compute_internal_using_cfg kf
    )

let raw_externals ~with_formals kf =
  let filter = externalize ~with_formals kf in
  filter (get_internal kf)

module Externals =
  Kernel_function.Make_Table(Inout_type)
    (struct
       let name = "External inouts full"
       let dependencies = [ Internals.self ]
       let size = 17
     end)
let get_external = Externals.memo (raw_externals ~with_formals:false)
let compute_external kf = ignore (get_external kf)



module Externals_With_Formals =
  Kernel_function.Make_Table(Inout_type)
    (struct
       let name = "External inouts with formals full"
       let dependencies = [ Internals.self ]
       let size = 17
     end)
let get_external_with_formals =
  Externals_With_Formals.memo (raw_externals ~with_formals:true)
let compute_external_with_formals kf = ignore (get_external_with_formals kf)


let pretty_operational_inputs_internal fmt kf =
  Format.fprintf fmt "@[InOut (internal) for function %a:@\n%a@]@\n"
    Kernel_function.pretty kf
    Inout_type.pretty_operational_inputs (get_internal kf)

let pretty_operational_inputs_external fmt kf =
  Format.fprintf fmt "@[InOut for function %a:@\n%a@]@\n"
    Kernel_function.pretty kf
    Inout_type.pretty_operational_inputs (get_external kf)

let pretty_operational_inputs_external_with_formals fmt kf =
  Format.fprintf fmt "@[InOut (with formals) for function %a:@\n%a@]@\n"
    Kernel_function.pretty kf
    Inout_type.pretty_operational_inputs (get_external_with_formals kf)



let () =
  Db.Operational_inputs.self_internal := Internals.self;
  Db.Operational_inputs.self_external := Externals.self;
  Db.Operational_inputs.get_internal := get_internal;
  Db.Operational_inputs.get_external := get_external;
  Db.Operational_inputs.get_internal_precise := get_internal_aux;
  Db.Operational_inputs.compute := compute_external;
  Db.Operational_inputs.display := pretty_operational_inputs_internal


(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
