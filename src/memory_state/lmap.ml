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

open Abstract_interp
open Locations
open CilE

module type Location_map = sig

  type y
  type loffset
  type widen_hint_y

    module LBase :
    sig
      type t
      val iter : (Base.base -> loffset -> unit) -> t -> unit
    end
    type tt = private Bottom | Top | Map of LBase.t
    include Datatype.S_with_collections with type t = tt

    type widen_hint = bool * Base.Set.t * (Base.t -> widen_hint_y)

    val inject : Base.t -> loffset -> t

    val add_offsetmap :  Base.t -> loffset -> t -> t

    val pretty_without_null : Format.formatter -> t -> unit
    val pretty_filter :
      Format.formatter -> t -> Zone.t -> (Base.t -> bool) -> unit

    val add_binding :
      with_alarms:CilE.warn_mode -> exact:bool -> t -> location -> y -> t

    val find :
      conflate_bottom:bool -> with_alarms:CilE.warn_mode -> t -> location -> y

    val join : t -> t -> location list *  t
    val is_included : t -> t -> bool

    val top: t
    val is_top: t -> bool

    (** Empty map. Casual users do not need this.*)
    val empty_map : t
    val is_empty_map : t -> bool

    (** Every location is associated to [VALUE.bottom] in [bottom].
        This state can be reached only in dead code. *)
    val bottom : t
    val is_reachable : t -> bool

    val widen : widen_hint-> t -> t -> (bool * t)

    val filter_base : (Base.t -> bool) -> t -> t

    (** @raise [Not_found] if the varid is not present in the map *)
    val find_base : Base.t -> t -> loffset

    val find_base_or_default : Base.t -> t -> loffset

    val remove_base : Base.t -> t -> t

    val reduce_previous_binding :
      with_alarms:CilE.warn_mode -> t -> location -> y -> t
    val reduce_binding : 
      with_alarms:CilE.warn_mode -> t -> location -> y -> t

