(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2025 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(********************************************************************)

open Why3

module S = Session_itp
module C = Whyconf

type spec_list = Getopt.opt list

type cmd =
    {
      cmd_spec : spec_list;
      cmd_desc : string;
      cmd_usage: string;
      cmd_name : string;
      cmd_run  : unit -> unit;
    }

let session_files = Queue.create ()
let iter_session_files f = Queue.iter f session_files
let add_session_file (f:string) = Queue.add f session_files
let no_session_file () = Queue.is_empty session_files

let read_session fname =
  let q = Queue.create () in
  Queue.push fname q;
  let project_dir = Server_utils.get_session_dir ~allow_mkdir:false q in
  S.load_session project_dir

let read_update_session ~allow_obsolete env config fname =
  let session = read_session fname in
(*
  let ctxt = S.mk_update_context
    ~allow_obsolete_goals:allow_obsolete
    ~use_shapes_for_pairing_sub_goals:use_shapes
    (fun ?parent:_ () -> ())
  in
  S.update_session ~ctxt session env config
 *)
  let cont = Controller_itp.create_controller config env session in
  let found_obs, some_merge_miss =
    try
      Controller_itp.reload_files ~ignore_shapes:true cont
    with
    | Controller_itp.Errors_list l ->
        List.iter (fun e -> Format.eprintf "%a@." Exn_printer.exn_printer e) l;
        exit 1
  in
  if (found_obs || some_merge_miss) && not allow_obsolete then raise Exit;
  cont, found_obs, some_merge_miss

(** filter *)
type filter_prover =
| Prover of Whyconf.prover
| FilterProver of Whyconf.filter_prover

let filter_prover = Stack.create ()

let read_opt_prover s =
  try
    let l = Strings.rev_split ',' s in
    match l with
    (* A prover specified uniquely *)
    | [altern;version;name]
      when List.for_all (fun s -> s = "" || s.[0] <> '^') l ->
      Prover {Whyconf.prover_name = name;
              prover_version = version;
              prover_altern = altern}
    | _ -> FilterProver (Whyconf.parse_filter_prover s)
  with Whyconf.ParseFilterProver _ ->
    raise (Arg.Bad
             "--filter-prover name[,version[,alternative]|,,alternative] \
                regexp must start with ^")


let add_filter_prover s = Stack.push (read_opt_prover s) filter_prover

type filter_three = | FT_Yes | FT_No | FT_All

let opt_filter_obsolete = ref FT_All
let opt_filter_verified = ref FT_All
let opt_filter_is_leaf = ref FT_All

let add_filter_three r = function
  | Some "no" -> r := FT_No
  | Some "yes" | None -> r := FT_Yes
  | Some "all" -> r := FT_All
  | _ -> assert false

let opt_three r =
  let open Getopt in
  HndOpt (ASymbol ["yes";"no";"all"], add_filter_three r)

let opt_status = ref []

let status_filter x =
  let open Call_provers in
  match x with
  | "valid" -> Valid
  | "invalid" -> Invalid
  | "highfailure" -> HighFailure ""
  | "timeout" -> Timeout
  | _ -> assert false

let filter_spec =
  let open Getopt in
  [ KLong "filter-prover", Hnd1 (AString, add_filter_prover),
    "[<name>,[<version>[,<alternative>]]] select proof\nattempts with the given prover";
    KLong "filter-obsolete", opt_three opt_filter_obsolete,
    "[yes|no] select only (non-)obsolete proofs";
    KLong "filter-proved", opt_three opt_filter_verified,
    "[yes|no] select only proofs of (non-)proved goals";
    KLong "filter-is-leaf", opt_three opt_filter_is_leaf,
    "[yes|no] select only proofs of leaf goals,\ni.e., those without transformations";
    KLong "filter-status",
    Hnd1 (AList (',', ASymbol ["valid"; "invalid"; "timeout"; "highfailure"]),
          fun l -> opt_status := List.map status_filter l),
    "[valid|invalid|timeout|highfailure] select proof attempts\nwith the given status";
  ]

type filters =
    { provers : C.Sprover.t; (* if empty : every provers *)
      obsolete : filter_three;
      verified : filter_three;
      is_leaf : filter_three;
      status : Call_provers.prover_answer list; (* if empty : any answer *)
    }

let provers_of_filter_prover whyconf = function
  | Prover p        -> C.Sprover.singleton p
  | FilterProver fp ->
    (* There is an issue here: if the prover is uninstalled_prover,
    filter_provers will return an empty map without raising an exception *)
   let s = C.Mprover.map (Util.const ()) (C.filter_provers whyconf fp) in
   if C.Sprover.is_empty s
    then raise (C.ProverNotFound (whyconf,fp))
   else s

let prover_of_filter_prover whyconf = function
  | Prover p        -> p
  | FilterProver fp ->
    (C.filter_one_prover whyconf fp).C.prover

let print_filter_prover fmt = function
  | Prover p -> Why3.Whyconf.print_prover fmt p
  | FilterProver fp -> Why3.Whyconf.print_filter_prover fmt fp

let read_filter_spec whyconf : filters * bool =
  let should_exit = ref false in
  let s = ref C.Sprover.empty in
  let iter p =
    try
      s := C.Sprover.union (provers_of_filter_prover whyconf p) !s
    with C.ProverNotFound (_,fp) ->
      Format.eprintf
        "The prover %a is not found in the configuration file %s@."
        Whyconf.print_filter_prover fp
        (Whyconf.get_conf_file whyconf);
      should_exit := true in
  Stack.iter iter filter_prover;
  {provers = !s;
   obsolete = !opt_filter_obsolete;
   verified = !opt_filter_verified;
   is_leaf = !opt_filter_is_leaf;
   status = !opt_status;
  },!should_exit

let iter_proof_attempt_by_filter ses iter filters f =
  (* provers *)
  let iter_provers id a =
    if C.Sprover.mem a.S.prover filters.provers then f id a in
  let f = if C.Sprover.is_empty filters.provers then f else iter_provers in
  (* three value *)
  let three_value f v p =
    let iter_obsolete id a =
      match v, p id a with
        | FT_No, false -> f id a
        | FT_Yes, true -> f id a
        | _ -> () (* FT_All treated after *) in
    if v = FT_All then f else iter_obsolete in
  (* obsolete *)
  let f = three_value f filters.obsolete (fun _ a -> a.S.proof_obsolete) in
  (* archived *)
(*
  let f = three_value f filters.archived (fun _ a -> a.S.proof_archived) in
 *)
  (* verified *)
  let f = three_value f filters.verified
    (fun _ a -> S.pn_proved ses a.S.parent) in
  (* status *)
  let f = if filters.status = [] then f else
      (fun id a -> match a.S.proof_state with
      | Some pr when List.mem pr.Call_provers.pr_answer filters.status -> f id a
      | _ -> ()) in
  iter f ses

let theory_iter_proof_attempt_by_filter s filters f th =
  iter_proof_attempt_by_filter
    s
    (fun f s -> S.theory_iter_proof_attempt s f)
    filters f th

let session_iter_proof_attempt_by_filter s filters f =
  iter_proof_attempt_by_filter
    s
    (fun f _s ->
     S.session_iter_proof_attempt f)
    filters f s

let session_iter_proof_node_id_by_filter s filters f =
  let f pn =
    match filters.verified with
    | FT_All -> f pn
    | FT_No -> if not (S.pn_proved s pn) then f pn
    | FT_Yes -> if S.pn_proved s pn then f pn
  in
  let f pn =
    match filters.is_leaf with
    | FT_All -> f pn
    | FT_No -> if S.get_transformations s pn <> [] then f pn
    | FT_Yes -> if S.get_transformations s pn = [] then f pn
  in
  S.session_iter_proof_node_id f s

let opt_force_obsolete = ref false

let force_obsolete_spec =
  let open Getopt in
  [ KShort 'F', Hnd0 (fun () -> opt_force_obsolete := true),
    " transform obsolete session" ]



let rec ask_yn () =
  Format.printf "(y/n)@.";
  let answer = read_line () in
  match answer with
    | "y" -> true
    | "n" -> false
    | _ -> ask_yn ()

let ask_yn_nonblock ~callback =
  let b = Buffer.create 3 in
  let s = Bytes.create 1 in
  Format.printf "(y/n)@.";
  fun () ->
    match Unix.select [Unix.stdin] [] [] 0. with
    | [],_,_ -> true
    | _ ->
      if Unix.read Unix.stdin s 1 0 = 0 then
        begin (* EndOfFile *) callback false; false end
      else begin
        let c = Bytes.get s 0 in
        if c <> '\n'
        then (Buffer.add_char b c; true)
        else
          match Buffer.contents b with
          | "y" -> callback true; false
          | "n" | "" -> callback false; false
          | _ ->
            Format.printf "(y/N)@.";
            Buffer.clear b;
            true
      end


let get_used_provers_goal session g =
  let sprover = ref Whyconf.Sprover.empty in
  Session_itp.goal_iter_proof_attempt session
    (fun _ pa -> sprover := Whyconf.Sprover.add pa.Session_itp.prover !sprover)
    g;
  !sprover

let get_used_provers_theory session th =
  let sprover = ref Whyconf.Sprover.empty in
  Session_itp.theory_iter_proof_attempt session
    (fun _ pa -> sprover := Whyconf.Sprover.add pa.Session_itp.prover !sprover)
    th;
  !sprover

let get_used_provers_file session f =
  let sprover = ref Whyconf.Sprover.empty in
  Session_itp.file_iter_proof_attempt session
    (fun _ pa -> sprover := Whyconf.Sprover.add pa.Session_itp.prover !sprover)
    f;
  !sprover

let get_used_provers session =
  let sprover = ref Whyconf.Sprover.empty in
  Session_itp.session_iter_proof_attempt
    (fun _ pa -> sprover := Whyconf.Sprover.add pa.Session_itp.prover !sprover)
     session;
  !sprover

let get_transf_string s tr =
  String.concat " " (Session_itp.get_transf_name s tr :: Session_itp.get_transf_args s tr)

let goal_full_name s g =
  let name = Session_itp.get_proof_expl s g in
  if name = "" then (Session_itp.get_proof_name s g).Ident.id_string
  else name

let rec transf_depth s tr =
  List.fold_left
    (fun depth g -> max depth (goal_depth s g)) 0 (Session_itp.get_sub_tasks s tr)
and goal_depth s g =
  List.fold_left
    (fun depth tr -> max depth (1 + transf_depth s tr))
    1 (Session_itp.get_transformations s g)

let theory_depth s t =
  List.fold_left
    (fun depth g -> max depth (goal_depth s g)) 0 (Session_itp.theory_goals t)

let file_depth s f =
  List.fold_left (fun depth t -> max depth (theory_depth s t)) 0
    (Session_itp.file_theories f)
