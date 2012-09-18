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

open Property
open Cil_types

let pp_loc = Cil_datatype.Location.pretty_long

let pp_kloc kloc fmt loc =
  if kloc then Format.fprintf fmt " (%a)" pp_loc loc else ()

let pp_opt doit pp fmt x = if doit then pp fmt x

let goto_stmt stmt =
  let rec goto_label = function
    | [] -> Printf.sprintf "s%04d" stmt.sid
    | Label(a,_,true)::_ -> a 
    | _::labels -> goto_label labels
  in goto_label stmt.labels

let rec stmt_labels = function
  | Label(a,_,true) :: ls -> a :: stmt_labels ls
  | Label _ :: ls -> stmt_labels ls
  | Case(e,_) :: ls -> 
      let cvalue = (Cil.constFold true e) in
      Pretty_utils.sfprintf "case %a" !Ast_printer.d_exp cvalue
      :: stmt_labels ls
  | Default _ :: ls ->
      "default" :: stmt_labels ls
  | [] -> []

let pp_labels fmt stmt =
  match stmt_labels stmt.labels with
    | [] -> ()
    | ls -> Format.fprintf fmt " '%s'" (String.concat "," ls)

let pp_idpred kloc fmt idpred =
  if idpred.ip_name <> [] 
  then Format.fprintf fmt " '%s'" (String.concat "," idpred.ip_name)
  else pp_kloc kloc fmt idpred.ip_loc

let pp_allocation kloc fmt (allocation:identified_term list) =
  if allocation = [] then Format.fprintf fmt "nothing"
  else
    let names = 
      List.fold_left
	(fun names x -> names @ x.it_content.term_name)
	[] allocation in
    match names with
      | [] ->
	  if kloc then 
	    let x = List.hd allocation in
	    Format.fprintf fmt "(%a)" pp_loc x.it_content.term_loc
	  else Format.fprintf fmt "..."
      | _ ->
	  Format.fprintf fmt "'%s'" (String.concat "," names)

let pp_region kloc fmt (region:identified_term from list) =
  if region = [] then Format.fprintf fmt "nothing"
  else
    let names = 
      List.fold_left
	(fun names (x,_) -> names @ x.it_content.term_name)
	[] region in
    match names with
      | [] ->
	  if kloc then 
	    let x = fst (List.hd region) in
	    Format.fprintf fmt "(%a)" pp_loc x.it_content.term_loc
	  else Format.fprintf fmt "..."
      | _ ->
	  Format.fprintf fmt "'%s'" (String.concat "," names)

let pp_bhv fmt bhv =
  if not (Cil.is_default_behavior bhv) then 
    Format.fprintf fmt " for '%s'" bhv.b_name

let pp_bhvs fmt = function
  | [] -> ()
  | b::bs ->
      Format.fprintf fmt " @[<hov 0>'%s'" b ;
      List.iter (fun b -> Format.fprintf fmt ",@ '%s'" b) bs ;
      Format.fprintf fmt "@]"

let pp_for fmt = function
  | [] -> ()
  | bs -> Format.fprintf fmt " for '%s'" (String.concat "," bs)

let pp_named fmt nx =
  if nx.name <> [] then Format.fprintf fmt " '%s'" (String.concat "," nx.name)

let pp_code_annot fmt ca =
  match ca.annot_content with
    | AAssert(bs,np) -> Format.fprintf fmt "assertion%a%a" pp_for bs pp_named np
    | AInvariant(bs,_,np) -> 
      Format.fprintf fmt "invariant%a%a" pp_for bs pp_named np
    | AAssigns(bs,_) -> Format.fprintf fmt "assigns%a" pp_for bs
    | AAllocation(bs,_) -> Format.fprintf fmt "allocates_frees%a" pp_for bs
    | APragma _ -> Format.pp_print_string fmt "pragma"
    | AVariant _ -> Format.pp_print_string fmt "variant"
    | AStmtSpec _ -> Format.pp_print_string fmt "block contract"

