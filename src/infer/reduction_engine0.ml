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

type value =
| Term of term    (* invariant: is in normal form *)
| Int of BigInt.t

let v_label_copy orig v =
  match v with
  | Int _ -> v
  | Term t -> Term (t_attr_copy orig t)

let const_of_positive n =
  let const = Number.{
        il_kind = ILitUnk; (* TODO check this *)
        il_int = n} in
  t_const (Constant.ConstInt const) Ty.ty_int

let ls_minus = ref ps_equ (* temporary *)

let const_of_big_int n =
  if BigInt.ge n BigInt.zero then const_of_positive n else
    let t = const_of_positive (BigInt.minus n) in
    t_app_infer !ls_minus [t]

let term_of_value v =
  match v with
  | Term t -> t
  | Int n -> const_of_big_int n

exception NotNum

let big_int_of_const c =
  match c with
    | Constant.ConstInt i -> Number.(i.il_int)
    | _ -> raise NotNum

let big_int_of_value v =
  match v with
  | Int n -> n
  | Term {t_node = Tconst c } -> big_int_of_const c
  | Term { t_node = Tapp (ls,[{ t_node = Tconst c }]) }
    when ls_compare ls !ls_minus = 0 -> BigInt.minus (big_int_of_const c)
  | _ -> raise NotNum


(* {2 Builtin symbols} *)

let builtins = Hls.create 17

(* all builtin functions *)

exception Undetermined

let to_bool b = if b then t_true else t_false

let _t_app_value ls l ty =
  Term (t_app ls (List.map term_of_value l) ty)

let is_zero v =
  try BigInt.eq (big_int_of_value v) BigInt.zero
  with NotNum -> false

let is_one v =
  try BigInt.eq (big_int_of_value v) BigInt.one
  with NotNum -> false

let eval_int_op op simpl ls l ty =
  match l with
  | [t1 ; t2] ->
    begin
      try
        let n1 = big_int_of_value t1 in
        let n2 = big_int_of_value t2 in
        Int (op n1 n2)
      with NotNum | Division_by_zero ->
        simpl ls t1 t2 ty
    end
  | _ -> assert false (* t_app_value ls l ty *)

(* unused anymore, for the moment
let simpl_none ls t1 t2 ty =
  t_app_value ls [t1;t2] ty
*)

let simpl_add _ls t1 t2 _ty =
  if is_zero t1 then t2 else
  if is_zero t2 then t1 else
  raise Undetermined
(*
  t_app_value ls [t1;t2] ty
*)

let simpl_sub _ls t1 t2 _ty =
  if is_zero t2 then t1 else
  raise Undetermined
(*
  t_app_value ls [t1;t2] ty
*)

let simpl_mul _ls t1 t2 _ty =
  if is_zero t1 then t1 else
  if is_zero t2 then t2 else
  if is_one t1 then t2 else
  if is_one t2 then t1 else
  raise Undetermined
(*
  t_app_value ls [t1;t2] ty
*)

let simpl_divmod _ls t1 t2 _ty =
  if is_zero t1 then t1 else
  if is_one t2 then t1 else
  raise Undetermined
(*
  t_app_value ls [t1;t2] ty
*)

let simpl_minmax _ls v1 v2 _ty =
  match v1,v2 with
  | Term t1, Term t2 ->
    if t_equal t1 t2 then v1 else
      raise Undetermined
  (*
    t_app_value ls [v1;v2] ty
  *)
  | _ ->
    raise Undetermined
(*
  t_app_value ls [v1;v2] ty
*)

let eval_int_rel op _ls l _ty =
  match l with
  | [t1 ; t2] ->
    begin
      try
        let n1 = big_int_of_value t1 in
        let n2 = big_int_of_value t2 in
        Term (to_bool (op n1 n2))
      with NotNum | Division_by_zero ->
        raise Undetermined
    (*        t_app_value ls l ty *)
    end
  | _ -> assert false
    (* t_app_value ls l ty *)

let eval_int_uop op _ls l _ty =
  match l with
  | [t1] ->
    begin
      try
        let n1 = big_int_of_value t1 in Int (op n1)
      with NotNum | Division_by_zero ->
        raise Undetermined
    (*       t_app_value ls l ty *)
    end
  | _ -> assert false


