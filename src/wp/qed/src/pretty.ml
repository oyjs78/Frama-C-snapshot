(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2012                                               *)
(*    CEA (Commissariat a l'�nergie atomique et aux �nergies              *)
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

(* -------------------------------------------------------------------------- *)
(* --- Pretty Printer with sharing                                        --- *)
(* -------------------------------------------------------------------------- *)

open Logic
open Format
open Plib

module Make(T : Term) =
struct

  open T

  (* -------------------------------------------------------------------------- *)
  (* ---  Types                                                             --- *)
  (* -------------------------------------------------------------------------- *)

  let pp_tvarn fmt n = fprintf fmt "?%d" n
  let pp_alpha fmt = function
    | 0 -> pp_print_string fmt "'a"
    | 1 -> pp_print_string fmt "'b"
    | 2 -> pp_print_string fmt "'c"
    | 3 -> pp_print_string fmt "'d"
    | 4 -> pp_print_string fmt "'e"
    | n -> fprintf fmt "?%d" (n-4)

  let pp_tau fmt t = 
    let n = Kind.degree_of_tau t in
    if 0<=n && n<5
    then Kind.pp_tau pp_alpha Field.pretty ADT.pretty fmt t
    else Kind.pp_tau pp_tvarn Field.pretty ADT.pretty fmt t

  (* -------------------------------------------------------------------------- *)
  (* --- Variables                                                          --- *)
  (* -------------------------------------------------------------------------- *)

  module Idx = Map.Make(String)
  module Ids = Set.Make(String)
  
  type env = {
    mutable named : string Tmap.t ; (* named terms *)
    mutable index : int Idx.t ;     (* index names *)
    mutable known : Ids.t ;         (* known names *)
    mutable closed : Vars.t ;
  }

  let fresh env term ?id base =
    let rec scan env base k =
      let a = Printf.sprintf "%s_%d" base k in
      if Ids.mem a env.known 
      then scan env base (succ k) 
      else (env.index <- Idx.add base (succ k) env.index ; a) in
    let freshname env base = scan env base 
      (try Idx.find base env.index with Not_found -> 0) in
    let x =
      match id with
	| None -> freshname env base
	| Some a -> if Ids.mem a env.known then freshname env base else a
    in
    env.known <- Ids.add x env.known ;
    env.named <- Tmap.add term x env.named ; x

  (* -------------------------------------------------------------------------- *)
  (* --- Environment                                                        --- *)
  (* -------------------------------------------------------------------------- *)
      
  let closed = { 
    named=Tmap.empty ; 
    index=Idx.empty ; 
    known=Ids.empty ; 
    closed=Vars.empty ;
  }

  let copy env =  {
    named = env.named ;
    index = env.index ;
    known = env.known ;
    closed = env.closed ;
  }
    
  let bind x t env =
    let env = copy env in
    env.named <- Tmap.add t x env.named ;
    env.known <- Ids.add x env.known ;
    env

  (* -------------------------------------------------------------------------- *)
  (* --- Bunch of Quantifier                                                --- *)
  (* -------------------------------------------------------------------------- *)

  module TauMap = Map.Make
    (struct
       type t = T.tau
       let compare = Kind.compare_tau T.Field.compare T.ADT.compare
     end)

  let group_add m x =
    let t = tau_of_var x in
    let xs = try TauMap.find t m with Not_found -> [] in
    TauMap.add t (x::xs) m

  let rec group_binders = function
    | [] -> []
    | (q,x)::qxs ->
	let m = TauMap.add (tau_of_var x) [x] TauMap.empty in
	group_binder q m qxs

  and group_binder q m = function
    | (q0,y)::qxs when q0 = q -> 
	group_binder q (group_add m y) qxs
    | qxs -> (q,m)::group_binders qxs

  (* -------------------------------------------------------------------------- *)
  (* --- Output Form                                                        --- *)
  (* -------------------------------------------------------------------------- *)

  type out =
    | Atom of string
    | Hbox of string * term list
    | Vbox of string * term list
    | Unop of string * term
    | Binop of ( term * string * term )
    | Cond of ( term * term * term )
    | Call of Fun.t * term list
    | Closure of term * term list
    | Access of term * term
    | Update of term * term * term
    | Abstraction of ( (binder * var) list * term )
    | Record of field list
    | GetField of term * Field.t

  and field =
    | With  of term
    | Field of Field.t * term
    | Last  of Field.t * term

  let rec fields = function
    | [] -> []
    | [f,v] -> [Last(f,v)]
    | (f,v)::fvs -> Field(f,v)::fields fvs

  let rec out env e =
    try Atom(Tmap.find e env.named)
    with Not_found ->
      match T.repr e with
	| Var x -> Atom( Plib.to_string Var.pretty x )
	| True -> Atom "true"
	| False -> Atom "false"
	| Kint z -> Atom (Z.to_string z)
	| Kreal r -> Atom (R.to_string r)
	| Times(z,e) when Z.equal z Z.minus_one -> Unop("-",e)
	| Times(z,e) -> Hbox("*",[e_zint z;e])
	| Add es -> Hbox("+",es)
	| Mul es -> Hbox("*",es)
	| Div(a,b) -> Binop(a,"div",b)
	| Mod(a,b) -> Binop(a,"mod",b)
	| And es -> Vbox("/\\",es)
	| Or  es -> Vbox("\\/",es)
	| Not e -> Unop("not ",e)
	| Imply(hs,p) ->Vbox("->",hs@[p])
	| Eq(a,b) -> 
	    if T.sort e = Sprop 
	    then Vbox("<->",[a;b])
	    else Hbox("=",[a;b])
	| Lt(a,b) -> Hbox("<",[a;b])
	| Neq(a,b) -> Hbox("≠",[a;b])
	| Leq(a,b) -> Hbox("≤",[a;b])
	| Fun(a,es) -> Call(a,es)
	| Apply(e,es) -> Closure(e,es)
	| If(c,a,b) -> Cond(c,a,b)
	| Aget(a,b) -> Access(a,b)
	| Aset(a,b,c) -> Update(a,b,c)
	| Bind(q,x,t) -> abstraction [q,x] t
	| Rget(e,f) -> GetField(e,f)
	| Rdef fvs -> Record 
	    begin
	      match T.record_with fvs with
		| None -> fields fvs
		| Some(base,fothers) -> With base :: fields fothers
	    end

  and abstraction qxs e =
    match T.repr e with
      | Bind(q,x,t) -> abstraction ((q,x)::qxs) t
      | _ -> Abstraction( List.rev qxs , e )

  (* -------------------------------------------------------------------------- *)
  (* --- Atom printer                                                       --- *)
  (* -------------------------------------------------------------------------- *)

  let rec pp_atom (env:env) (fmt:formatter) e =
    match out env e with
      | Atom x -> pp_print_string fmt x
      | Call(f,es) -> pp_call env fmt f es
      | Hbox(op,es) -> fprintf fmt "@[<hov 1>(%a)@]" (pp_hbox env op) es
      | Vbox(op,es) -> fprintf fmt "@[<hov 1>(%a)@]" (pp_vbox env op) es
      | Unop(op,e) -> fprintf fmt "@[<hov 3>(%s%a)@]" op (pp_atom env) e
      | Binop op -> fprintf fmt "@[<hov 3>(%a)@]" (pp_binop env) op
      | Cond c -> fprintf fmt "@[<hv 1>(%a)@]" (pp_cond env) c
      | Closure(e,es) -> pp_closure env fmt e es
      | Abstraction abs -> fprintf fmt "@[<v 1>(%a)@]" (pp_abstraction env) abs
      | Access(a,b) -> fprintf fmt "@[<hov 2>%a@,[%a]@]" 
	  (pp_atom env) a (pp_free env) b
      | Update(a,b,c) -> fprintf fmt "@[<hov 2>%a@,[%a@,->%a]@]" 
	  (pp_atom env) a (pp_atom env) b (pp_free env) c
      | GetField(e,f) -> fprintf fmt "%a.%a" (pp_atom env) e Field.pretty f
      | Record fs -> pp_fields env fmt fs

  and pp_fields (env:env) (fmt:formatter) fs =
    fprintf fmt "@[<hv 0>{@[<hv 2>" ;
    List.iter
      (function 
	 | With r ->
	     fprintf fmt "@ %a with" (pp_atom env) r
	 | Field (f,v) ->
	     fprintf fmt "@ @[<hov 2>%a =@ %a ;@]" Field.pretty f (pp_free env) v
	 | Last (f,v) ->
	     fprintf fmt "@ @[<hov 2>%a =@ %a@]" Field.pretty f (pp_free env) v	       
      ) fs ;
    fprintf fmt "@]@ }@]"

  (* -------------------------------------------------------------------------- *)
  (* --- Free printer                                                       --- *)
  (* -------------------------------------------------------------------------- *)

  and pp_free (env:env) (fmt:formatter) e =
    match out env e with
      | Atom x -> pp_print_string fmt x
      | Call(f,es) -> pp_call env fmt f es
      | Hbox(op,es) -> fprintf fmt "@[<hov 0>%a@]" (pp_hbox env op) es
      | Vbox(op,es) -> fprintf fmt "@[<hov 0>%a@]" (pp_vbox env op) es
      | Unop(op,e) -> fprintf fmt "@[<hov 2>%s%a@]" op (pp_atom env) e
      | Binop op -> fprintf fmt "@[<hov 2>%a@]" (pp_binop env) op
      | Cond c -> fprintf fmt "@[<hv 0>%a@]" (pp_cond env) c
      | Closure(e,es) -> pp_closure env fmt e es
      | Abstraction abs -> fprintf fmt "@[<hv 0>%a@]" (pp_abstraction env) abs
      | Access _ | Update _ | Record _ | GetField _ -> pp_atom env fmt e

  (* -------------------------------------------------------------------------- *)
  (* --- Call printer                                                       --- *)
  (* -------------------------------------------------------------------------- *)
	  
  and pp_call (env:env) (fmt:formatter) f = function
    | [] -> Fun.pretty fmt f
    | es -> 
	fprintf fmt "@[<hv 2>(%a" Fun.pretty f ;
	List.iter (fun e -> fprintf fmt "@ %a" (pp_atom env) e) es ;
	fprintf fmt ")@]"

  (* -------------------------------------------------------------------------- *)
  (* --- Horizonal Boxes                                                    --- *)
  (* -------------------------------------------------------------------------- *)

  and pp_hbox (env:env) (sep:string) (fmt:formatter) = function
    | [] -> ()
    | e::es ->
	pp_atom env fmt e ;
	List.iter (fun e -> fprintf fmt "%s@,%a" sep (pp_atom env) e) es

  (* -------------------------------------------------------------------------- *)
  (* --- Vertical Boxes                                                     --- *)
  (* -------------------------------------------------------------------------- *)

  and pp_vbox (env:env) (sep:string) (fmt:formatter) = function
    | [] -> ()
    | e::es -> 
	pp_atom env fmt e ;
	List.iter (fun e -> fprintf fmt "@ %s %a" sep (pp_atom env) e) es

  (* -------------------------------------------------------------------------- *)
  (* --- Specific Operators                                                 --- *)
  (* -------------------------------------------------------------------------- *)

  and pp_binop (env:env) (fmt:formatter) (a,op,b) =
    fprintf fmt "%a@ %s %a" (pp_atom env) a op (pp_atom env) b
      
  and pp_cond (env:env) (fmt:formatter) (c,a,b) =
    fprintf fmt "if %a@ then %a@ else %a" 
      (pp_atom env) c 
      (pp_atom env) a 
      (pp_atom env) b

  and pp_closure (env:env) (fmt:formatter) e es =
    fprintf fmt "@[<hov 3>(%a" (pp_atom env) e ;
    List.iter (fun e -> fprintf fmt "@ %a" (pp_atom env) e) es ;
    fprintf fmt ")@]"

  (* -------------------------------------------------------------------------- *)
  (* --- Abstraction                                                        --- *)
  (* -------------------------------------------------------------------------- *)

  and pp_abstraction (env:env) (fmt:formatter) (qxs,t) =
    let groups = group_binders qxs in
    List.iter
      (fun (q,m) ->
	 match q with
	   | Forall -> fprintf fmt "@[<hov 4>forall %a.@]@ " (pp_group env) m 
	   | Exists -> fprintf fmt "@[<hov 4>exists %a.@]@ " (pp_group env) m
	   | Lambda -> fprintf fmt "@[<hov 4>fun %a ->@]@ " (pp_group env) m
      ) groups ;
    pp_share env fmt t

  and pp_group (env:env) (fmt:formatter) m =
    let sep = ref false in
    TauMap.iter
      (fun t xs ->
	 if !sep then fprintf fmt ",@," ;
	 Plib.iteri
	   (fun idx x ->
	      let id = Plib.to_string Var.pretty x in
	      let a = fresh env (T.e_var x) ~id (Var.basename x) in
	      env.closed <- Vars.add x env.closed ;
	      match idx with
		| Isingle | Ifirst -> pp_print_string fmt a
		| Imiddle | Ilast -> fprintf fmt ",@,%s" a
	   ) (List.rev xs) ;
	 fprintf fmt ":%a" pp_tau t ;
	 sep := true ;
      ) m

  (* -------------------------------------------------------------------------- *)
  (* --- Sharing                                                            --- *)
  (* -------------------------------------------------------------------------- *)

  and pp_share (env:env) (fmt:formatter) t =
    begin
      fprintf fmt "@[<hv 0>" ;
      let ts = T.shared 
	~atomic:(fun t -> Tmap.mem t env.named) 
	~closed:env.closed [t] 
      in
      List.iter
	(fun t ->
	   let e0 = copy env in
	   let x = fresh env t (Kind.basename (T.sort t)) in
	   fprintf fmt "@[<hov 4>let %s =@ %a in@]@ " x (pp_atom e0) t
	) ts ;
      pp_free env fmt t ;
      fprintf fmt "@]" ;
    end

  (* -------------------------------------------------------------------------- *)
  (* --- Entry Point                                                        --- *)
  (* -------------------------------------------------------------------------- *)

  let pp_term (env:env) (fmt:formatter) t = pp_share (copy env) fmt t

end
