(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2025 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(********************************************************************)

open Term
open Decl
open Reduction_engine
open Args_wrapper

let meta_rewrite = Theory.register_meta "rewrite" [Theory.MTprsymbol]
  ~desc:"Declare@ the@ given@ proposition@ as@ a@ rewrite@ rule."

let meta_rewrite_def = Theory.register_meta "rewrite_def" [Theory.MTlsymbol]
  ~desc:"Declare@ the@ definition@ of@ the@ symbol@ as@ a@ rewrite@ rule."

let meta_compute_max_quantifier_domain =
 Theory.register_meta_excl "compute_max_domain_size" [Theory.MTint]
  ~desc:"Maximal@ domain@ size@ for@ the@ reduction@ of@ bounded@ \
         quantifications"

let meta_compute_max_steps = Theory.register_meta_excl "compute_max_steps"
  [Theory.MTint]
  ~desc:"Maximal@ number@ of@ reduction@ steps@ done@ by@ the@ 'compute'@ \
         transformation"

let compute_max_steps = ref 1024

(* not yet used
let meta_begin_compute_context =
  Theory.register_meta "begin_compute_context" []
    ~desc:"Marks@ the@ position@ where@ computations@ are@ done@ by@ \
           transformation@ 'compute_in_context'."
*)

let rule_attr = Ident.create_attribute "rewrite"

let warn_cannot_rewrite =
  Loc.register_warning "cannot_rewrite" "Warn that a proposition cannot be turned into a rewrite rule"

let collect_rules p env km prs t =
  let acc = Task.task_fold
    (fun acc td -> match td.Theory.td_node with
      | Theory.Decl { d_node = Dprop((Plemma|Paxiom), pr, t) }
        when Decl.Spr.mem pr prs ||
           Ident.Sattr.mem rule_attr pr.pr_name.Ident.id_attrs ||
             Ident.Sattr.mem rule_attr t.t_attrs ->
          (pr,t) :: acc
      | _ -> acc)
    [] t
  in
  List.fold_left
    (fun e (pr,t) ->
      try add_rule t e
      with NotARewriteRule msg ->
        Loc.warning warn_cannot_rewrite "proposition %a cannot be turned into a rewrite rule: %s"
         Pretty.print_pr pr msg;
        e
    )
    (create p env km) acc

let normalize_hyp_or_goal ?pr_norm ?step_limit engine : Task.task Trans.tlist  =
  let step_limit =
    if step_limit = None then Some !compute_max_steps else step_limit
  in
  Trans.decl_l (fun d ->
    match d.d_node with
    | Dprop (Pgoal, pr, t) when pr_norm = None ->
        let t = normalize ?step_limit ~limit:!compute_max_steps engine Mvs.empty t in
        begin match t.t_node with
        | Ttrue -> []
        | _ ->
            let d = Decl.create_prop_decl Pgoal pr t in
            [[d]]
        end
    | Dprop (k, pr, t) when Option.fold ~some:(fun v -> pr_equal pr v) ~none:false pr_norm ->
      let t = normalize ?step_limit:step_limit ~limit:!compute_max_steps engine Mvs.empty t in
      let d = Decl.create_prop_decl k pr t in
      [[d]]
    | _ -> [[d]]) None

let craft_engine p env prs task =
  let km = Task.task_known task in
  collect_rules p env km prs task

let collect_rules_trans p env : Reduction_engine.engine Trans.trans =
  Trans.on_tagged_pr meta_rewrite
    (fun prs -> if p.compute_defs
    then Trans.store (craft_engine p env prs)
    else Trans.on_tagged_ls meta_rewrite_def
        (fun lss -> let p = { p with compute_def_set = lss } in
        Trans.store (craft_engine p env prs)
        ))

let normalize_goal_transf ?pr_norm ?step_limit p env : 'a Trans.trans =
  let tr = Trans.on_meta_excl meta_compute_max_quantifier_domain @@ function
      | None -> Trans.return p
      | Some [Theory.MAint n] ->
          Trans.return {p with compute_max_quantifier_domain = n}
      | _ ->  assert false in
  let tr = Trans.bind tr (fun p -> collect_rules_trans p env) in
  let tr = Trans.on_meta_excl meta_compute_max_steps @@ function
      | None ->
          Trans.bind tr (fun engine -> normalize_hyp_or_goal ?pr_norm ?step_limit engine)
      | Some [Theory.MAint n] -> compute_max_steps := n;
          Trans.bind tr (fun engine -> normalize_hyp_or_goal ?pr_norm ?step_limit engine)
      | _ ->  assert false in
  tr

let default_param = {
  compute_defs = false;
  compute_builtin = false;
  compute_def_set = Term.Mls.empty;
  compute_max_quantifier_domain = 10;
}

let normalize_goal_transf_all env =
  let p = { default_param with compute_defs = true; compute_builtin = true } in
  normalize_goal_transf p env

let normalize_goal_transf_few env =
  let p = { default_param with compute_builtin = true } in
  normalize_goal_transf p env

let () =
  Trans.register_env_transform_l "compute_in_goal" normalize_goal_transf_all
  ~desc:"Perform@ computations@ in@ the@ goal,@ also@ using@ \
    the@ automatically@ derived@ rules."

let () =
  Trans.register_env_transform_l "compute_specified" normalize_goal_transf_few
  ~desc:"Perform@ computations@ in@ the@ goal,@ only@ using@ \
    the@ user-specified@ rules."

let normalize_hyp step_limit pr_norm env =
  let p = { default_param with compute_defs = true; compute_builtin = true } in
  normalize_goal_transf ?pr_norm ?step_limit p env

let () = wrap_and_register
    ~desc:"step [in] <name>@ performs@ one@ \"elementary\"@ \
      reduction@ step@ in@ the@ given@ premise@ (experimental)."
    "step"
    (Topt ("in", Tprsymbol Tenvtrans_l))
    (normalize_hyp (Some 1))

let () = wrap_and_register
    ~desc:"steps <n> [in] <name>@ performs@ <n>@ \"elementary\"@ \
      reduction@ steps@ in@ the@ given@ premise@ (experimental)."
    "steps"
    (Tint (Topt ("in", Tprsymbol Tenvtrans_l)))
    (fun n -> normalize_hyp (Some n))

let () = wrap_and_register
    ~desc:"compute_hyp [in] <name>@ performs@ computations@ \
      in@ the@ given@ premise, also@ using@ the@ automatically@ \
      derived@ rules."
    "compute_hyp"
    (Topt ("in", Tprsymbol Tenvtrans_l)) (normalize_hyp None)

let normalize_hyp_few step_limit pr_norm env =
  let p = { default_param with compute_builtin = true } in
  normalize_goal_transf ?pr_norm ?step_limit p env

let () = wrap_and_register
    ~desc:"compute_hyp_specified [in] <name>@ performs@ computations@ \
      in@ the@ given@ premise, only@ using@ the@ user-specified@ rules."
    "compute_hyp_specified"
    (Topt ("in", Tprsymbol Tenvtrans_l)) (normalize_hyp_few None)

let simplify check_ls env : 'a Trans.trans =
  let normalize_transf engine =
    Trans.decl (fun d ->
      match d.d_node with
      | Dprop (k, pr, t) ->
          let t = normalize ~step_limit:(1024*1024) ~limit:(1024*1024) engine Mvs.empty t in
          let d = Decl.create_prop_decl k pr t in
          [d]
      | _ -> [d]) None
  in
  let collect t =
    let acc = Task.task_fold
      (fun acc td -> match td.Theory.td_node with
        | Theory.Decl { d_node = Dprop((Plemma|Paxiom), pr, t) } ->
            begin match t.t_node with
            | Tapp(ls,[t1;_]) when ls == ps_equ ->
                begin match t1.t_node with
                | Tapp(ls,_::_) when not (check_ls ls) -> (pr,t) :: acc
                | _ -> acc
                end
            | _ -> acc
            end
        | _ -> acc)
      [] t
    in
    let p = { default_param with compute_builtin = true } in
    List.fold_left
      (fun e (pr,t) ->
        try add_rule t e
        with NotARewriteRule msg ->
          Loc.warning warn_cannot_rewrite "proposition %a cannot be turned into a rewrite rule: %s"
            Pretty.print_pr pr msg;
          e
      )
      (create p env (Task.task_known t)) acc in
  let tr = Trans.store collect in
  Trans.bind tr (fun engine -> normalize_transf engine)