let built_in_theories =
  [
(*
 ["bool"],"Bool", [],
    [ "True", None, eval_true ;
      "False", None, eval_false ;
    ] ;
*)
    ["int"],"Int", [],
    [ "infix +", None, eval_int_op BigInt.add simpl_add;
      "infix -", None, eval_int_op BigInt.sub simpl_sub;
      "infix *", None, eval_int_op BigInt.mul simpl_mul;
      "prefix -", Some ls_minus, eval_int_uop BigInt.minus;
      "infix <", None, eval_int_rel BigInt.lt;
      "infix <=", None, eval_int_rel BigInt.le;
      "infix >", None, eval_int_rel BigInt.gt;
      "infix >=", None, eval_int_rel BigInt.ge;
    ] ;
    ["int"],"MinMax", [],
    [ "min", None, eval_int_op BigInt.min simpl_minmax;
      "max", None, eval_int_op BigInt.max simpl_minmax;
    ] ;
    ["int"],"ComputerDivision", [],
    [ "div", None, eval_int_op BigInt.computer_div simpl_divmod;
      "mod", None, eval_int_op BigInt.computer_mod simpl_divmod;
    ] ;
    ["int"],"EuclideanDivision", [],
    [ "div", None, eval_int_op BigInt.euclidean_div simpl_divmod;
      "mod", None, eval_int_op BigInt.euclidean_mod simpl_divmod;
    ] ;
(*
    ["map"],"Map", ["map", builtin_map_type],
    [ "const", Some ls_map_const, eval_map_const;
      "get", Some ls_map_get, eval_map_get;
      "set", Some ls_map_set, eval_map_set;
    ] ;
*)
  ]

let add_builtin_th env (l,n,t,d) =
  let th = Env.read_theory env l n in
  List.iter
    (fun (id,r) ->
      let ts = Theory.ns_find_ts th.Theory.th_export [id] in
      r ts)
    t;
  List.iter
    (fun (id,r,f) ->
      let ls = Theory.ns_find_ls th.Theory.th_export [id] in
      Hls.add builtins ls f;
      match r with
        | None -> ()
        | Some r -> r := ls)
    d

let get_builtins env =
  Hls.clear builtins;
  List.iter (add_builtin_th env) built_in_theories



(* {2 the reduction machine} *)


type rule = Svs.t * term list * term

type params =
  { compute_defs : bool;
    compute_builtin : bool;
    compute_def_set : Term.Sls.t;
  }

type engine =
  { known_map : Decl.decl Ident.Mid.t;
    rules : rule list Mls.t;
    params : params;
  }


(* OBSOLETE COMMENT

  A configuration is a pair (t,s) where t is a stack of terms and s is a
  stack of function symbols.

  A configuration ([t1;..;tn],[f1;..;fk]) represents a whole term, its
  model, as defined recursively by

    model([t],[]) = t

    model(t1::..::tn::t,f::s) = model(f(t1,..,tn)::t,s)
      where f as arity n

  A given term can be "exploded" into a configuration by reversing the
  rules above

  During reduction, the terms in the first stack are kept in normal
  form. The normalization process can be defined as the repeated
  application of the following rules.

  ([t],[]) --> t  // t is in normal form

  if f(t1,..,tn) is not a redex then
  (t1::..::tn::t,f::s) --> (f(t1,..,tn)::t,s)

  if f(t1,..,tn) is a redex l sigma for a rule l -> r then
  (t1::..::tn::t,f::s) --> (subst(sigma) @ t,explode(r) @ s)




*)

type substitution = term Mvs.t

type cont =
| Kapp of lsymbol * Ty.ty option
| Kif of term * term * substitution
| Klet of vsymbol * term * substitution
| Kcase of term_branch list * substitution
| Keps of vsymbol
| Kquant of quant * vsymbol list * trigger
| Kbinop of binop
| Knot
| Keval of term * substitution

type config = {
  value_stack : value list;
  cont_stack : (cont * term) list;
  (* second term is the original term, for label and loc copy *)
}


exception NoMatch

let first_order_matching (vars : Svs.t) (largs : term list)
    (args : term list) : Ty.ty Ty.Mtv.t * substitution =
  let rec loop ((mt,mv) as sigma) largs args =
    match largs,args with
      | [],[] -> sigma
      | t1::r1, t2::r2 ->
        begin
