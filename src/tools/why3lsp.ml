
open Why3
open Unix_scheduler
open Format
open Itp_communication

(*******************)
(* server protocol *)
(*******************)

module Protocol_lsp = struct 
  let debug_proto =
    Debug.register_flag "lsp_proto"
      ~desc:"Print@ debugging@ messages@ about@ Why3lsp@ protocol@"

  let print_request_debug r =
    Debug.dprintf debug_proto "[request]";
    Debug.dprintf debug_proto "%a" print_request r

  let print_notify_debug n =
    Debug.dprintf debug_proto "[notification]";
    Debug.dprintf debug_proto "%a@." print_notify n

  let list_requests : ide_request list ref = ref []

  let get_requests () =
    let n = List.length !list_requests in
    if n > 0 then Debug.dprintf debug_proto "got %d new requests@." n;
    let l = List.rev !list_requests in
    list_requests := [];
    l

  let send_request r =
    print_request_debug r;
    list_requests := r :: !list_requests

  let notification_list : notification list ref = ref []

  let notify n =
    (* too early, print when handling notifications print_notify_debug n; *)
    notification_list := n :: !notification_list

  let get_notified () =
    let n = List.length !notification_list in
    if n > 0 then Debug.dprintf debug_proto "got %d new notifications@." n;
    let l = List.rev !notification_list in
    notification_list := [];
    l
end

let get_notified = Protocol_lsp.get_notified

let send_request = Protocol_lsp.send_request

module Server = Itp_server.Make (Unix_scheduler) (Protocol_lsp)

type shell_node_type =
  | SRoot
  | SFile
  | STheory
  | STransformation
  | SGoal
  | SProofAttempt

type node = {
  node_ID: node_ID;
  node_parent: node_ID;
  node_name: string;
  mutable node_task: string option;
  mutable node_proof: Controller_itp.proof_attempt_status option;
  node_trans_args: string list option;
  node_type: shell_node_type;
  mutable node_proved: bool;
  mutable children_nodes: node_ID list;
  }

let root_node_ID = root_node
let max_ID = ref 1

let root_node = {
  node_ID = root_node_ID;
  node_parent = root_node_ID;
  node_name = "root";
  node_task = None;
  node_proof = None;
  node_trans_args = None;
  node_type = SRoot;
  node_proved = false;
  children_nodes = [];
}

module Hnode = Wstdlib.Hint
let nodes : node Hnode.t = Hnode.create 17
let () = Hnode.add nodes root_node_ID root_node

(* Current node_ID *)
let cur_id = ref root_node_ID

let print_goal fmt n =
  let node = Hnode.find nodes n in
  match node.node_task with
  | None -> fprintf fmt "No goal@."
  | Some s -> fprintf fmt "Goal is: \n %s@." s

(* _____________________________________________________________________ *)
(* -------------------- printing --------------------------------------- *)

let get_result pa =
  match pa with
  | None -> None
  | Some pr -> match pr with
    | Controller_itp.Done pr -> Some pr
    | _ -> None

let print_proof_attempt fmt pa_id =
  let pa = Hnode.find nodes pa_id in
  match pa.node_proof with
  | None -> pp_print_string fmt pa.node_name
  | Some _pr ->
    fprintf fmt "@[<h>%s %a@]"
      pa.node_name
      (Pp.print_option (Call_provers.print_prover_result ~json:false))
      (get_result pa.node_proof)

let rec print_proof_node (fmt: formatter) goal_id =
  let goal = Hnode.find nodes goal_id in
  let parent = Hnode.find nodes goal.node_parent in
  let parent_name = parent.node_name in
  let current_goal =
    goal_id = !cur_id
  in
  if current_goal then
    pp_print_string fmt "**";
  if goal.node_proved then
    pp_print_string fmt "P";
  let proof_attempts, transformations =
    List.partition (fun n -> let node = Hnode.find nodes n in
      node.node_type = SProofAttempt) goal.children_nodes
  in

  fprintf fmt
    "@[<hv 2>{ Goal=%s, id = %d;@ parent=%s;@ @[<hv 1>[%a]@]@ @[<hv 1>[%a]@] }@]"
    goal.node_name goal_id parent_name
    (Pp.print_list Pp.semi print_proof_attempt)
    proof_attempts
    (Pp.print_list Pp.semi print_trans_node) transformations;

  if current_goal then
    pp_print_string fmt " **"

and print_trans_node fmt id =
  let trans = Hnode.find nodes id in
  let name = trans.node_name in
  let l = trans.children_nodes in
  let args = trans.node_trans_args in
  let parent = Hnode.find nodes trans.node_parent in
  let parent_name = parent.node_name in
  if trans.node_proved then
    pp_print_string fmt "P";
  fprintf fmt "@[<hv 2>{ Trans=%s;@ args=%a;@ parent=%s;@ [%a] }@]" name
    (Pp.print_option (Pp.print_list Pp.semi pp_print_string)) args parent_name
    (Pp.print_list Pp.semi print_proof_node) l