let pp_stmt kloc fmt stmt =
  match stmt.skind with
    | Instr (Call(_,{enode=Lval(Var v,_)},_,loc)) -> 
	Format.fprintf fmt "call '%s'%a" v.vname (pp_kloc kloc) loc
    | Instr (Set(_,_,loc)|Call(_,_,_,loc)) -> 
	Format.fprintf fmt "instruction%a" (pp_kloc kloc) loc
    | Instr (Asm(_,_,_,_,_,loc)) ->
	Format.fprintf fmt "assembly%a%a" pp_labels stmt (pp_kloc kloc) loc
    | Instr (Skip(_,loc)) ->
	Format.fprintf fmt "program point%a%a" pp_labels stmt (pp_kloc kloc) (loc,loc)
    | Instr (Code_annot(ca,loc)) ->
	Format.fprintf fmt "%a%a" pp_code_annot ca (pp_kloc kloc) loc
    | Return(_,loc) -> Format.fprintf fmt "return%a" (pp_kloc kloc) loc
    | Goto(s,loc) -> Format.fprintf fmt "goto %s%a" (goto_stmt !s) (pp_kloc kloc) loc
    | Break loc -> Format.fprintf fmt "break%a" (pp_kloc kloc) loc
    | Continue loc -> Format.fprintf fmt "continue%a" (pp_kloc kloc) loc
    | If(_,_,_,loc) -> Format.fprintf fmt "if-then-else%a" (pp_kloc kloc) loc
    | Switch(_,_,_,loc) -> Format.fprintf fmt "switch%a" (pp_kloc kloc) loc
    | Loop(_,_,loc,_,_) -> Format.fprintf fmt "loop%a" (pp_kloc kloc) loc
    | Block _ -> Format.fprintf fmt "block%a" pp_labels stmt
    | UnspecifiedSequence _ -> Format.fprintf fmt "instruction%a" pp_labels stmt
    | TryFinally(_,_,loc) | TryExcept(_,_,_,loc) -> 
      Format.fprintf fmt "try-catch%a" (pp_kloc kloc) loc

let pp_kinstr kloc fmt = function
  | Kglobal -> ()
  | Kstmt s -> Format.fprintf fmt " at %a" (pp_stmt kloc) s

let pp_predicate fmt = function
  | PKRequires bhv -> 
      Format.fprintf fmt "Pre-condition%a" pp_bhv bhv
  | PKAssumes bhv -> 
      Format.fprintf fmt "Assumption%a" pp_bhv bhv
  | PKEnsures(bhv,Normal) ->
      Format.fprintf fmt "Post-condition%a" pp_bhv bhv
  | PKEnsures(bhv,Breaks) ->
      Format.fprintf fmt "Breaking-condition%a" pp_bhv bhv
  | PKEnsures(bhv,Continues) ->
      Format.fprintf fmt "Continue-condition%a" pp_bhv bhv
  | PKEnsures(bhv,Returns) ->
      Format.fprintf fmt "Return-condition%a" pp_bhv bhv
  | PKEnsures(bhv,Exits) ->
      Format.fprintf fmt "Exit-condition%a" pp_bhv bhv
  | PKTerminates ->
      Format.fprintf fmt "Termination-condition"