(*
          Format.eprintf "matching terms %a and %a...@."
            Pretty.print_term t1 Pretty.print_term t2;
*)
          match t1.t_node with
            | Tvar vs when Svs.mem vs vars ->
              begin
                try let t = Mvs.find vs mv in
                    if t_equal t t2 then
                      loop sigma r1 r2
                    else
                      raise NoMatch
                with Not_found ->
                  try
                    let ts = Ty.ty_match mt vs.vs_ty (t_type t2) in
                    loop (ts,Mvs.add vs t2 mv) r1 r2
                  with Ty.TypeMismatch _ -> raise NoMatch
              end
            | Tapp(ls1,args1) ->
              begin
                match t2.t_node with
                  | Tapp(ls2,args2) when ls_equal ls1 ls2 ->
                    let mt, mv = loop sigma (List.rev_append args1 r1)
                      (List.rev_append args2 r2) in
                    begin
                      try Ty.oty_match mt t1.t_ty t2.t_ty, mv
                      with Ty.TypeMismatch _ -> raise NoMatch
                    end
                  | _ -> raise NoMatch
              end
            | (Tconst _ | Ttrue | Tfalse) when t_equal t1 t2 ->
                loop sigma r1 r2
            | _ -> raise NoMatch
        end
      | _ -> raise NoMatch
  in
  loop (Ty.Mtv.empty, Mvs.empty) largs args

exception Irreducible

let one_step_reduce engine ls args =
  try
    let rules = Mls.find ls engine.rules in
    let rec loop rules =
      match rules with
        | [] -> raise Irreducible
        | (vars,largs,rhs)::rem ->
          begin
            try
              let sigma = first_order_matching vars largs args in
              sigma,rhs
            with NoMatch ->
              loop rem
          end
    in loop rules
  with Not_found ->
    raise Irreducible

let rec matching ((mt,mv) as sigma) t p =
  match p.pat_node with
  | Pwild -> sigma
  | Pvar v -> (mt,Mvs.add v t mv)
  | Por(p1,p2) ->
    begin
      try matching sigma t p1
      with NoMatch -> matching sigma t p2
    end
  | Pas(p,v) -> matching (mt,Mvs.add v t mv) t p
  | Papp(ls1,pl) ->
    match t.t_node with
      | Tapp(ls2,tl) ->
        if ls_equal ls1 ls2 then
          List.fold_left2 matching sigma tl pl
        else
          if ls2.ls_constr > 0 then raise NoMatch
          else raise Undetermined
      | _ -> raise Undetermined


let rec extract_first n acc l =
  if n = 0 then acc,l else
    match l with
    | x :: r ->
      extract_first (n-1) (x::acc) r
    | [] -> assert false


let rec reduce engine c =
  match c.value_stack, c.cont_stack with
  | _, [] -> assert false
  | st, (Keval (t,sigma),orig) :: rem -> reduce_eval st t ~orig sigma rem
  | [], (Kif _, _) :: _ -> assert false
  | v :: st, (Kif(t2,t3,sigma), orig) :: rem ->
    begin
      match v with
      | Term { t_node = Ttrue } ->
        { value_stack = st ;
          cont_stack = (Keval(t2,sigma),t_attr_copy orig t2)  :: rem }
      | Term { t_node = Tfalse } ->
        { value_stack = st ;
          cont_stack = (Keval(t3,sigma),t_attr_copy orig t3) :: rem }
      | Term t1 -> begin
          match t1.t_node , t2.t_node , t3.t_node with
          | Tapp (ls,[b0;{ t_node = Tapp (ls1,_) }]) , Tapp(ls2,_) , Tapp(ls3,_)
            when ls_equal ls ps_equ && ls_equal ls1 fs_bool_true &&
              ls_equal ls2 fs_bool_true && ls_equal ls3 fs_bool_false ->
            { value_stack = Term (t_attr_copy orig b0) :: st;
              cont_stack = rem }
          | _ ->
            { value_stack =
                Term
                  (t_attr_copy orig
                     (t_if t1 (t_subst sigma t2) (t_subst sigma t3))) :: st;
              cont_stack = rem;
            }
        end
      | Int _ -> assert false (* would be ill-typed *)
    end
  | [], (Klet _, _) :: _ -> assert false
  | t1 :: st, (Klet(v,t2,sigma), orig) :: rem ->
    let t1 = term_of_value t1 in
    { value_stack = st;
      cont_stack =
        (Keval(t2, Mvs.add v t1 sigma), t_attr_copy orig t2) :: rem;
    }
  | [], (Kcase _, _) :: _ -> assert false
  | Int _ :: _, (Kcase _, _) :: _ -> assert false
  | (Term t1) :: st, (Kcase(tbl,sigma), orig) :: rem ->
    reduce_match st t1 ~orig tbl sigma rem
  | ([] | [_] | Int _ :: _ | Term _ :: Int _ :: _),
    (Kbinop _, _) :: _ -> assert false
  | (Term t1) :: (Term t2) :: st, (Kbinop op, orig) :: rem ->
    { value_stack = Term (t_attr_copy orig (t_binary_simp op t2 t1)) :: st;
      cont_stack = rem;
    }
  | [], (Knot,_) :: _ -> assert false
  | Int _ :: _ , (Knot,_) :: _ -> assert false
  | (Term t) :: st, (Knot, orig) :: rem ->
    { value_stack = Term (t_attr_copy orig (t_not_simp t)) :: st;
      cont_stack = rem;
    }
  | st, (Kapp(ls,ty), orig) :: rem ->
    reduce_app engine st ~orig ls ty rem
  | [], (Keps _, _) :: _ -> assert false
  | Int _ :: _ , (Keps _, _) :: _ -> assert false
  | Term t :: st, (Keps v, orig) :: rem ->
    { value_stack = Term (t_attr_copy orig (t_eps_close v t)) :: st;
      cont_stack = rem;
    }
  | [], (Kquant _, _) :: _ -> assert false
  | Int _ :: _, (Kquant _, _) :: _ -> assert false
  | Term t :: st, (Kquant(q,vl,tr), orig) :: rem ->
    { value_stack = Term (t_attr_copy orig (t_quant_close_simp q vl tr t)) :: st;
      cont_stack = rem;
    }

