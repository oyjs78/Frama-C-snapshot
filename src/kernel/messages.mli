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

(** Stored messages. Storing of messages can be changed using
    {Kernel.Collect_messages.set} (at initialization time only);
    currently, only warning and error messages are stored if thus
    requested. *)

val iter: (Log.event -> unit) -> unit
  (** Iter over all stored messages. The messages are passed in emission order.
      @modify Nitrogen-20111001  Messages are now passed in emission order. *)

val dump_messages: unit -> unit
  (** Dump stored messages to standard channels *)

val self: State.t
  (** Internal state of stored messages *)

val reset_once_flag : unit -> unit
  (** Reset the [once] flag of pretty-printers. Messages already printed
      will be printed again.
      @since Boron-20100401 *)


(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