let pp_context kfopt fmt = function
  | None -> ()
  | Some kf ->
      match kfopt with
	| `Always ->
	    Format.fprintf fmt " in '%s'" (Kernel_function.get_name kf)
	| `Never -> ()
	| `Context kf0 -> 
	    if not (Kernel_function.equal kf0 kf) then 
	      Format.fprintf fmt " of '%s'" (Kernel_function.get_name kf)

let pp_prop kfopt kiopt kloc fmt = function
  | IPAxiom (s,_,_,_,_) -> Format.fprintf fmt "Axiom '%s'" s
  | IPLemma (s,_,_,_,_) -> Format.fprintf fmt "Lemma '%s'" s
  | IPAxiomatic (s,_) -> Format.fprintf fmt "Axiomatic '%s'" s
  | IPOther(s,kf,ki) -> Format.fprintf fmt "%s%a%a" s 
    (pp_context kfopt) kf (pp_opt kiopt (pp_kinstr kloc)) ki
  | IPPredicate(kind,kf,Kglobal,idpred) ->
    Format.fprintf fmt "%a%a%a" 
      pp_predicate kind 
      (pp_idpred kloc) idpred 
      (pp_context kfopt) (Some kf)
  | IPPredicate(kind,_,ki,idpred) ->
    Format.fprintf fmt "%a%a%a" 
      pp_predicate kind 
      (pp_idpred kloc) idpred 
      (pp_kinstr kloc) ki
  | IPBehavior(_,ki,bhv) ->
    if Cil.is_default_behavior bhv then
      Format.fprintf fmt "Default behavior%a" (pp_opt kiopt (pp_kinstr kloc)) ki
    else
      Format.fprintf fmt "Behavior '%s'%a" 
	bhv.b_name
	(pp_opt kiopt (pp_kinstr kloc)) ki
  | IPComplete(_,ki,bs) ->
    Format.fprintf fmt "Complete behaviors%a%a" 
      pp_bhvs bs
      (pp_opt kiopt (pp_kinstr kloc)) ki
  | IPDisjoint(_,ki,bs) ->
    Format.fprintf fmt "Disjoint behaviors%a%a" 
      pp_bhvs bs
      (pp_opt kiopt (pp_kinstr kloc)) ki
  | IPCodeAnnot(_,_,{annot_content=AAssert(bs,np)}) ->
    Format.fprintf fmt "Assertion%a%a%a" 
      pp_for bs 
      pp_named np 
      (pp_kloc kloc) np.loc
  | IPCodeAnnot(_,_,{annot_content=AInvariant(bs,_,np)}) ->
    Format.fprintf fmt "Invariant%a%a%a" 
      pp_for bs 
      pp_named np 
      (pp_kloc kloc) np.loc
  | IPCodeAnnot(_,stmt,_) ->
    Format.fprintf fmt "Annotation %a" (pp_stmt kloc) stmt
  | IPAllocation(kf,Kglobal,Id_behavior bhv,(frees,allocates)) ->
    Format.fprintf fmt "Frees/Allocates%a %a/%a %a" 
      pp_bhv bhv 
      (pp_allocation kloc) frees
      (pp_allocation kloc) allocates
      (pp_context kfopt) (Some kf) 
  | IPAssigns(kf,Kglobal,Id_behavior bhv,region) ->
    Format.fprintf fmt "Assigns%a %a%a" 
      pp_bhv bhv 
      (pp_region kloc) region 
      (pp_context kfopt) (Some kf) 
  | IPFrom (kf,Kglobal,Id_behavior bhv,depend) ->
    Format.fprintf fmt "Froms%a %a%a"
      pp_bhv bhv 
      (pp_region kloc) [depend] 
      (pp_context kfopt) (Some kf) 
  | IPAllocation(_,ki,Id_behavior bhv,(frees,allocates)) ->
    Format.fprintf fmt "Frees/Allocates%a %a/%a %a" 
      pp_bhv bhv 
      (pp_allocation kloc) frees
      (pp_allocation kloc) allocates
      (pp_opt kiopt (pp_kinstr kloc)) ki
  | IPAssigns(_,ki,Id_behavior bhv,region) ->
    Format.fprintf fmt "Assigns%a %a%a"
      pp_bhv bhv 
      (pp_region kloc) region 
      (pp_opt kiopt (pp_kinstr kloc)) ki
  | IPFrom (_,ki,Id_behavior bhv,depend) ->
    Format.fprintf fmt "Froms%a %a%a" 
      pp_bhv bhv 
      (pp_region kloc) [depend] 
      (pp_opt kiopt (pp_kinstr kloc)) ki
  | IPAllocation(_,_,Id_code_annot _,(frees,allocates)) ->
    Format.fprintf fmt "Loop frees%a Loop allocates%a" 
      (pp_allocation kloc) frees
      (pp_allocation kloc) allocates
  | IPAssigns(_,_,Id_code_annot _,region) ->
    Format.fprintf fmt "Loop assigns %a" (pp_region kloc) region
  | IPFrom(_,_,Id_code_annot _,depend) ->
    Format.fprintf fmt "Loop froms %a" (pp_region kloc) [depend]
  | IPDecrease(_,Kglobal,_,_) ->
    Format.fprintf fmt "Recursion variant"
  | IPDecrease(_,Kstmt stmt,_,_) ->
    Format.fprintf fmt "Loop variant at %a" (pp_stmt kloc) stmt
  | IPReachable (None, Kglobal, Before) -> 
    (* print "Unreachable": it seems that it is what the user want to see *)
    Format.fprintf fmt "Unreachable entry point"
  | IPReachable (None, Kglobal, After)
  | IPReachable (None, Kstmt _, _) -> assert false
  | IPReachable (Some _, Kstmt stmt, ba) ->
    (* print "Unreachable": it seems that it is what the user want to see *)
    Format.fprintf fmt "Unreachable %a%s" 
      (pp_stmt kloc) stmt
      (match ba with Before -> "" | After -> " (after it)")
  | IPReachable (Some kf, Kglobal, _) ->
    (* print "Unreachable": it seems that it is what the user want to see *)
    Format.fprintf fmt "Unreachable %a" Kernel_function.pretty kf

type kf = [ `Always | `Never | `Context of kernel_function ]

let pp_property = pp_prop `Always true true
let pp_localized ~kf ~ki ~kloc = pp_prop kf ki kloc

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