and reduce_match st u ~orig tbl sigma cont =
  let rec iter tbl =
    match tbl with
    | [] -> assert false (* pattern matching not exhaustive *)
    | b::rem ->
      let p,t = t_open_branch b in
      try
        let (mt',mv') = matching (Ty.Mtv.empty,sigma) u p in
(*
        Format.eprintf "Pattern-matching succeeded:@\nmt' = @[";
        Ty.Mtv.iter
          (fun tv ty -> Format.eprintf "%a -> %a,"
            Pretty.print_tv tv Pretty.print_ty ty)
          mt';
        Format.eprintf "@]@\n";
        Format.eprintf "mv' = @[";
        Mvs.iter
          (fun v t -> Format.eprintf "%a -> %a,"
            Pretty.print_vs v Pretty.print_term t)
          mv';
        Format.eprintf "@]@.";
        Format.eprintf "branch before inst: %a@." Pretty.print_term t;
*)
        let mv'',t = t_subst_types mt' mv' t in
(*
        Format.eprintf "branch after types inst: %a@." Pretty.print_term t;
        Format.eprintf "mv'' = @[";
        Mvs.iter
          (fun v t -> Format.eprintf "%a -> %a,"
            Pretty.print_vs v Pretty.print_term t)
          mv'';
        Format.eprintf "@]@.";
*)
        { value_stack = st;
          cont_stack = (Keval(t,mv''), t_attr_copy orig t) :: cont;
        }
      with NoMatch -> iter rem
  in
  try iter tbl with Undetermined ->
    let dmy = t_var (create_vsymbol (Ident.id_fresh "__dmy") (t_type u)) in
    let tbls = match t_subst sigma (t_case dmy tbl) with
      | { t_node = Tcase (_,tbls) } -> tbls
      | _ -> assert false
    in
    { value_stack =
        Term (t_attr_copy orig (t_case u tbls)) :: st;
      cont_stack = cont;
    }


and reduce_eval st t ~orig sigma rem =
  let orig = t_attr_copy orig t in
  match t.t_node with
  | Tvar v ->
    begin
      try
        let t = Mvs.find v sigma in
        { value_stack = Term (t_attr_copy orig t) :: st ;
          cont_stack = rem;
        }
      with Not_found ->
        (* this may happen, e.g when computing below a quantified formula *)
        (*
          Format.eprintf "Tvar not found: %a@." Pretty.print_vs v;
          assert false
        *)
        { value_stack = Term orig :: st ;
          cont_stack = rem;
        }
    end
  | Tif(t1,t2,t3) ->
    { value_stack = st;
      cont_stack = (Keval(t1,sigma),t1) :: (Kif(t2,t3,sigma),orig) :: rem;
    }
  | Tlet(t1,tb) ->
    let v,t2 = t_open_bound tb in
    { value_stack = st ;
      cont_stack = (Keval(t1,sigma),t1) :: (Klet(v,t2,sigma),orig) :: rem }
  | Tcase(t1,tbl) ->
    { value_stack = st;
      cont_stack = (Keval(t1,sigma),t1) :: (Kcase(tbl,sigma),orig) :: rem }
  | Tbinop(op,t1,t2) ->
    { value_stack = st;
      cont_stack =
        (Keval(t1,sigma),t1) ::
          (Keval(t2,sigma),t2) :: (Kbinop op, orig) :: rem;
    }
  | Tnot t1 ->
    { value_stack = st;
      cont_stack = (Keval(t1,sigma),t1) :: (Knot,orig) :: rem;
    }
  | Teps tb ->
    let v,t1 = t_open_bound tb in
    { value_stack = st ;
      cont_stack = (Keval(t1,sigma),t1) :: (Keps v,orig) :: rem;
    }
  | Tquant(q,tq) ->
    let vl,tr,t1 = t_open_quant tq in
    { value_stack = st;
      cont_stack = (Keval(t1,sigma),t1) :: (Kquant(q,vl,tr),orig) :: rem;
    }
  | Tapp(ls,tl) ->
    let args = List.rev_map (fun t -> (Keval(t,sigma),t)) tl in
    { value_stack = st;
      cont_stack = List.rev_append args ((Kapp(ls,t.t_ty),orig) :: rem);
    }
  | Ttrue | Tfalse | Tconst _ ->
    { value_stack = Term orig :: st;
      cont_stack = rem;
    }