let print_theory fmt th_id : unit =
  let th = Hnode.find nodes th_id in
  if th.node_proved then
    pp_print_string fmt "P";
  fprintf fmt "@[<hv 1> Theory %s, id: %d;@ [%a]@]" th.node_name th_id
    (Pp.print_list Pp.semi print_proof_node) th.children_nodes

let print_file fmt file_ID =
  let file = Hnode.find nodes file_ID in
  assert (file.node_type = SFile);
  fprintf fmt "@[<hv 1> File %s, id %d;@ [%a];@]" file.node_name file.node_ID
    (Pp.print_list Pp.semi print_theory) file.children_nodes

let print_s fmt files =
  fprintf fmt "@[%a@]" (Pp.print_list Pp.semi print_file) files

let print_session fmt =
  let l = root_node.children_nodes in
  fprintf fmt "root %a@." print_s l


let convert_to_shell_type t =
  match t with
  | NRoot           -> SRoot
  | NFile           -> SFile
  | NTheory         -> STheory
  | NTransformation -> STransformation
  | NGoal           -> SGoal
  | NProofAttempt   -> SProofAttempt

let return_proof_info (t: node_type) =
  match t with
  | NProofAttempt ->
    Some Controller_itp.Scheduled
  | _ -> None

(*Increases max ID*)
let add_new_node fmt (n: node_ID) (parent: node_ID) (t: node_type) (name: string) =
  if t = NRoot then () else
  let new_node = {
    node_ID = n;
    node_parent = parent;
    node_name = name;
    node_task = None;
    node_proof = return_proof_info t;
    node_trans_args = None; (* TODO *)
    node_type = convert_to_shell_type t;
    node_proved = false;
    children_nodes = [];
  } in
  try
    let parent = Hnode.find nodes parent in
    parent.children_nodes <- parent.children_nodes @ [n];
    Hnode.add nodes n new_node;
    max_ID := !max_ID + 1
  with
    Not_found -> fprintf fmt "Could not find node %d@." parent

let change_node fmt (n: node_ID) (u: update_info) =
  try
    let node = Hnode.find nodes n in
    (match u with
    | Proved b ->
        node.node_proved <- b
    | Proof_status_change (pas, _b, _rl) when node.node_type = SProofAttempt ->
        node.node_proof <- Some pas
    | Proof_status_change _ ->
        (* TODO Probably case that cannot occur. *)
        ()
    | Name_change _ -> fprintf fmt "Not yet supported@.") (* TODO *)
  with
    Not_found -> fprintf fmt "Could not find node %d@." n

(*************************)
(* Notification Handling *)
(*************************)

let treat_message_notification fmt msg = match msg with
  (* TODO: do something ! *)
  | Proof_error (_id, s)                           -> fprintf fmt "%s@." s
  | Transf_error (_b, _id, _tr_name, _arg, _loc, s, _) -> fprintf fmt "%s@." s
  | Strat_error (_id, s)                           -> fprintf fmt "%s@." s
  | Replay_Info s                                  -> fprintf fmt "%s@." s
  | Query_Info (_id, s)                            -> fprintf fmt "%s@." s
  | Query_Error (_id, s)                           -> fprintf fmt "%s@." s
  | File_Saved s                                   -> fprintf fmt "%s@." s
  | Information s when s = "Session initialized successfully" ->
      fprintf fmt "%s@." s;
      print_session fmt
  | Information s ->
      fprintf fmt "%s@." s
  | Task_Monitor (_t, _s, _r) -> () (* TODO do we want to print something for this? *)
  | Parse_Or_Type_Error (_, _, s)  -> fprintf fmt "%s@." s
  | Error s                ->
      fprintf fmt "%s@." s
  | Open_File_Error s -> fprintf fmt "%s@." s

