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


module Tbl =
  Kernel_function.Make_Table
    (Function_Froms)
    (struct
       let name = "Functionwise dependencies"
       let size = 17
       let dependencies = [ Db.Value.self ]
     end)
let () = From_parameters.ForceDeps.set_output_dependencies [Tbl.self]

(* Forward reference to a function computing the from for a given function *)
let force_compute = ref (fun _ -> assert false)

module Functionwise_From_to_use =
struct
  let memo kf =
    Tbl.memo
      (fun kf ->
         !force_compute kf;
         try Tbl.find kf
         with Not_found -> invalid_arg "could not compute dependencies")
      kf
  let get kf _ = memo kf
end

module Recording_To_Do =
struct
  let accept_base_in_lmap =
    Value_aux.accept_base ~with_formals:false ~with_locals:false
  let final_cleanup kf froms =
    if Lmap_bitwise.From_Model.is_bottom froms.Function_Froms.deps_table
    then froms
    else
    let f k intervs =
      if Value_aux.accept_base ~with_formals:true ~with_locals:false kf k
      then Zone.inject k intervs
      else Zone.bottom
    in
    let joiner = Zone.join in
    let projection base =
      match Base.validity base with
      | Base.Periodic (min_valid, max_valid, _)
      | Base.Known (min_valid,max_valid)
      | Base.Unknown (min_valid,max_valid)->
          Lattice_Interval_Set.Int_Intervals.inject_bounds min_valid max_valid
      | Base.All -> assert false(*TODO*)
    in
    let zone_substitution =
      Zone.cached_fold ~cache:("from cleanup", 331) ~temporary:true
        ~f ~joiner ~empty:Zone.bottom ~projection
    in
    let zone_substitution x =
      try
        zone_substitution x
      with Zone.Error_Top -> Zone.top
    in
    { Function_Froms.deps_table =
        Lmap_bitwise.From_Model.map_and_merge
          zone_substitution
          froms.Function_Froms.deps_table
          Lmap_bitwise.From_Model.empty;
      deps_return =
        Lmap_bitwise.From_Model.LOffset.map
          (function b, d -> b, zone_substitution d)
          froms.Function_Froms.deps_return;
    }
  let record_kf kf last_from = Tbl.add kf last_from
end

module Value_local = struct
  let get_stmt_state = Db.Value.get_stmt_state
  let access_expr s exp = !Db.Value.access_expr (Kstmt s) exp
  let expr_to_kernel_function s ~deps exp =
    !Db.Value.expr_to_kernel_function
      (Kstmt s) ~with_alarms:CilE.warn_none_mode ~deps exp
  let lval_to_loc_with_deps s ~deps lval =
    !Db.Value.lval_to_loc_with_deps
      (Kstmt s) ~with_alarms:CilE.warn_none_mode ~deps lval
end

module From =
  From_compute.Make(Value_local)(Functionwise_From_to_use)(Recording_To_Do)

let () =
  force_compute := From.compute


let force_compute_all () =
  !Db.Value.compute ();
  !Db.Semantic_Callgraph.topologically_iter_on_functions
    (fun kf ->
       if Kernel_function.is_definition kf && !Db.Value.is_called kf
       then !Db.From.compute kf)

(* Db Registration for function-wise from *)
let () =
  Db.From.self := Tbl.self;
  Db.From.is_computed := Tbl.mem;
  Db.From.compute :=
    (fun kf -> ignore (Functionwise_From_to_use.memo kf));
  Db.From.get := Functionwise_From_to_use.memo;
  Db.From.pretty :=
    (fun fmt v ->
      let deps = Functionwise_From_to_use.memo v in
      Function_Froms.pretty_with_type (Kernel_function.get_type v) fmt deps);
  Db.From.find_deps_no_transitivity :=
    (fun stmt lv ->
       let state = Db.Value.get_stmt_state stmt in
       From_compute.find_deps_no_transitivity state lv);
  Db.From.find_deps_no_transitivity_state :=
    From_compute.find_deps_no_transitivity;

  ignore (
    Db.register_compute "From.compute_all"
      [Tbl.self]
      Db.From.compute_all
      force_compute_all);