and reduce_app engine st ls ~orig ty rem_cont =
  if ls_equal ls ps_equ then
    match st with
    | t2 :: t1 :: rem_st ->
      begin
        try
          reduce_equ ~orig rem_st t1 t2 rem_cont
        with Undetermined ->
          reduce_app_no_equ engine st ls ~orig ty rem_cont
      end
    | _ -> assert false
  else
    if ls_equal ls fs_func_app then
      match st with
      | t2 :: t1 :: rem_st ->
        begin
          try
            reduce_func_app ~orig ty rem_st t1 t2 rem_cont
          with Undetermined ->
            reduce_app_no_equ engine st ls ~orig ty rem_cont
        end
      | _ ->  assert false
    else
      reduce_app_no_equ engine st ls ~orig ty rem_cont

and reduce_func_app ~orig _ty rem_st t1 t2 rem_cont =
    (* attempt to decompile t1 under the form
       (epsilon fc. forall x. fc @ x = body)
       that is equivalent to \x.body *)
    match t1 with
    | Term { t_node = Teps tb } ->
      let fc,t = Term.t_open_bound tb in
      begin match t.t_node with
      | Tquant(Tforall,tq) ->
        let vl,trig,t = t_open_quant tq in
        let process lhs body equ elim =
          let rvl = List.rev vl in
          let rec remove_var lhs rvh rvt = match lhs.t_node with
            | Tapp (ls2,[lhs1;{t_node = Tvar v1} as arg])
              when ls_equal ls2 fs_func_app && vs_equal v1 rvh ->
              begin
              match rvt , lhs1 with
              | rvh::rvt , _ ->
                let lhs1 , fc2 = remove_var lhs1 rvh rvt in
                let lhs2 = t_app ls2 [lhs1;arg] lhs.t_ty in
                t_attr_copy lhs lhs2 , fc2
              | [] , { t_node = Tvar fc1 } when vs_equal fc1 fc ->
                let fcn = fc.vs_name in
                let fc2 = Ident.id_derive fcn.Ident.id_string fcn in
                let fc2 = create_vsymbol fc2 (t_type lhs) in
                t_attr_copy lhs (t_var fc2) , fc2
              | _ -> raise Undetermined
              end
            | _ -> raise Undetermined
          in
          begin
          match rvl with
          | rvh :: rvt -> let lhs , fc2 = remove_var lhs rvh rvt in
            let (vh,vl) = match vl with
            | [] -> assert false
            | vh::vl -> (vh,vl)
            in
            let t2 = term_of_value t2 in
            begin
            match vl with
            | [] -> elim body vh t2
            | _ ->
              let eq = equ lhs body in
              let tq = t_quant Tforall (t_close_quant vl trig eq) in
              let body = t_attr_copy t (t_eps_close fc2 tq) in
              { value_stack = rem_st;
                cont_stack =
                  (Keval(body,Mvs.add vh t2 Mvs.empty),
                   t_attr_copy orig body) :: rem_cont;
              }
            end
          | _ -> raise Undetermined
          end
        in
        begin
        match t.t_node with
          | Tapp (ls1,[lhs;body]) when ls_equal ls1 ps_equ ->
            let equ lhs body = t_attr_copy t (t_app ps_equ [lhs;body] None) in
            let elim body vh t2 = {
              value_stack = rem_st;
              cont_stack =
                (Keval(body,Mvs.add vh t2 Mvs.empty),
                 t_attr_copy orig body) :: rem_cont;
            } in
            process lhs body equ elim
          | Tbinop (Tiff,
            ({t_node=Tapp (ls1,[lhs;tr])} as teq),
            body)
            when ls_equal ls1 ps_equ && t_equal tr t_bool_true ->
            let equ lhs body =
              let lhs = t_attr_copy teq (t_app ps_equ [lhs;tr] None) in
              t_attr_copy t (t_binary Tiff lhs body) in
            let elim body vh t2 =
              let body = t_if body t_bool_true t_bool_false in
              { value_stack = rem_st;
                cont_stack =
                (Keval(body,Mvs.add vh t2 Mvs.empty),
                t_attr_copy orig body) :: rem_cont } in
            process lhs body equ elim
          | _ -> raise Undetermined
        end
      | _ -> raise Undetermined
      end
    | _ -> raise Undetermined

