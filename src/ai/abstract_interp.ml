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

exception Not_less_than
exception Is_not_included

(** Generic lattice *)
module type Lattice = sig

  exception Error_Top
  exception Error_Bottom

  include Datatype.S (** datatype of element of the lattice *)

  type widen_hint (** hints for the widening *)

  val join: t -> t -> t (** over-approximation of union *)
  val link: t -> t -> t (** under-approximation of union *)
  val meet: t -> t -> t (** under-approximation of intersection *)
  val narrow: t -> t -> t (** over-approximation of intersection *)
  val bottom: t (** the smallest *)
  val top: t  (** the largest *)

  val is_included: t -> t -> bool
  val is_included_exn: t -> t -> unit
  val intersects: t -> t -> bool

  val widen: widen_hint -> t -> t -> t
    (** [widen h t1 t2] is an over-approximation of [join t1 t2].
        Assumes [is_included t1 t2] *)

  val cardinal_zero_or_one: t -> bool

  (** [cardinal_less_than t v ]
      @raise Not_less_than whenever the cardinal of [t] is higher than [v] *)
  val cardinal_less_than: t -> int -> int

  val tag : t -> int

end

module type Lattice_With_Diff = sig
  include Lattice
  val diff : t -> t -> t
    (** [diff t1 t2] is an over-approximation of [t1-t2]. *)
  val diff_if_one : t -> t -> t
    (** [diff t1 t2] is an over-approximation of [t1-t2].
       Returns [t1] if [t2] is not a singleton. *)
  val fold_enum :
    split_non_enumerable:int -> (t -> 'a -> 'a) -> t -> 'a -> 'a
  val splitting_cardinal_less_than:
    split_non_enumerable:int -> t -> int -> int
  val pretty_debug : Format.formatter -> t -> unit
end

module type Lattice_Product = sig
  type t1
  type t2
  type tt = private Product of t1*t2 | Bottom
  include Lattice with type t = tt
  val inject : t1 -> t2 -> t
  val fst : t -> t1
  val snd : t -> t2
end

module type Lattice_Sum = sig
  type t1
  type t2
  type sum = private Top | Bottom | T1 of t1 | T2 of t2
  include Lattice with type t = sum
  val inject_t1 : t1 -> t
  val inject_t2 : t2 -> t
end

module type Lattice_Base = sig
  type l
  type tt = private Top | Bottom | Value of l
  include Lattice with type t = tt
  val project : t -> l
  val inject: l -> t
  val transform: (l -> l -> l) -> tt -> tt -> tt
end

module type Lattice_Set = sig
  module O: Datatype.Set
  type tt = private Set of O.t | Top
  include Lattice with type t = tt and type widen_hint = O.t
  val inject_singleton: O.elt -> t
  val inject: O.t -> t
  val empty: t
  val apply2: (O.elt -> O.elt -> O.elt) -> (t -> t -> t)
  val apply1: (O.elt -> O.elt) -> (t -> t)
  val fold: ( O.elt -> 'a -> 'a) -> t -> 'a -> 'a
  val iter: ( O.elt -> unit) -> t -> unit
  val exists: (O.elt -> bool) -> t -> bool
  val for_all: (O.elt -> bool) -> t -> bool
  val project : t -> O.t
  val mem : O.elt -> t -> bool
end

module type LatValue = Datatype.S_with_collections