(*
    val copy_paste :
      with_alarms:CilE.warn_mode -> location -> location -> t -> t
*)

    val paste_offsetmap :
      with_alarms:CilE.warn_mode ->
      from:loffset ->
      dst_loc:Location_Bits.t ->
      start:Int.t ->
      size:Int.t ->
      exact:bool ->
      t -> t

    val copy_offsetmap :
      with_alarms:CilE.warn_mode -> location -> t -> loffset option

    val is_included_by_location_enum :  t -> t -> Zone.t -> bool

    (* @raise [Invalid_argument "Lmap.fold"] if one location is not aligned
       or of size different of [size]. *)
    val fold: size:Int.t -> (location -> y -> 'a -> 'a) -> t -> 'a -> 'a

    (** @raise [Invalid_argument "Lmap.fold"] if one location is not aligned
        or of size different of [size]. *)
    val fold_single_bindings:
      size:Int.t -> (location -> y -> 'a -> 'a) -> t -> 'a -> 'a

    (** [fold_base f m] calls [f] on all bases bound to non top offsetmaps in
        the non bottom map [m].
        @raise [Error_Bottom] if [m] is bottom.*)
    val fold_base : (Base.t -> 'a -> 'a) -> t -> 'a -> 'a

    (** [fold_base_offsetmap f m] calls [f] on all bases bound to non top
        offsetmaps in the non bottom map [m].
        @raise [Error_Bottom] if [m] is bottom.*)
    val fold_base_offsetmap : (Base.t -> loffset -> 'a -> 'a) -> t -> 'a -> 'a

    val find_offsetmap_for_location : Location_Bits.t -> t -> loffset

    val comp_prefixes: t -> t -> unit
    type subtree
    val find_prefix : t -> Hptmap.prefix -> subtree option
    val hash_subtree : subtree -> int
    val equal_subtree : subtree -> subtree -> bool

    (** [reciprocal_image m b] is the set of bits in the map [m] that may lead
        to Top([b]) and  the location in [m] where one may read an address
        [b]+_ *)
    val reciprocal_image : Base.t -> t -> Zone.t*Location_Bits.t

    val create_initial :
      base:Base.t ->
      v:y ->
      modu:Int.t ->
      state:t -> t

    exception Error_Bottom

    val cached_fold :
      f:(Base.t -> loffset -> 'a) ->
      cache:string * int ->    temporary:bool ->
      joiner:('a -> 'a -> 'a) -> empty:'a -> t -> 'a

    val cached_map :
      f:(Base.t -> loffset -> loffset) ->
      cache:string * int -> temporary:bool ->
      t -> t

    exception Found_prefix of Hptmap.prefix * subtree * subtree

end

module Make_LOffset
  (V: Lattice_With_Isotropy.S)
  (LOffset: Offsetmap.S with type y = V.t and type widen_hint = V.widen_hint)
  (Default_offsetmap: sig val default_offsetmap : Base.t -> LOffset.t end)
  =
struct

  type y = V.t
  type loffset = LOffset.t
  type widen_hint_y = V.widen_hint

    open Default_offsetmap

    module LBase =  struct

      module Comp =
        struct
          let f base offsetmap =
            match Base.validity base with
              Base.Known (b, e) | Base.Unknown (b, e) when
                  Int.lt (Int.sub e b) Int.onethousand ->
                    LOffset.cardinal_zero_or_one (Base.validity base) offsetmap
            | Base.Known _ | Base.Unknown _
            | Base.Periodic _ | Base.All -> false

          let compose a b = a && b
          let e = true
          let default = true
        end

      module Initial_Values = struct let v = [ [] ] end

      include Hptmap.Make
      (Base)
      (LOffset)
      (Comp)
      (Initial_Values)
      (struct let l = [ Ast.self ] end)
      let () = Ast.add_monotonic_state self


      let add k v m =
        if LOffset.equal v (default_offsetmap k) then
          remove k m
        else add k v m

      let find_or_default varid map =
        try
          find varid map
        with Not_found -> default_offsetmap varid
    end

    exception Found_prefix = LBase.Found_prefix

    type tt =
      | Bottom
      | Top
      | Map of LBase.t

    let equal m1 m2 =
      match m1, m2 with
      | Bottom, Bottom -> true
      | Top, Top -> true
      | Map m1, Map m2 -> m1 == m2
      | _ -> false

    let comp_prefixes m1 m2 =
      match m1, m2 with
      | Map m1, Map m2 -> LBase.comp_prefixes m1 m2
      | _ -> ()

    type subtree = LBase.subtree
    let find_prefix m p =
      match m with
        Map m -> LBase.find_prefix m p
      | Top | Bottom -> None
    let equal_subtree = LBase.equal_subtree
    let hash_subtree = LBase.hash_subtree

    let compare =
      if LBase.compare == Datatype.undefined then Datatype.undefined
      else
        fun m1 m2 -> match m1, m2 with
          | Bottom, Bottom | Top, Top -> 0
          | Map m1, Map m2 -> LBase.compare m1 m2
          | Bottom, (Top | Map _) | Top, Map _ -> -1
          | Map _, (Top | Bottom) | Top, Bottom -> 1

    let empty_map = Map LBase.empty

    let hash = function
      | Bottom -> 457
      | Top -> 458
      | Map m -> LBase.tag m

    let pretty fmt m =
      Format.fprintf fmt "@[";
      (match m with
        Bottom -> Format.fprintf fmt "NOT ACCESSIBLE"
       | Map m ->
           LBase.iter
             (fun base offs ->
                let typ = Base.typeof base in
                  Format.fprintf fmt "@[%a@[%a@]@\n@]" Base.pretty base
                    (LOffset.pretty_typ typ) offs)
             m
       | Top -> Format.fprintf fmt "NO INFORMATION");
      Format.fprintf fmt "@]"

    include Datatype.Make_with_collections
        (struct
          type t = tt
          let structural_descr =
            Structural_descr.Structure
              (Structural_descr.Sum [| [| LBase.packed_descr |] |])
          let name = LOffset.name ^ " lmap"
          let reprs = Bottom :: Top :: List.map (fun b -> Map b) LBase.reprs
          let equal = equal
          let compare = compare
          let hash = hash
          let pretty = pretty
          let internal_pretty_code = Datatype.undefined
          let rehash = Datatype.identity
          let copy = Datatype.undefined
          let varname = Datatype.undefined
          let mem_project = Datatype.never_any_project
         end)
    let () = Type.set_ml_name ty None

    let top = Top
    let bottom = Bottom
    let is_top x = equal top x

    exception Error_Bottom

    let add_offsetmap base offsetmap acc =
      match acc with
      | Map acc -> Map (LBase.add base offsetmap acc)
      | Bottom -> raise Error_Bottom
      | Top -> Top

    let inject base offsetmap =
      add_offsetmap base offsetmap empty_map

    let is_empty_map = function
        Bottom -> assert false
      | Top -> assert false
      | Map m -> LBase.is_empty m

  let filter_base f m =
    match m with
      Top -> Top
    | Bottom -> assert false
    | Map m ->
        Map
          (LBase.fold
             (fun k v acc -> if f k then LBase.add k v acc else acc)
             m
             LBase.empty)

  let find_base (vi:LBase.key) (m:t) =
    match m with
      | Bottom -> raise Not_found
      | Map m -> LBase.find vi m
      | Top -> LOffset.empty

  let remove_base (vi:LBase.key) (m:t) =
    match m with
    | Bottom -> m
    | Map m -> Map (LBase.remove vi m)
    | Top -> assert false

  let is_reachable t =
    match t with
      Bottom -> false
    | Top | Map _ -> true

  let pretty_without_null fmt m =
    Format.fprintf fmt "@[";
    (match m with
      Bottom -> Format.fprintf fmt "NOT ACCESSIBLE"
    | Top -> Format.fprintf fmt "NO INFORMATION"
    | Map m ->
         LBase.iter
           (fun base offs ->
              if not (Base.is_null base) then
                Format.fprintf fmt "@[%a@[%a@]@\n@]" Base.pretty base
                  (LOffset.pretty_typ (Base.typeof base)) offs)
           m);
    Format.fprintf fmt "@]"


  (* Display bases in [filter]. *)
  let pretty_filter fmt mm filter refilter =
    Format.fprintf fmt "@[";
    (match mm with
     | Bottom -> Format.fprintf fmt "NON TERMINATING FUNCTION"
     | Top -> Format.fprintf fmt "NO INFORMATION"
     | Map m ->
         let filter_it base _itvs () =
           if refilter base
           then
             let offsm = LBase.find_or_default base m in
	     if not (LOffset.is offsm V.bottom)
	     then
               Format.fprintf fmt "@[%a@[%a@]@\n@]"
		 Base.pretty base
		 (LOffset.pretty_typ (Base.typeof base)) offsm
         in
         try
           Zone.fold_topset_ok filter_it filter ()
         with Zone.Error_Top ->
             Format.fprintf fmt
               "Cannot filter: dumping raw memory (including unchanged variables)@\n%a@\n"
               pretty mm
         );
    Format.fprintf fmt "@]"


  let add_binding_offsetmap ~reducing ~with_alarms ~exact varid offsets size v map =
    if (not reducing) && (Base.is_read_only varid)
    then raise Offsetmap.Result_is_bottom;
    match size with
      | Int_Base.Top ->
          let offsetmap_orig = LBase.find_or_default varid map in
          let new_offsetmap =
            LOffset.overwrite offsetmap_orig v
              (Origin.Arith (LocationSetLattice.currentloc_singleton()))
          in
          if offsetmap_orig == new_offsetmap then map
          else LBase.add varid new_offsetmap map

      | Int_Base.Bottom -> assert false
      | Int_Base.Value size ->
          assert (Int.gt size Int.zero);
          let offsetmap_orig = LBase.find_or_default varid map in
          (*Format.printf "add_binding_offsetmap varid:%a offset:%a@\n"
            Base.pretty varid
            Ival.pretty
            offsets;*)
          let validity = Base.validity varid in
          begin
            match validity with
            | Base.Unknown _ -> CilE.warn_mem_write with_alarms
            | _ -> ()
          end;
          let new_offsetmap =
            LOffset.update_ival ~with_alarms ~validity
              ~exact ~offsets ~size offsetmap_orig v
          in
          if offsetmap_orig == new_offsetmap then map
          else LBase.add varid new_offsetmap map

  let create_initial ~base ~v ~modu ~state =
    match state with
    | Bottom -> state
    | Top -> state
    | Map mem ->
        Map (LBase.add base (LOffset.create_initial ~v ~modu) mem)

  let add_binding ~reducing ~with_alarms ~exact initial_mem {loc=loc ; size=size } v =
    (*Format.printf "add_binding: loc:%a@\n" Location_Bits.pretty loc;*)
    if V.equal v V.bottom then Bottom else
      match initial_mem with
      | Top -> initial_mem
      | Bottom -> assert false
      | Map mem ->
          let result =
            (match loc with
             | Location_Bits.Top (Location_Bits.Top_Param.Top, orig) ->
                 (match with_alarms.imprecision_tracing with
                  | Aignore -> ()
                  | Acall f -> f ()
                  | Alog _ ->
                    Kernel.warning ~current:true ~once:true
                      "writing at a completely unknown address @[%a@]@\n\
                        Aborting." Origin.pretty_as_reason orig
                 );
                 warn_mem_write with_alarms;
                 (* Format.printf "dumping memory : %a@\n" pretty initial_mem;*)
                 top (* the map where every location maps to top *)
             | Location_Bits.Top (Location_Bits.Top_Param.Set set, origin) ->
                 warn_mem_write with_alarms;
                 let treat_base varid acc =
                   if (not reducing) && (Base.is_read_only varid)
                   then acc
                   else
                     match Base.validity varid with
                     | (Base.Known (b,e)|Base.Unknown (b,e)) when Int.lt e b ->
                         acc
                     | Base.Unknown _ | Base.Known _ | Base.Periodic _
                     | Base.All ->
                         let offsetmap = LBase.find_or_default varid mem in
                         let offsetmap =
                           LOffset.overwrite offsetmap v origin
                         in
                         LBase.add varid offsetmap acc
                 in
                 let result =
                   Map (Location_Bits.Top_Param.O.fold treat_base set
                           (treat_base Base.null mem))
                 in
 (* Format.printf "debugging add_binding topset, loc =%a, result=%a@."
                                Location_Bits.pretty loc
                                pretty result; *)
                 result
             | Location_Bits.Map loc_map ->
                 (* Format.printf "add_binding size:%a@\n"
                    Int_Base.pretty size;*)
                 let had_non_bottom = ref false in
                 let result = Location_Bits.M.fold
                   (fun varid offsets map ->
                      try
                        let r =
                          add_binding_offsetmap ~reducing
                            ~with_alarms
                            ~exact
                            varid
                            offsets
                            size
                            v
                            map
                        in
                        had_non_bottom := true;
                        r
                      with Offsetmap.Result_is_bottom ->
                        CilE.warn_mem_write with_alarms;
                        map)
                   loc_map
                   mem
                 in
                 if !had_non_bottom
                 then Map result
                 else begin
                   (match with_alarms.imprecision_tracing with
                      (* another field would be appropriate here TODO *)
                    | Aignore -> ()
                    | Acall f -> f ()
                    | Alog _ ->
                      Kernel.warning ~current:true ~once:true
                        "all target addresses were invalid. This path is \
assumed to be dead.");
                   bottom
                 end)
          in
          result

  let find_base_or_default base mem =
    match mem with
      Map mem -> LBase.find_or_default base mem
    | Top -> LOffset.empty
    | Bottom -> assert false 

  let find ~conflate_bottom ~with_alarms mem { loc = loc ; size = size } =
    let result =
      match mem with
      | Bottom -> V.bottom
      | Top | Map _ ->
          let handle_imprecise_base base acc =
            let validity = Base.validity base in
            begin
              match validity with
              | Base.All -> ()
              | Base.Known _ | Base.Unknown _ | Base.Periodic _ ->
                  CilE.warn_mem_read with_alarms
            end;
            let offsetmap = find_base_or_default base mem in
            let new_v =
              LOffset.find_imprecise_entire_offsetmap
                ~validity
                offsetmap
            in
            V.join new_v acc
          in
          begin match loc with
          |  Location_Bits.Top (topparam,_orig) ->
               assert (size <> Int_Base.bottom);
               begin try
                   Location_Bits.Top_Param.fold
                     handle_imprecise_base
                     topparam
                     (handle_imprecise_base Base.null V.bottom)
                 with Location_Bits.Top_Param.Error_Top -> V.top
               end
          | Location_Bits.Map loc_map ->
              begin match size with
              | Int_Base.Bottom -> V.bottom
              | Int_Base.Top ->
                  begin try
                      Location_Bits.M.fold
                        (fun base _offsetmap acc ->
                          handle_imprecise_base base acc)
                        loc_map
                        V.bottom
                    with Location_Bits.Top_Param.Error_Top -> V.top
                  end
              | Int_Base.Value size ->
                  Location_Bits.M.fold
                    (fun base offsets acc ->
                      let validity = Base.validity base in
                      begin
                        match validity with
                        | Base.Unknown _ -> CilE.warn_mem_read with_alarms
                        | _ -> ()
                      end;
                      let offsetmap = find_base_or_default base mem in
                      (*Format.printf "offsetmap(%a):%a@\noffsets:%a@\nsize:%a@\n"
                        Base.pretty base
                        (LOffset.pretty None) offsetmap
                        Ival.pretty offsets
                        Int.pretty size;*)
                      let new_v =
                        LOffset.find_ival
                          ~conflate_bottom
                          ~validity
                          ~with_alarms
                          offsets
                          offsetmap
                          size
                      in
                      (* Format.printf "find got:%a@\n" V.pretty new_v; *)
                      V.join new_v acc)
                    loc_map
                    V.bottom
              end
          end
    in
    result

  let reduce_previous_binding ~with_alarms initial_mem l v =
    assert
      (if not (Locations.valid_cardinal_zero_or_one ~for_writing:false l)
        then begin
            Format.printf "Internal error 835; debug info:@\n%a@."
              Locations.pretty l;
            false
          end
        else
          true);
    add_binding ~reducing:true ~exact:true ~with_alarms initial_mem l v


(* XXXXXXXXX bug with uninitialized values ? *)
  let reduce_binding ~with_alarms initial_mem l v =
    let v_old = find ~conflate_bottom:true ~with_alarms initial_mem l in
    if V.equal v v_old
    then initial_mem
    else
      let vv = V.narrow v_old v in
(* Format.printf "narrow %a %a %a@." V.pretty v_old V.pretty v V.pretty vv; *)
      if V.equal vv v_old then initial_mem
      else reduce_previous_binding ~with_alarms initial_mem l vv

(*
  let reduce_previous_binding ~with_alarms initial_mem l v = 
    let s1 = reduce_previous_binding ~with_alarms initial_mem l v in
    let s2 = reduce_binding ~with_alarms initial_mem l v in
    if not (equal s1 s2)
    then
      Format.printf "DIFF@\n%a@\n@\n%a@\n@\n%a@."
	V.pretty v
	pretty s1
	pretty s2;
    s1
*)

  let add_binding = add_binding ~reducing:false



(*
  let concerned_bindings mem { loc = loc ; size = size } =
    let result =
      match mem with
      | None -> []
      | Some mem ->
          match loc with
          |  Location_Bits.Top _ ->
               LBase.fold
                 (fun _varid offsetmap acc ->
                    LOffset.concerned_bindings_ival
                      ~offsetmap ~offsets:Ival.top ~size:Int.one acc)
                 mem
                 []
          | Location_Bits.Map loc_map ->
              Location_Bits.M.fold
                (fun varid offsets acc ->
                   let offsets,size =
                     match size with
                     | Int_Base.Top -> Ival.top,Int.one
                     | Int_Base.Bottom -> assert false
                     | Int_Base.Value size -> offsets,size
                   in
                     let offsetmap = LBase.find_or_default varid mem in
                     LOffset.concerned_bindings_ival
                       ~offsetmap ~offsets ~size acc)
                loc_map
                []
    in result
*)
  let join_internal =
    let decide_none base v1 =
        (LOffset.join v1 (default_offsetmap base))
    in
    let decide_some v1 v2 =
        (LOffset.join v1 v2)
    in
    let symetric_merge =
      LBase.symetric_merge ~cache:("lmap",65536) ~decide_none ~decide_some in
    fun m1 m2 ->
      [], Map (symetric_merge m1 m2)

  let join  mm1 mm2 =
 (*   Format.printf "lmap join@." ; *)
    let result =
      match mm1, mm2 with
        Bottom,m | m,Bottom -> [], m
      | Top, _ | _, Top -> [], Top
      | Map m1, Map m2 ->
          if m1 == m2
          then [], mm1
          else
            let r = join_internal m1 m2 in
            r
    in
(*    Format.printf "lmap.join %a %a -ZZZZ-> %a@."
      pretty mm1
      pretty mm2
      pretty result;*)
    result

let is_included =
  let decide_fst base v1 =
    LOffset.is_included_exn v1 (default_offsetmap base)
  in
  let decide_snd base v2 =
    LOffset.is_included_exn (default_offsetmap base) v2
  in
  let decide_both = LOffset.is_included_exn
  in
  let generic_is_included =
    LBase.generic_is_included Abstract_interp.Is_not_included
      ~cache:("lmap", 16384)
      ~decide_fst ~decide_snd ~decide_both
  in
  fun (m1:t) (m2:t) ->
    match m1,m2 with
      Bottom,_ -> true | _,Bottom -> false
    |   _, Top -> true | Top, _ -> false
    | Map m1,Map m2 ->
        try
          generic_is_included m1 m2;
          true
        with
          Is_not_included -> false

  let find_offsetmap_for_location loc m =
    let result = try
      match m with
        | Bottom -> assert false
        | Top -> (* TODO *) assert false
        | Map m ->
            Extlib.the
              (Location_Bits.fold_i
                 (fun varid offsets acc ->
                    LOffset.shift_ival
                      (Ival.neg offsets)
                      (LBase.find_or_default varid m)
                      acc)
                 loc
                 None)
    with
      | Location_Bits.Error_Top (* from [LocBits.fold] *)
      | Offsetmap.Found_Top (* from [LOffset.shift_ival] *)
        -> LOffset.empty
    in
    (*Format.printf "find_offsetmap_for_location:%a@\nLEADS TO %a@\n"
      Location_Bits.pretty loc
      (LOffset.pretty None) result;*)
    result

  let is_included_by_location_enum m1 m2 locs =
    if Zone.equal locs Zone.bottom  then true
    else match locs with
      | Zone.Top _ -> is_included m1 m2
      | Zone.Map locs ->
          match m1, m2 with
          | Top, _ | _, Top -> assert false
            | Bottom ,_ -> assert false
            | _, Bottom -> assert false
            | Map m1, Map m2 ->
                let treat_offset varid offs2  =
                  try
                    ignore (Zone.find_or_bottom varid locs);
                    (* at this point varid is present in locs *)
                      let offs1 = LBase.find_or_default varid m1
                      in LOffset.is_included_exn offs1 offs2
                  with Not_found -> () (* varid not in locs *)
                in
                try
                  LBase.iter treat_offset m2;
                  true
                with
                  Is_not_included -> false

  (* Precondition : m1 <= m2 *)
  type widen_hint = bool * Base.Set.t * (Base.t -> V.widen_hint)
  let widen (widen_other_keys, wh_key_set, wh_hints) r1 r2 =
    let result =
      match r1,r2 with
      | Top, _ | _, Top -> assert false
    | Bottom,Bottom -> false, Bottom
    | _,Bottom -> assert false (* thanks to precondition *)
    | Bottom, m -> false, m
    | Map m1,Map m2 ->
        let m_done, m_remain =
          (* [m_done] = widened state on keys of [wh_key_set].
             if a widening is performed for one of them,
             [m_remain] will be empty.
          *)
          Base.Set.fold
            (fun key (m_done, m_remain) ->
               let offs2 = LBase.find_or_default key m2 in
               let offs1 = LBase.find_or_default key m1 in
               let fixed = LOffset.is_included offs2 offs1 in
                 (* Format.printf "key=%a, fixed=%b@."
                    Base.pretty key fixed; *)
                 if fixed
                 then (m_done, LBase.remove key m_remain)
                 else
                   let new_off = LOffset.widen (wh_hints key) offs1 offs2
                   in
                     LBase.add key new_off m_done, LBase.empty)
            wh_key_set
            (m2, m2)
        in
        let fixed_for_all_wh_key = not (LBase.is_empty m_remain) in
          (* Format.printf "widening (widen_other_keys=%b, fixed_for_all_wh_key %b)@."
            widen_other_keys fixed_for_all_wh_key; *)
        if widen_other_keys
          then
            let other_keys_widened =
              Map
                (LBase.fold
                   (fun base offs2 acc ->
                      (* Format.printf "widening also on key %a@."
                        Base.pretty base; *)
                        let offs1 = LBase.find_or_default base m1 in
                        let new_off =
                          LOffset.widen (wh_hints base) offs1 offs2
                        in               
                        if offs2 != new_off then LBase.add base new_off acc
                        else acc
                   )
                   m_remain
                   m_done)
            in
              true, other_keys_widened
          else
            fixed_for_all_wh_key, Map m_done
        in
    result

  let paste_offsetmap ~with_alarms ~from:map_to_copy ~dst_loc ~start ~size ~exact m =
    let dst_loc' = Locations.make_loc dst_loc (Int_Base.inject size) in
    match m with
    | Bottom | Top -> m
    | Map m' ->
        assert (Int.lt Int.zero size);
        let dst_is_exact =
          exact && valid_cardinal_zero_or_one ~for_writing:true dst_loc'
        in
        (* TODO: if the destination is not exact but the write do not overlap
           (see below), performing a unique join once after all the paste
           is much more efficient *)
        let op =
	  if dst_is_exact
	  then LOffset.copy_paste
          else LOffset.copy_merge 
	in
        let stop = Int.pred (Int.add start size) in
        (* Value to paste if we cannot be precise *)
        let v = lazy (LOffset.find_ival ~with_alarms
                        ~validity:Base.All ~conflate_bottom:false
                        (Ival.inject_singleton start) map_to_copy size) in
        let had_non_bottom = ref false in
	let plevel = !Lattice_Interval_Set.plevel in
        let treat_dst base_dst i_dst (acc_lmap : LBase.t) =
          if Base.is_read_only base_dst
          then (CilE.warn_mem_write with_alarms; acc_lmap)
          else
            let validity = Base.validity base_dst in
            let offsetmap_dst = LBase.find_or_default base_dst m' in
            try
              ignore (Ival.cardinal_less_than i_dst plevel);
              (* TODO: this should be improved if i_dst if of the form [a..b]c%d
                 with d >= size. In this case, the write do not overlap, and
                 could be done in one run in the offsetmap itself *)
              let new_offsetmap =
                Ival.fold
                  (fun start_to acc ->
                    let stop_to = Int.pred (Int.add start_to size) in
                    match validity with
                      | Base.Periodic (b, e, _)
                      | Base.Known (b,e)
                      | Base.Unknown (b,e)
                              when Int.lt start_to b || Int.gt stop_to e ->
                          CilE.warn_mem_write with_alarms;
                          acc

                      | Base.Known _ | Base.All | Base.Unknown _ ->
                          had_non_bottom := true;
                          op map_to_copy start stop start_to acc

                      | Base.Periodic (b, _e, period) ->
                          had_non_bottom := true;
                          assert (Int.equal b Int.zero) (* assumed in base.ml*);
                          let start_to = Int.rem start_to period in
                          let stop_to = Int.pred (Int.add start_to size) in
                          if Int.gt stop_to period then
                            Kernel.not_yet_implemented "Paste of overly long \
                              values in periodic offsetmaps" (* TODO *);
                          LOffset.copy_merge map_to_copy start stop start_to acc
                  ) i_dst offsetmap_dst
              in
              if offsetmap_dst != new_offsetmap then
                LBase.add base_dst new_offsetmap acc_lmap
              else acc_lmap
            with Not_less_than ->
	      ( try
		  let r = 
		  add_binding_offsetmap ~reducing:false ~with_alarms
                    ~exact:dst_is_exact base_dst i_dst (Int_Base.inject size)
                    (Lazy.force v) acc_lmap
		  in
		  Kernel.result ~current:true ~once:true
                    "too many locations to update in array. Approximating.";
		  had_non_bottom := true;
		  r
		with 
		  Offsetmap.Result_is_bottom ->
		    CilE.warn_mem_write with_alarms; acc_lmap)
	in
        match dst_loc with
          | Location_Bits.Map _ ->
              let result = Location_Bits.fold_i treat_dst dst_loc m' in
              if !had_non_bottom then Map result
              else begin
                Kernel.warning ~once:true ~current:true
                  "all target addresses were invalid. This path is assumed to \
                    be dead.";
                bottom
              end

          | Location_Bits.Top (top, orig) ->
              if top != Location_Bits.Top_Param.top then
                Kernel.result ~current:true ~once:true
                  "writing somewhere in @[%a@]@[%a@]."
                  Location_Bits.Top_Param.pretty top
                  Origin.pretty_as_reason orig;
              add_binding ~with_alarms ~exact:false m dst_loc' (Lazy.force v)

  let copy_offsetmap ~with_alarms src_loc mm =
    match mm with
      | Bottom -> None
      | Top -> Some LOffset.empty
      | Map m ->
        try
          let size = Int_Base.project src_loc.size in
          try
            begin
              let treat_src k_src i_src (acc : LOffset.t option) =
                let validity = Base.validity k_src in
                let offsetmap_src = LBase.find_or_default k_src m in
                if LOffset.is_empty offsetmap_src then (
                  CilE.warn_mem_read with_alarms;
                  acc)
                else
                  let copy = LOffset.copy_ival ~with_alarms
                    ~validity i_src offsetmap_src size
                  in
                  (* TODO. copy_ival seems to return an empty offsetmap only if
                     i_src is degenerate. This needs further checking *)
                  assert (not (LOffset.is_empty copy));
                  match acc with
                    | None -> Some copy
                    | Some acc ->
                      Some ((LOffset.join copy acc))
              in
              Location_Bits.fold_i treat_src src_loc.loc None
            end
          with
            | Location_Bits.Error_Top (* from Location_Bits.fold *) ->
              let v = find ~conflate_bottom:false ~with_alarms mm src_loc in
              Some
                (LOffset.update_ival
                   ~with_alarms:warn_none_mode
                   ~validity:Base.All
                   ~exact:true
                   ~offsets:Ival.zero
                   ~size
                   LOffset.empty
                   v)
        with
          | Int_Base.Error_Top  (* from Int_Base.project *) ->
            Some LOffset.empty


  (* TODO: this function is currently unused, and much less tested than the
     corresponding code in Eval_stmts.do_assign. There are also problems with
     with_alarms (the syntactic context should probably be different for
     the read and the paste). Removed for now. *)
  let _copy_paste ~with_alarms src_loc dst_loc mm =
    assert (Int_Base.equal src_loc.size dst_loc.size &&
              not (Int_Base.equal src_loc.size Int_Base.top));
    let size = Int_Base.project src_loc.size in
    let result = copy_offsetmap ~with_alarms src_loc mm in
    match result with
      | Some result ->
          paste_offsetmap with_alarms result dst_loc.loc Int.zero size true mm
      | None -> bottom

  let fold ~size f m acc =
    match m with
      | Bottom -> raise Error_Bottom
      | Top -> assert false
      | Map m ->
          try
            LBase.fold
              (fun k v acc ->
                 LOffset.fold_whole
                   ~size
                 (fun ival size v acc ->
                    let loc = Location_Bits.inject k ival in
                    f (make_loc loc (Int_Base.inject size)) v acc)
                   v
                   acc)
              m
              acc
          with Invalid_argument "Offsetmap.Make.fold" ->
            raise (Invalid_argument "Lmap.fold")

  let fold_single_bindings ~size f m acc =
    match m with
    | Bottom -> raise Error_Bottom
      | Top -> assert false
    | Map m ->
        try
          LBase.fold
            (fun k v acc ->
              LOffset.fold_single_bindings
                ~size
                (fun ival size v acc ->
                  let loc = Location_Bits.inject k ival in
                  f (make_loc loc (Int_Base.inject size)) v acc)
                v
                acc)
            m
            acc
        with Invalid_argument "Offsetmap.Make.fold" ->
          raise (Invalid_argument "Lmap.fold")

  let fold_base f m acc =
    match m with
      | Bottom -> raise Error_Bottom
          | Top -> assert false
  | Map m ->
          LBase.fold
            (fun k _ acc -> f k acc)
            m
            acc

  let fold_base_offsetmap f m acc =
    match m with
      | Top -> assert false
      | Bottom -> raise Error_Bottom
      | Map m ->
          LBase.fold
            (fun k off acc -> f k off acc)
            m
            acc

  let reciprocal_image base m = (*: Base.t -> t -> Zone.t*Location_Bits.t*)
    match m with
    | Bottom -> assert false
    | Top -> assert false
    | Map m ->
        if Base.is_null base then Zone.top,Location_Bits.top
        else
          LBase.fold
            (fun b offs (acc1,acc2) ->
               let interv_set,ival = LOffset.reciprocal_image offs base in
               let acc1 = Zone.join acc1 (Zone.inject b interv_set) in
               let acc2 = Location_Bits.join acc2 (Location_Bits.inject b ival) in
               acc1,acc2)
            m
            (Zone.bottom,Location_Bits.bottom)

  let cached_fold ~f ~cache ~temporary ~joiner ~empty =
    let cached_f = LBase.cached_fold ~f ~cache ~temporary ~joiner ~empty
    in
    function
      | Top -> assert false
      | Bottom -> raise Error_Bottom
      | Map mm ->
         (cached_f mm)


  let cached_map ~f ~cache ~temporary =
    let cached_f = LBase.cached_map ~f ~cache ~temporary
    in
    function
        Bottom -> Bottom
      | Top -> assert false
      | Map mm ->
         Map (cached_f mm)

end

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