and reduce_app_no_equ engine st ls ~orig ty rem_cont =
  let arity = List.length ls.ls_args in
  let args,rem_st = extract_first arity [] st in
  try
    let f = Hls.find builtins ls in
    let v = f ls args ty in
    { value_stack = (v_label_copy orig v) :: rem_st;
      cont_stack = rem_cont;
    }
  with Not_found | Undetermined ->
    let args = List.map term_of_value args in
    let d = try Ident.Mid.find ls.ls_name engine.known_map
      with Not_found -> assert false in
    let rewrite () =
      (* try a rewrite rule *)
        begin
          try
(*
            Format.eprintf "try a rewrite rule on %a@." Pretty.print_ls ls;
*)
            let (mt,mv),rhs = one_step_reduce engine ls args in
(*
            Format.eprintf "rhs = %a@." Pretty.print_term rhs;
            Format.eprintf "sigma = ";
            Mvs.iter
              (fun v t -> Format.eprintf "%a -> %a,"
                Pretty.print_vs v Pretty.print_term t)
              (snd sigma);
            Format.eprintf "@.";
            Format.eprintf "try a type match: %a and %a@."
              (Pp.print_option Pretty.print_ty) ty
              (Pp.print_option Pretty.print_ty) rhs.t_ty;
*)
(*
            let type_subst = Ty.oty_match Ty.Mtv.empty rhs.t_ty ty in
            Format.eprintf "subst of rhs: ";
            Ty.Mtv.iter
              (fun tv ty -> Format.eprintf "%a -> %a,"
                Pretty.print_tv tv Pretty.print_ty ty)
              type_subst;
            Format.eprintf "@.";
            let rhs = t_ty_subst type_subst Mvs.empty rhs in
            let sigma =
              Mvs.map (t_ty_subst type_subst Mvs.empty) sigma
            in
            Format.eprintf "rhs = %a@." Pretty.print_term rhs;
            Format.eprintf "sigma = ";
            Mvs.iter
              (fun v t -> Format.eprintf "%a -> %a,"
                Pretty.print_vs v Pretty.print_term t)
              sigma;
            Format.eprintf "@.";
*)
            let mv,rhs = t_subst_types mt mv rhs in
            { value_stack = rem_st;
              cont_stack = (Keval(rhs,mv),orig) :: rem_cont;
            }
          with Irreducible ->
            { value_stack =
                Term (t_attr_copy orig (t_app ls args ty)) :: rem_st;
              cont_stack = rem_cont; }
        end in
      match d.Decl.d_node with
      | Decl.Dtype _ | Decl.Dprop _ -> assert false
      | Decl.Dlogic dl ->
        (* regular definition *)
        let d = List.assq ls dl in
        if engine.params.compute_defs ||
           Term.Sls.mem ls engine.params.compute_def_set
        then begin
          let vl,e = Decl.open_ls_defn d in
          let add (mt,mv) x y =
            Ty.ty_match mt x.vs_ty (t_type y), Mvs.add x y mv
          in
          let (mt,mv) = List.fold_left2 add (Ty.Mtv.empty, Mvs.empty) vl args in
          let mt = Ty.oty_match mt e.t_ty ty in
          let mv,e = t_subst_types mt mv e in
          { value_stack = rem_st;
            cont_stack = (Keval(e,mv),orig) :: rem_cont;
          }
        end else rewrite ()
      | Decl.Dparam _ | Decl.Dind _ ->
        rewrite ()
      | Decl.Ddata dl ->
        (* constructor or projection *)
        begin try match args with
        | [ { t_node = Tapp(ls1,tl1) } ] ->
          (* if ls is a projection and ls1 is a constructor,
             we should compute that projection *)
          let rec iter dl =
            match dl with
            | [] -> raise Exit
            | (_,csl) :: rem ->
              let rec iter2 csl =
                match csl with
                | [] -> iter rem
                | (cs,prs) :: rem2 ->
                  if ls_equal cs ls1
                  then
                    (* we found the right constructor *)
                    let rec iter3 prs tl1 =
                      match prs,tl1 with
                      | (Some pr)::prs, t::tl1 ->
                        if ls_equal ls pr
                        then (* projection found! *)
                          { value_stack =
                              (Term (t_attr_copy orig t)) :: rem_st;
                            cont_stack = rem_cont;
                          }
                        else
                          iter3 prs tl1
                      | None::prs, _::tl1 ->
                        iter3 prs tl1
                      | _ -> raise Exit
                    in iter3 prs tl1
                  else iter2 rem2
              in iter2 csl
          in iter dl
        | _ -> raise Exit
        with Exit -> rewrite () end