let treat_notification fmt n =
  match n with
  | Reset_whole_tree                        -> print_session fmt
  | Node_change (id, info)                  ->
      change_node fmt id info
  | New_node (id, pid, typ, name, _detached) ->
      add_new_node fmt id pid typ name
  | Remove _id                              -> (* TODO *)
      fprintf fmt "got a Remove notification not yet supported@."
  | Ident_notif_loc _loc                    ->
      fprintf fmt "Ident_notif_loc notification not yet supported@."
  | Initialized _g_info                     ->
      (* TODO *)
      fprintf fmt "Initialized@."
  | Saved                                   -> (* TODO *)
      fprintf fmt "Session is saved@."
  | Saving_needed _b                        -> (* TODO *)
      fprintf fmt "got a Saving_needed notification not yet supported@."
  | Message msg                             -> treat_message_notification fmt msg
  | Dead s                                  ->
      fprintf fmt "Dead notification: %s\nExiting.@." s;
      (* This exception is matched in Unix_Scheduler *)
      raise Exit
  | File_contents (f, s, _, _)              ->
      fprintf fmt "File %s is:\n%s" f s (* TODO print this correctly *)
  | Source_and_ce _                         ->
      fprintf fmt "got a Source_and_ce notification not yet supported@." (* TODO *)
  | Next_Unproven_Node_Id _                 ->
      fprintf fmt "got a Next_Unproven_Node_Id notification not yet supported@." (* TODO *)
  | Task (id, s, _list_loc, _, _)           ->
    (* coloring the source is useless in shell *)
    try
      let node = Hnode.find nodes id in
      node.node_task <- Some s;
      if id = !cur_id then print_goal fmt !cur_id
    with
      Not_found -> fprintf fmt "Could not find node %d@." id

let additional_help = "Additionally for shell:\n\
                       goto n -> focus on n\n\
                       ng -> next node\n\
                       g -> print the current task\n\
                       gf -> print the current task with full context\n\
                       p -> print the session\n\
                       Exit -> quit the shell\n\
                       Save -> save the session\n"

(******************)
(*    actions     *)
(******************)

let interp fmt cmd =
  (* TODO dont use Re.Str. *)
  let l = Re.Str.split (Re.Str.regexp " ") cmd in
  begin
    match l with
    | ["goto"; n] ->
      begin
      try
        if int_of_string n < !max_ID then begin
        cur_id := int_of_string n;
        let c = false (* TODO *) in
        let show_uses_clones_metas = false (* TODO *) in
        send_request (Get_task(!cur_id,c,show_uses_clones_metas,false));
        print_session fmt
            end
        else
            Printf.printf "Input exceeded max ID\n";
      with
        | Failure msg -> 
          Printf.printf "Error: Could not convert '%s' to a number (%s). Please input a valid integer.\n" n msg;
        | _ -> 
          Printf.printf "An unexpected error occurred while parsing '%s'.\n" n;
        end
    | "goto" :: _ -> (* Catches "goto" with too few or too many arguments *)
       Printf.printf "Error: 'goto' command takes exactly one integer argument. Usage: goto <ID>\n";
       print_session fmt
    | _ ->
        begin
          match cmd with
          | "ng" -> cur_id := (!cur_id + 1) mod !max_ID; print_session fmt
          | "g" ->
              send_request (Get_task(!cur_id,false,false,false))
          | "gf" ->
              send_request (Get_task(!cur_id, true, false, false))
          | "p" -> print_session fmt
          | "help" ->
              fprintf fmt "%s@." additional_help;
              send_request (Command_req (!cur_id, cmd))
          | "Save" -> send_request Save_req
          | "Exit" -> send_request Exit_req
          | _ -> send_request (Command_req (!cur_id, cmd))
        end
  end;

(************************)
(* parsing command line *)
(************************)

module Main : functor () -> sig end
 = functor () -> struct

(* files of the current task *)
let files = Queue.create ()

let quiet = ref false

let spec =
  let open Getopt in
  [KLong "quiet", Hnd0 (fun () -> quiet := true),
   " remove all printing to stdout"]

(* --help *)
let usage_str =
  "[<file.xml>|<f1.why> <f2.mlw> ...]\n\
   Launch the lsp for why3."

let config, env =
  Whyconf.Args.initialize spec (fun f -> Queue.add f files) usage_str

let () =
  if Queue.is_empty files then
    Whyconf.Args.exit_with_usage usage_str;
  let fmt = if !quiet then str_formatter else std_formatter in
  fprintf fmt "Welcome to Why3 shell. Type 'help' for help.@.";
  let dir =
    try
      Server_utils.get_session_dir ~allow_mkdir:true files
    with Invalid_argument s ->
      eprintf "Error: %s@." s;
      Whyconf.Args.exit_with_usage usage_str
  in
  Queue.iter
    (fun f ->
      (* Sanitize the command line arguments so that they are always absolute *)
      let f = Sysutil.concat (Sys.getcwd ()) f in
      send_request (Add_file_req f))
    files;
  Server.init_server config env dir;
  Unix_scheduler.timeout ~ms:100
      (*a function that iterates over a list of notifications, applying treat_notification, returns true*) 
    (fun () -> List.iter
        (fun n -> treat_notification fmt n) (get_notified ()); 
        true);
  Unix_scheduler.main_loop (interp fmt)

end

let () = Whyconf.register_command "lsp" (module Main)