module Make_Lattice_Set(V:LatValue): Lattice_Set with type O.elt = V.t = struct

  exception Error_Top
  exception Error_Bottom

  module O = struct
    include Datatype.Set
      (Set.Make(V))
      (V)
      (struct let module_name = "Make_lattice_set" end)
  end

  type tt = Set of O.t | Top
  type widen_hint = O.t

  let bottom = Set O.empty
  let top = Top

  let hash c = match c with
    | Top -> 12373
    | Set s ->
        let f v acc =
          67 * acc + (V.hash v)
        in
        O.fold f s 17

  let tag = hash

  let compare =
    if O.compare == Datatype.undefined then (
      Kernel.debug "%s lattice_set, missing comparison function"
        V.name;
      Datatype.undefined
    ) else
      fun e1 e2 ->
        if e1 == e2 then 0
        else
          match e1,e2 with
            | Top,_ -> 1
            | _, Top -> -1
            | Set e1,Set e2 -> O.compare e1 e2

  let equal v1 v2 =
    if v1 == v2 then true
    else
      match v1, v2 with
        | Top, Top -> true
        | Set e1, Set e2 -> O.equal e1 e2
        | Top, Set _ | Set _, Top -> false

  let widen _wh _t1 t2 = (* [wh] isn't used *)
    t2

  (** This is exact *)
  let meet v1 v2 =
    if v1 == v2 then v1
    else
      match v1,v2 with
      | Top, v | v, Top -> v
      | Set s1 , Set s2 -> Set (O.inter s1 s2)

  (** This is exact *)
  let narrow = meet

  (** This is exact *)
  let join v1 v2 =
    if v1 == v2 then v1
    else
      match v1,v2 with
      | Top, _ | _, Top -> Top
      | Set s1 , Set s2 ->
          let u = O.union s1 s2 in
          Set u

  (** This is exact *)
  let link = join

  let cardinal_less_than s n =
    match s with
    | Top -> raise Not_less_than
    | Set s ->
        let c = O.cardinal s in
        if  c > n
        then raise Not_less_than;
        c

  let cardinal_zero_or_one s =
    try ignore (cardinal_less_than s 1) ; true
    with Not_less_than -> false

  let inject s = Set s
  let inject_singleton e = inject (O.singleton e)
  let empty = inject O.empty

  let transform f = fun t1 t2 ->
    match t1,t2 with
    | Top, _ | _, Top -> Top
    | Set v1, Set v2 -> Set (f v1 v2)

  let map_set f s =
    O.fold
      (fun v -> O.add (f v))
      s
      O.empty

  let apply2 f s1 s2 =
    let distribute_on_elements f s1 s2 =
      O.fold
        (fun v -> O.union (map_set (f v) s2))
        s1
        O.empty
    in
    transform (distribute_on_elements f) s1 s2

  let apply1 f s = match s with
    | Top -> top
    | Set s -> Set(map_set f s)

  let pretty fmt t =
    match t with
    | Top -> Format.fprintf fmt "TopSet"
    | Set s ->
      if O.is_empty s then Format.fprintf fmt "BottomSet"
      else
        Pretty_utils.pp_iter
          ~pre:"{"
          ~suf:"}"
          ~sep:";@ "
          O.iter
          (fun fmt v -> Format.fprintf fmt "@[%a@]" V.pretty v)
           fmt s

  let is_included t1 t2 =
    (t1 == t2) ||
      match t1,t2 with
      | _,Top -> true
      | Top,_ -> false
      | Set s1,Set s2 -> O.subset s1 s2

  let is_included_exn v1 v2 =
    if not (is_included v1 v2) then raise Is_not_included

  let intersects t1 t2 =
    let b = match t1,t2 with
      | _,Top | Top,_ -> true
      | Set s1,Set s2 ->
          O.exists (fun e -> O.mem e s2) s1
    in
    (* Format.printf
       "[Lattice_Set]%a intersects %a: %b @\n"
       pretty t1 pretty t2 b;*)
    b

  let fold f elt init = match elt with
    | Top -> raise Error_Top
    | Set v -> O.fold f v init


  let iter f elt = match elt with
    | Top -> raise Error_Top
    | Set v -> O.iter f v

  let exists f = function
    | Top -> true
    | Set s -> O.exists f s

  let for_all f = function
    | Top -> false
    | Set s -> O.for_all f s

  let project o = match o with
    | Top -> raise Error_Top
    | Set v -> v

  let mem v s = match s with
    | Top -> true
    | Set s -> O.mem v s

  include
    Datatype.Make
      (struct
         type t = tt
         let name = V.name ^ " lattice_set"
         let structural_descr =
           Structural_descr.Structure
             (Structural_descr.Sum [| [| O.packed_descr |] |])
         let reprs = Top :: List.map (fun o -> Set o) O.reprs
         let equal = equal
         let compare = compare
         let hash = tag
         let rehash = Datatype.identity
         let copy = Datatype.undefined
         let internal_pretty_code = Datatype.undefined
         let pretty = pretty
         let varname = Datatype.undefined
         let mem_project = Datatype.never_any_project
       end)

end

module Make_Hashconsed_Lattice_Set(V: Hptset.Id_Datatype)(O: Hptset.S with type elt = V.t)
  : Lattice_Set with type O.elt=V.t =
struct

  exception Error_Top
  exception Error_Bottom

  module O = O

  type tt = Set of O.t | Top
  type widen_hint = O.t

  let bottom = Set O.empty
  let top = Top

  let hash c = match c with
    | Top -> 12373
    | Set s ->
        let f v acc =
          67 * acc + (V.id v)
        in
        O.fold f s 17

  let tag = hash

  let equal e1 e2 =
    if e1==e2 then true
    else
      match e1,e2 with
      | Top,_ | _, Top -> false
      | Set e1,Set e2 -> O.equal e1 e2

  let compare =
    if O.compare == Datatype.undefined then (
      Kernel.debug "%s hashconsed_lattice_set, missing comparison function"
        V.name;
      Datatype.undefined
    ) else
      fun e1 e2 ->
        if e1 == e2 then 0
        else
          match e1,e2 with
            | Top,_ -> 1
            | _, Top -> -1
            | Set e1,Set e2 -> O.compare e1 e2


  let widen _wh _t1 t2 = (* [wh] isn't used *)
    t2

  (** This is exact *)
  let meet v1 v2 =
    if v1 == v2 then v1 else
      match v1,v2 with
      | Top, v | v, Top -> v
      | Set s1 , Set s2 -> Set (O.inter s1 s2)

  (** This is exact *)
  let narrow = meet

  (** This is exact *)
  let join v1 v2 =
    if v1 == v2 then v1 else
      match v1,v2 with
      | Top, _ | _, Top -> Top
      | Set s1 , Set s2 ->
          let u = O.union s1 s2 in
          Set u

  (** This is exact *)
  let link = join

  let cardinal_less_than s n =
    match s with
      Top -> raise Not_less_than
    | Set s ->
        let c = O.cardinal s in
        if  c > n
        then raise Not_less_than;
        c

  let cardinal_zero_or_one s =
    try
      ignore (cardinal_less_than s 1) ; true
    with Not_less_than -> false

  let inject s = Set s
  let inject_singleton e = inject (O.singleton e)
  let empty = inject O.empty

  let transform f = fun t1 t2 ->
    match t1,t2 with
      | Top, _ | _, Top -> Top
      | Set v1, Set v2 -> Set (f v1 v2)

  let map_set f s =
    O.fold
      (fun v -> O.add (f v))
      s
      O.empty

  let apply2 f s1 s2 =
    let distribute_on_elements f s1 s2 =
      O.fold
        (fun v -> O.union (map_set (f v) s2))
        s1
        O.empty
    in
    transform (distribute_on_elements f) s1 s2

  let apply1 f s = match s with
    | Top -> top
    | Set s -> Set(map_set f s)

  let pretty fmt t = match t with
    | Top -> Format.fprintf fmt "TopSet"
    | Set s ->
      if O.is_empty s then Format.fprintf fmt "BottomSet"
      else
        Pretty_utils.pp_iter
          ~pre:"@[<hov 1>{"
          ~suf:"}@]"
          ~sep:";@ "
          O.iter
          (fun fmt v -> Format.fprintf fmt "@[%a@]" V.pretty v)
           fmt s

  let is_included t1 t2 =
    (t1 == t2) ||
      match t1,t2 with
      | _,Top -> true
      | Top,_ -> false
      | Set s1,Set s2 -> O.subset s1 s2

  let is_included_exn v1 v2 =
    if not (is_included v1 v2) then raise Is_not_included

  let intersects t1 t2 =
    let b = match t1,t2 with
      | _,Top | Top,_ -> true
      | Set s1,Set s2 ->
          O.exists (fun e -> O.mem e s2) s1
    in
    (* Format.printf
       "[Lattice_Set]%a intersects %a: %b @\n"
       pretty t1 pretty t2 b;*)
    b

  let fold f elt init = match elt with
    | Top -> raise Error_Top
    | Set v -> O.fold f v init

  let iter f elt = match elt with
    | Top -> raise Error_Top
    | Set v -> O.iter f v

  let exists f = function
    | Top -> true
    | Set s -> O.exists f s

  let for_all f = function
    | Top -> false
    | Set s -> O.for_all f s

  let project o = match o with
    | Top -> raise Error_Top
    | Set v -> v

  let mem v s = match s with
    | Top -> true
    | Set s -> O.mem v s

  include Datatype.Make
      (struct
        type t = tt
        let name = V.name ^ " hashconsed_lattice_set"
        let structural_descr =
          Structural_descr.Structure
            (Structural_descr.Sum [| [| O.packed_descr |] |])
        let reprs = Top :: List.map (fun o -> Set o) O.reprs
        let equal = equal
        let compare = compare
        let hash = hash
        let rehash = Datatype.identity
        let copy = Datatype.undefined
        let internal_pretty_code = Datatype.undefined
        let pretty = pretty
        let varname = Datatype.undefined
        let mem_project = Datatype.never_any_project
       end)
  let () = Type.set_ml_name ty None

end

module Make_Pair = Datatype.Pair

module Make_Lattice_Base (V:LatValue):(Lattice_Base with type l = V.t) = struct

  type l = V.t
  type tt = Top | Bottom | Value of l
  type widen_hint = V.t list

  let bottom = Bottom
  let top = Top

  exception Error_Top
  exception Error_Bottom
  let project v = match v with
    | Top  -> raise Error_Top
    | Bottom -> raise Error_Bottom
    | Value v -> v


  let cardinal_zero_or_one v = match v with
    | Top  -> false
    | _ -> true

  let cardinal_less_than v n = match v with
    | Top  -> raise Not_less_than
    | Value _ -> if n >= 1 then 1 else raise Not_less_than
    | Bottom -> 0

  let compare =
    if V.compare == Datatype.undefined then
      (Kernel.debug "Missing function comparison for %s lattice_base"
         V.name;
       Datatype.undefined)
    else
      fun e1 e2 ->
        if e1==e2 then 0 else
          match e1,e2 with
            | Top,_ -> 1
            | _, Top -> -1
            | Bottom, _ -> -1
            | _, Bottom -> 1
            | Value e1,Value e2 -> V.compare e1 e2

  let equal v1 v2 = match v1, v2 with
    | Top, Top | Bottom, Bottom -> true
    | Value v1, Value v2 -> V.equal v1 v2
    | _ -> false

  let tag = function
    | Top -> 3
    | Bottom -> 5
    | Value v -> V.hash v * 7

  let widen _wh t1 t2 = (* [wh] isn't used yet *)
    if equal t1 t2 then t1 else top

  (** This is exact *)
  let meet b1 b2 =
    if b1 == b2 then b1 else
    match b1,b2 with
    | Bottom, _ | _, Bottom -> Bottom
    | Top , v | v, Top -> v
    | Value v1, Value v2 -> if (V.compare v1 v2)=0 then b1 else Bottom

  (** This is exact *)
  let narrow = meet

  (** This is exact *)
  let join b1 b2 =
    if b1 == b2 then b1 else
      match b1,b2 with
      | Top, _ | _, Top -> Top
      | Bottom , v | v, Bottom -> v
      | Value v1, Value v2 -> if (V.compare v1 v2)=0 then b1 else Top

  (** This is exact *)
  let link = join

  let inject x = Value x

  let transform f = fun t1 t2 ->
    match t1,t2 with
      | Bottom, _ | _, Bottom -> Bottom
      | Top, _ | _, Top -> Top
      | Value v1, Value v2 -> Value (f v1 v2)

  let pretty fmt t =
    match t with
      | Top -> Format.fprintf fmt "Top"
      | Bottom ->  Format.fprintf fmt "Bottom"
      | Value v -> Format.fprintf fmt "<%a>" V.pretty v

  let is_included t1 t2 =
    let b = (t1 == t2) ||
      (equal (meet t1 t2) t1)
    in
    (* Format.printf
       "[Lattice]%a is included in %a: %b @\n"
       pretty t1 pretty t2 b;*)
    b

  let is_included_exn v1 v2 =
    if not (is_included v1 v2) then raise Is_not_included

  let intersects t1 t2 = not (equal (meet t1 t2) Bottom)

  include Datatype.Make
  (struct
    type t = tt (*= Top | Bottom | Value of l*)
    let name = V.name ^ " lattice_base"
    let structural_descr =
      Structural_descr.Structure
        (Structural_descr.Sum [| [| V.packed_descr |] |])
    let reprs = Top :: Bottom :: List.map (fun v -> Value v) V.reprs
    let equal = equal
    let compare = compare
    let hash = tag
    let rehash = Datatype.identity
    let copy = Datatype.undefined
    let internal_pretty_code = Datatype.undefined
    let pretty = pretty
    let varname = Datatype.undefined
    let mem_project = Datatype.never_any_project
   end)
  let () = Type.set_ml_name ty None

end

module Int = struct
  include My_bigint.M
  include Datatype.Big_int

  let pretty fmt v =
    if not (Kernel.BigIntsHex.is_default ()) then
      let max = of_int (Kernel.BigIntsHex.get ()) in
      if gt (abs v) max then My_bigint.pretty ~hexa:true fmt v
      else My_bigint.pretty ~hexa:false fmt v
    else
      My_bigint.pretty ~hexa:false fmt v

  (** execute [f] on [inf], [inf + step], ... *)
  let fold f ~inf ~sup ~step acc =
(*    Format.printf "Int.fold: inf:%a sup:%a step:%a@\n"
       pretty inf pretty sup pretty step; *)
    let nb_loop = div (sub sup inf) step in
    let next = add step in
    let rec fold ~counter ~inf acc =
      if equal counter onethousand then
        Kernel.warning ~once:true ~current:true
          "enumerating %s integers" (to_string nb_loop);
      if le inf sup then begin
          (*          Format.printf "Int.fold: %a@\n" pretty inf; *)
        fold ~counter:(succ counter) ~inf:(next inf) (f inf acc)
      end else acc
    in
    fold ~counter:zero ~inf acc

end

module type Key = sig
  include Datatype.S
  val is_null : t -> bool
  val null : t
  val id : t -> int
end

module VarinfoSetLattice =
  Make_Hashconsed_Lattice_Set
    (struct include Cil_datatype.Varinfo let id v = v.Cil_types.vid end)
    (Cil_datatype.Varinfo.Hptset)

module LocationSetLattice = struct
  include Make_Lattice_Set(Cil_datatype.Location)
  let currentloc_singleton () = inject_singleton (Cil.CurrentLoc.get ())
end

module type Collapse = sig
  val collapse : bool
end

(** If [C.collapse] then [L1.Bottom,_ = _,L2.Bottom = Bottom] *)
module Make_Lattice_Product(L1:Lattice)(L2:Lattice)(C:Collapse):
  (Lattice_Product with type t1 =  L1.t and type t2 = L2.t) =
struct

  exception Error_Top
  exception Error_Bottom

  type t1 = L1.t
  type t2 = L2.t
  type tt = Product of t1*t2 | Bottom
  type widen_hint = L1.widen_hint * L2.widen_hint

  let tag = function
    | Bottom -> 3
    | Product(v1, v2) -> L1.tag v1 + 3 * L2.tag v2

  let cardinal_less_than _ = assert false

  let cardinal_zero_or_one v = match v with
    | Bottom -> true
    | Product (t1, t2) ->
        (L1.cardinal_zero_or_one t1) &&
          (L2.cardinal_zero_or_one t2)

  let compare =
    if L1.compare == Datatype.undefined || L2.compare == Datatype.undefined then (
      Kernel.debug "Missing comparison function for (%s, %s) lattice_product: \
                    %b %b"
        L1.name L2.name
        (L1.compare == Datatype.undefined) (L2.compare == Datatype.undefined);
      Datatype.undefined)
    else fun x x' ->
      if x == x' then 0 else
        match x,x' with
          | Bottom, Bottom -> 0
          | Bottom, Product _ -> 1
          | Product _,Bottom -> -1
          | (Product (a,b)), (Product (a',b')) ->
              let c = L1.compare a a' in
              if c = 0 then L2.compare b b' else c

  let equal x x' =
    if x == x' then true else
      match x,x' with
      | Bottom, Bottom -> true
      | Bottom, Product _ -> false
      | Product _,Bottom -> false
      | (Product (a,b)), (Product (a',b')) ->
          L1.equal a a' && L2.equal b b'

  let top = Product(L1.top,L2.top)

  let bottom = Bottom

  let fst x = match x with
    Bottom -> L1.bottom
  | Product(x1,_) -> x1

  let snd x = match x with
    Bottom -> L2.bottom
  | Product(_,x2) -> x2

  let condition_to_be_bottom x1 x2 =
    let c1 = (L1.equal x1 L1.bottom)  in
    let c2 = (L2.equal x2 L2.bottom)  in
    (C.collapse && (c1 || c2)) || (not C.collapse && c1 && c2)

  let inject x y =
    if condition_to_be_bottom x y
    then bottom
    else Product(x,y)

  let widen (wh1, wh2) t l =
    let t1 = fst t in
    let t2 = snd t in
    let l1 = fst l in
    let l2 = snd l in
    inject (L1.widen wh1 t1 l1) (L2.widen wh2 t2 l2)

  let join x1 x2 =
    if x1 == x2 then x1 else
      match x1,x2 with
      | Bottom, v | v, Bottom -> v
      | Product (l1,ll1), Product (l2,ll2) ->
          Product(L1.join l1 l2, L2.join ll1 ll2)

  let link _ = assert false (** Not implemented yet. *)

  let narrow _ = assert false (** Not implemented yet. *)

  let meet x1 x2 =
    if x1 == x2 then x1 else
    match x1,x2 with
    | Bottom, _ | _, Bottom -> Bottom
    | Product (l1,ll1), Product (l2,ll2) ->
        let l1 = L1.meet l1 l2 in
        let l2 = L2.meet ll1 ll2 in
        inject l1 l2

  let pretty fmt x =
    match x with
      Bottom ->
        Format.fprintf fmt "BotProd"
    | Product(l1,l2) ->
        Format.fprintf fmt "(%a,%a)" L1.pretty l1 L2.pretty l2

  let intersects  x1 x2 =
    match x1,x2 with
    | Bottom, _ | _, Bottom -> false
    | Product (l1,ll1), Product (l2,ll2) ->
        (L1.intersects l1 l2) && (L2.intersects ll1 ll2)

  let is_included x1 x2 =
    (x1 == x2) ||
    match x1,x2 with
    | Bottom, _ -> true
    | _, Bottom -> false
    | Product (l1,ll1), Product (l2,ll2) ->
        (L1.is_included l1 l2) && (L2.is_included ll1 ll2)

  let is_included_exn x1 x2 =
    if x1 != x2
    then
      match x1,x2 with
      | Bottom, _ -> ()
      | _, Bottom -> raise Is_not_included
      | Product (l1,ll1), Product (l2,ll2) ->
          L1.is_included_exn l1 l2;
          L2.is_included_exn ll1 ll2

  include Datatype.Make
      (struct
        type t = tt (*= Product of t1*t2 | Bottom*)
        let name = "(" ^ L1.name ^ ", " ^ L2.name ^ ") lattice_product"
        let structural_descr =
          Structural_descr.Structure
            (Structural_descr.Sum [| [| L1.packed_descr; L2.packed_descr |] |])
        let reprs =
          Bottom ::
            List.fold_left
            (fun acc l1 ->
              List.fold_left
                (fun acc l2 -> Product(l1, l2) :: acc) acc L2.reprs)
            []
            L1.reprs
        let equal = equal
        let compare = compare
        let hash = tag
        let rehash = Datatype.identity
        let copy = Datatype.undefined
        let internal_pretty_code = Datatype.undefined
        let pretty = pretty
        let varname = Datatype.undefined
        let mem_project = Datatype.never_any_project
       end)
  let () = Type.set_ml_name ty None

end

module Make_Lattice_Sum (L1:Lattice) (L2:Lattice):
  (Lattice_Sum with type t1 = L1.t and type t2 = L2.t)
  =
struct
  exception Error_Top
  exception Error_Bottom
  type t1 = L1.t
  type t2 = L2.t
  type sum = Top | Bottom | T1 of t1 | T2 of t2
  type widen_hint = L1.widen_hint * L2.widen_hint

  let top = Top
  let bottom = Bottom

  let tag = function
    | Top -> 3
    | Bottom -> 5
    | T1 t -> 7 * L1.tag t
    | T2 t -> - 17 * L2.tag t

  let cardinal_less_than _ = assert false

  let cardinal_zero_or_one v = match v with
    | Top  -> false
    | Bottom -> true
    | T1 t1 -> L1.cardinal_zero_or_one t1
    | T2 t2 -> L2.cardinal_zero_or_one t2

  let widen (wh1, wh2) t1 t2 =
    match t1,t2 with
      | T1 x,T1 y ->
          T1 (L1.widen wh1 x y)
      | T2 x,T2 y ->
          T2 (L2.widen wh2 x y)
      | Top,Top | Bottom,Bottom -> t1
      | _,_ -> Top

  let compare =
    if L1.compare == Datatype.undefined || L2.compare == Datatype.undefined then (
      Kernel.debug "Missing comparison function for (%s, %s) lattice_sum: \
                    %b %b"
        L1.name L2.name
        (L1.compare == Datatype.undefined) (L2.compare == Datatype.undefined);
      Datatype.undefined)
    else fun u v ->
      if u == v then 0 else
        match u,v with
          | Top,Top | Bottom,Bottom -> 0
          | Bottom,_ | _,Top -> 1
          | Top,_ |_,Bottom -> -1
          | T1 _ , T2 _ -> 1
          | T2 _ , T1 _ -> -1
          | T1 t1,T1 t1' -> L1.compare t1 t1'
          | T2 t1,T2 t1' -> L2.compare t1 t1'

  let equal u v =
    if u == v then false
    else
      match u, v with
        | Top,Top | Bottom,Bottom -> true
        | Bottom,_ | _,Top | Top,_ |_,Bottom -> false
        | T1 _ , T2 _ -> false
        | T2 _ , T1 _ -> false
        | T1 t1,T1 t1' -> L1.equal t1 t1'
        | T2 t2,T2 t2' -> L2.equal t2 t2'

  (** Forbid [L1 Bottom] *)
  let inject_t1 x =
    if L1.equal x L1.bottom then Bottom
    else T1 x

  (** Forbid [L2 Bottom] *)
  let inject_t2 x =
    if L2.equal x L2.bottom then Bottom
    else T2 x

  let pretty fmt v =
    match v with
      | T1 x -> L1.pretty fmt x
      | T2 x -> L2.pretty fmt x
      | Top -> Format.fprintf fmt "<TopSum>"
      | Bottom -> Format.fprintf fmt "<BottomSum>"

  let join u v =
    if u == v then u else
      match u,v with
      | T1 t1,T1 t2 -> T1 (L1.join t1 t2)
      | T2 t1,T2 t2 -> T2 (L2.join t1 t2)
      | Bottom,x| x,Bottom -> x
      | _,_ ->
          (*Format.printf
            "Degenerating collision : %a <==> %a@\n" pretty u pretty v;*)
          top

  let link _ = assert false (** Not implemented yet. *)

  let narrow _ = assert false (** Not implemented yet. *)

  let meet u v =
    if u == v then u else
    match u,v with
      | T1 t1,T1 t2 -> inject_t1 (L1.meet t1 t2)
      | T2 t1,T2 t2 -> inject_t2 (L2.meet t1 t2)
      | (T1 _ | T2 _),Top -> u
      | Top,(T1 _ | T2 _) -> v
      | Top,Top -> top
      | _,_ -> bottom

  let intersects u v =
    match u,v with
      | Bottom,_ | _,Bottom -> false
      | Top,_ |_,Top -> true
      | T1 _,T1 _ -> true
      | T2 _,T2 _ -> true
      | _,_ -> false

  let is_included u v =
    (u == v) ||
    let b = match u,v with
    | Bottom,_ | _,Top -> true
    | Top,_ | _,Bottom -> false
    | T1 t1,T1 t2 -> L1.is_included t1 t2
    | T2 t1,T2 t2 -> L2.is_included t1 t2
    | _,_ -> false
    in
    (* Format.printf
      "[Lattice_Sum]%a is included in %a: %b @\n" pretty u pretty v b;*)
    b

  let is_included_exn v1 v2 =
    if not (is_included v1 v2) then raise Is_not_included

  include Datatype.Make
  (struct
    type t = sum
    let name = "(" ^ L1.name ^ ", " ^ L2.name ^ ") lattice_sum"
    let structural_descr = Structural_descr.Unknown
    let reprs =
      Top :: Bottom
      :: List.fold_left
        (fun acc t -> T2 t :: acc) (List.map (fun t -> T1 t) L1.reprs) L2.reprs
    let equal = equal
    let compare = compare
    let hash = tag
    let rehash = Datatype.undefined
    let copy = Datatype.undefined
    let internal_pretty_code = Datatype.undefined
    let pretty = pretty
    let varname = Datatype.undefined
    let mem_project = Datatype.never_any_project
   end)
  let () = Type.set_ml_name ty None

end

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