and reduce_equ (* engine *) ~orig st v1 v2 cont =
(*
  try
*)
    match v1,v2 with
    | Int n1, Int n2 ->
      let b = to_bool (BigInt.eq n1 n2) in
      { value_stack = Term (t_attr_copy orig b) :: st;
        cont_stack = cont;
      }
    | Int n, Term {t_node = Tconst c} | Term {t_node = Tconst c}, Int n ->
      begin
        try
          let n' = big_int_of_const c in
          let b = to_bool (BigInt.eq n n') in
          { value_stack = Term (t_attr_copy orig b) :: st;
            cont_stack = cont;
          }
        with NotNum -> raise Undetermined
      end
    | Int _,  Term _ | Term _,  Int _ -> raise Undetermined
    | Term t1, Term t2 -> reduce_term_equ ~orig st t1 t2 cont
(*
  with Undetermined ->
    { value_stack = Term (t_equ (term_of_value v1) (term_of_value v2)) :: st;
      cont_stack = cont;
    }
*)

and reduce_term_equ ~orig st t1 t2 cont =
  if t_equal t1 t2 then
    { value_stack = Term (t_attr_copy orig t_true) :: st;
      cont_stack = cont;
    }
  else
  match (t1.t_node,t2.t_node) with
  | Tconst c1, Tconst c2 ->
    begin
      match c1,c2 with
      | Constant.ConstInt i1, Constant.ConstInt i2 ->
         let open Number in
         let b = BigInt.eq i1.il_int i2.il_int in
         { value_stack = Term (t_attr_copy orig (to_bool b)) :: st;
           cont_stack = cont;
         }
      | _ -> raise Undetermined
    end
  | Tapp(ls1,tl1), Tapp(ls2,tl2) when ls1.ls_constr > 0 && ls2.ls_constr > 0 ->
    if ls_equal ls1 ls2 then
      let rec aux sigma t tyl l1 l2 =
        match tyl,l1,l2 with
        | [],[],[] -> sigma,t
        | ty::tyl, t1::tl1, t2::tl2 ->
          let v1 = create_vsymbol (Ident.id_fresh "") ty in
          let v2 = create_vsymbol (Ident.id_fresh "") ty in
          aux
            (Mvs.add v1 t1 (Mvs.add v2 t2 sigma))
            (t_and_simp (t_equ (t_var v1) (t_var v2)) t)
            tyl tl1 tl2
        | _ ->  assert false
      in
      let sigma,t =
        aux Mvs.empty t_true ls1.ls_args tl1 tl2
      in
      { value_stack = st;
        cont_stack = (Keval(t,sigma),orig) :: cont;
      }
    else
      { value_stack = Term (t_attr_copy orig t_false) :: st;
        cont_stack = cont;
      }
  | Tif (b,{ t_node = Tapp(ls1,_) },{ t_node = Tapp(ls2,_) }) , Tapp(ls3,_)
    when ls_equal ls3 fs_bool_true && ls_equal ls1 fs_bool_true &&
         ls_equal ls2 fs_bool_false ->
    { value_stack = Term (t_attr_copy orig b) :: st;
      cont_stack = cont }
  | _ -> raise Undetermined



let rec reconstruct c =
  match c.value_stack, c.cont_stack with
  | [Term t], [] -> t
  | _, [] -> assert false
  | _, (k,orig) :: rem ->
    let t, st =
      match c.value_stack, k with
      | st, Keval (t,sigma) -> (t_subst sigma t), st
      | [], Kif _ -> assert false
      | v :: st, Kif(t2,t3,sigma) ->
        (t_if (term_of_value v) (t_subst sigma t2) (t_subst sigma t3)), st
      | [], Klet _ -> assert false
      | t1 :: st, Klet(v,t2,sigma) ->
        (t_let_close v (term_of_value t1) (t_subst sigma t2)), st
      | [], Kcase _ -> assert false
      | v :: st, Kcase(tbl,sigma) ->
        (t_subst sigma (t_case (term_of_value v) tbl)), st
      | ([] | [_]), Kbinop _ -> assert false
      | t1 :: t2 :: st, Kbinop op ->
        (t_binary_simp op (term_of_value t2) (term_of_value t1)), st
      | [], Knot -> assert false
      | t :: st, Knot -> (t_not (term_of_value t)), st
      | st, Kapp(ls,ty) ->
        let args,rem_st = extract_first (List.length ls.ls_args) [] st in
        let args = List.map term_of_value args in
        (t_app ls args ty), rem_st
      | [], Keps _ -> assert false
      | t :: st, Keps v -> (t_eps_close v (term_of_value t)), st
      | [], Kquant _ -> assert false
      | t :: st, Kquant(q,vl,tr) ->
        (t_quant_close_simp q vl tr (term_of_value t)), st
    in
    reconstruct {
      value_stack = (Term (t_attr_copy orig t)) :: st;
      cont_stack = rem;
    }


(** iterated reductions *)

let normalize ~limit engine t0 =
  let rec many_steps c n =
    match c.value_stack, c.cont_stack with
    | [Term t], [] -> t
    | [Int t], [] ->
      (* FIXME: what if there is an overflow *)
      let a = BigInt.to_int t in
      if a >= 0 then
        t_nat_const a
      else
        t_app_infer !ls_minus [t_nat_const (-a)]
    | _, [] -> assert false
    | _ ->
      if n = limit then
        begin
          Loc.warning "reduction of term %a takes more than %d steps, aborted.@."
            Pretty.print_term t0 limit;
          reconstruct c
        end
      else
        let c = reduce engine c in
        many_steps c (n+1)
  in
  let c = { value_stack = [];
            cont_stack = [Keval(t0,Mvs.empty),t0] ;
          }
  in
  many_steps c 0






(* the rewrite engine *)

let create p env km =
  if p.compute_builtin
  then get_builtins env
  else Hls.clear builtins;
  { known_map = km ;
    rules = Mls.empty;
    params = p;
  }

exception NotARewriteRule of string

let extract_rule _km t =
(*
  let check_ls ls =
    try let _ = Hls.find builtins ls in
        raise (NotARewriteRule "root of lhs of rule must not be a built-in symbol")
    with Not_found ->
      let d = Ident.Mid.find ls.ls_name km in
      match d.Decl.d_node with
      | Decl.Dtype _ | Decl.Dprop _ -> assert false
      | Decl.Dlogic _ ->
        raise (NotARewriteRule "root of lhs of rule must not be defined symbol")
      | Decl.Ddata _ ->
        raise (NotARewriteRule "root of lhs of rule must not be a constructor nor a projection")
      | Decl.Dparam _ | Decl.Dind _ -> ()
  in
*)

  let check_vars acc t1 t2 =
    (* check that quantified variables all appear in the lefthand side *)
    let vars_lhs = t_vars t1 in
    if Svs.exists (fun vs -> not (Mvs.mem vs vars_lhs)) acc
    then raise (NotARewriteRule "lhs should contain all variables");
    (* check the same with type variables *)
    if not
         (Ty.Stv.subset
            (t_ty_freevars Ty.Stv.empty t2) (t_ty_freevars Ty.Stv.empty t2))
    then raise (NotARewriteRule "lhs should contain all type variables")

  in

  let rec aux acc t =
    match t.t_node with
      | Tquant(Tforall,q) ->
        let vs,_,t = t_open_quant q in
        aux (List.fold_left (fun acc v -> Svs.add v acc) acc vs) t
      | Tbinop(Tiff,t1,t2) ->
        begin
          match t1.t_node with
            | Tapp(ls,args) ->
               (* check_ls ls; *)
               check_vars acc t1 t2;
               acc,ls,args,t2
            | _ -> raise
              (NotARewriteRule "lhs of <-> should be a predicate symbol")
        end
      | Tapp(ls,[t1;t2]) when ls == ps_equ ->
        begin
          match t1.t_node with
            | Tapp(ls,args) ->
               (* check_ls ls; *)
               check_vars acc t1 t2;
               acc,ls,args,t2
            | _ -> raise
              (NotARewriteRule "lhs of = should be a function symbol")
        end
      | _ -> raise
        (NotARewriteRule "rule should be of the form forall ... t1 = t2 or f1 <-> f2")
  in
  aux Svs.empty t


let add_rule t e =
  let vars,ls,args,r = extract_rule e.known_map t in
  let rules =
    try Mls.find ls e.rules
    with Not_found -> []
  in
  {e with rules =
      Mls.add ls ((vars,args,r)::rules) e.rules}
