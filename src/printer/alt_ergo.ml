(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2025 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(********************************************************************)

(** Alt-ergo printer *)

open Format
open Pp
open Wstdlib
open Ident
open Ty
open Term
open Decl
open Printer
open Cntexmp_printer

let meta_ac = Theory.register_meta "AC" [Theory.MTlsymbol]
  ~desc:"Specify@ that@ a@ symbol@ is@ associative@ and@ commutative."

let meta_printer_option =
  Theory.register_meta "printer_option" [Theory.MTstring]
    ~desc:"Pass@ additional@ parameters@ to@ the@ pretty-printer."

let meta_invalid_trigger =
  Theory.register_meta "invalid trigger" [Theory.MTlsymbol]
  ~desc:"Specify@ that@ a@ symbol@ is@ not@ allowed@ in@ a@ trigger."

type info = {
  info_syn : syntax_map;
  info_ac  : Sls.t;
  info_show_attrs : bool;
  info_type_casts : bool;
  mutable info_csm : string list Mls.t;
  info_inv_trig : Sls.t;
  info_printer : ident_printer;
  mutable info_model: S.t;
  info_vc_term: vc_term_info;
  info_in_goal: bool;
  info_cntexample: bool
  }

let ident_printer () =
  let bls = [
    "abs_int"; "abs_real"; "ac"; "and"; "array"; "as"; "axiom";
    "bitv"; "bool"; "case_split"; "check"; "cut"; "distinct";
    "else"; "end"; "exists"; "extends";
    "false"; "float"; "float32"; "float32d"; "float64"; "float64d";
    "forall"; "fpa_rounding_mode"; "function";
    "goal";
    "if"; "in"; "include"; "int"; "int_ceil"; "int_floor";
    "integer_log2"; "integer_round"; "is_theory_constant"; "inversion";
    "let"; "linear_dependency"; "logic";
    "max_int"; "max_real"; "min_int"; "min_real";
    "not"; "not_theory_constant"; "of"; "or";
    "parameter"; "predicate"; "pow_real_int"; "pow_real_real";
    "prop";
    "real"; "real_of_int"; "rewriting";
    "select"; "sqrt_real"; "sqrt_real_default"; "sqrt_real_excess"; "store";
    "then"; "theory"; "true"; "type"; "unit"; "void"; "with";
    "Aw"; "Down"; "Od";
    "NearestTiesToAway"; "NearestTiesToEven"; "Nd"; "No"; "Nu"; "Nz";
    "ToZero"; "Up";
  ]
  in
  let san = sanitizer char_to_alpha char_to_alnumus in
  create_ident_printer bls ~sanitizer:san

let print_ident info fmt id =
  pp_print_string fmt (id_unique info.info_printer id)

let print_attr fmt l = fprintf fmt "\"%s\"" l.attr_string

let print_ident_attr info fmt id =
  if info.info_show_attrs then
    fprintf fmt "%s %a"
      (id_unique info.info_printer id)
      (print_list space print_attr) (Sattr.elements id.id_attrs)
  else
    print_ident info fmt id

let forget_var info v = forget_id info.info_printer v.vs_name

let collect_model_ls info ls =
  if relevant_for_counterexample ls.ls_name then
    info.info_model <-
      add_model_element (ls, ls.ls_name.id_loc, ls.ls_name.id_attrs) info.info_model

(*
let tv_printer =
  let san = sanitizer char_to_lalpha char_to_alnumus in
  create_ident_printer [] ~sanitizer:san

let print_tvsymbol fmt tv =
  fprintf fmt "'%s" (id_unique tv_printer tv.tv_name)

let forget_tvs () = forget_all tv_printer
*)

(* work around a "duplicate type variable" bug of Alt-Ergo 0.94 *)
let print_tvsymbol, forget_tvs =
  let htv = Hid.create 5 in
  (fun info fmt tv ->
    Hid.replace htv tv.tv_name ();
    fprintf fmt "'%s" (id_unique info.info_printer tv.tv_name)),
  (fun info ->
    Hid.iter (fun id _ -> forget_id info.info_printer id) htv;
    Hid.clear htv)

let rec print_type info fmt ty = match ty.ty_node with
  | Tyvar id ->
      print_tvsymbol info fmt id
  | Tyapp (ts, tl) -> begin match query_syntax info.info_syn ts.ts_name with
      | Some s -> syntax_arguments s (print_type info) fmt tl
      | None -> fprintf fmt "%a%a" (print_tyapp info) tl
          (print_ident info) ts.ts_name
    end

and print_tyapp info fmt = function
  | [] -> ()
  | [ty] -> fprintf fmt "%a " (print_type info) ty
  | tl -> fprintf fmt "(%a) " (print_list comma (print_type info)) tl

(* can the type of a value be derived from the type of the arguments? *)
let unambig_fs fs =
  let rec lookup v ty = match ty.ty_node with
    | Tyvar u when tv_equal u v -> true
    | _ -> ty_any (lookup v) ty
  in
  let lookup v = List.exists (lookup v) fs.ls_args in
  let rec inspect ty = match ty.ty_node with
    | Tyvar u when not (lookup u) -> false
    | _ -> ty_all inspect ty
  in
  inspect (Option.get fs.ls_value)

let number_format = {
    Number.long_int_support = `Default;
    Number.negative_int_support = `Default;
    Number.dec_int_support = `Default;
    Number.hex_int_support = `Unsupported;
    Number.oct_int_support = `Unsupported;
    Number.bin_int_support = `Unsupported;
    Number.negative_real_support = `Default;
    Number.dec_real_support = `Default;
    Number.hex_real_support = `Default;
    Number.frac_real_support = `Unsupported (fun _ _ -> assert false);
  }

let rec print_term info fmt t =
  if check_for_counterexample t then
    begin match t.t_node with
    | Tapp (ls,_) ->
      info.info_model <- add_model_element (ls,t.t_loc,t.t_attrs) info.info_model
    | _ -> assert false (* cannot happen because check_for_counterexample is true *)
    end;

  check_enter_vc_term t info.info_in_goal info.info_vc_term;

  let () = match t.t_node with
  | Tconst c ->
      let ts = match t.t_ty with
        | Some { ty_node = Tyapp (ts, []) } ->
            ts
        | _ -> assert false (* impossible *)
      in
      if ts_equal ts ts_int || ts_equal ts ts_real || ts_equal ts ts_str then
        Constant.(print number_format unsupported_escape) fmt c
      else
        unsupportedTerm t
          "alt-ergo printer: don't know how to print this literal, consider adding a syntax rule in the driver"

  | Tvar { vs_name = id } ->
      print_ident info fmt id
  | Tapp (ls, tl) ->
     begin
       match query_syntax info.info_syn ls.ls_name with
       | Some s -> syntax_arguments s (print_term info) fmt tl
       | None ->
	  begin
	    if (tl = []) then
	      begin
		let vc_term_info = info.info_vc_term in
		if vc_term_info.vc_inside then begin
		  match vc_term_info.vc_loc with
		  | None -> ()
		  | Some loc ->
                    let attrs = (*match vc_term_info.vc_func_name with
                      | None ->*)
                          ls.ls_name.id_attrs
                      (*| Some _ ->
                          model_trace_for_postcondition ~attrs:ls.ls_name.id_attrs info.info_vc_term
                       *)
                    in
                    let _t_check_pos = t_attr_set ~loc attrs t in
		      (* TODO: temporarily disable collecting variables inside the term triggering VC *)
		      (*info.info_model <- add_model_element t_check_pos info.info_model;*)
		      ()
		end
	      end;
	  end;
	  if (Mls.mem ls info.info_csm) then
	    begin
              let print_field fmt (id,t) =
		fprintf fmt "%s =@ %a" id (print_term info) t in
              fprintf fmt "{@ %a@ }" (print_list semi print_field)
		(List.combine (Mls.find ls info.info_csm) tl)
	    end
	  else if ls.ls_proj then
	    begin
              fprintf fmt "%a.%a" (print_tapp info) tl (print_ident info) ls.ls_name
	    end
	  else if (unambig_fs ls || not info.info_type_casts) then
	    begin
              fprintf fmt "%a%a" (print_ident info) ls.ls_name (print_tapp info) tl
	    end
	  else
	    begin
	      fprintf fmt "(%a%a : %a)" (print_ident info) ls.ls_name
		(print_tapp info) tl (print_type info) (t_type t)
	    end
     end
  | Tlet (t1, tb) ->
      let v, t2 = t_open_bound tb in
      fprintf fmt "(let %a =@ %a@ : %a in@ %a)"
        (print_ident info) v.vs_name
        (print_term info) t1
         (* some version of alt-ergo have an inefficient typing of let *)
        (print_type info) v.vs_ty
        (print_term info) t2;
      forget_var info v
  | Tif(t1,t2,t3) ->
     fprintf fmt "(if %a then %a else %a)"
       (print_fmla info) t1 (print_term info) t2 (print_term info) t3
  | Tcase _ -> unsupportedTerm t
      "alt-ergo: you must eliminate match"
  | Teps _ -> unsupportedTerm t
      "alt-ergo: you must eliminate epsilon"
  | Tquant _ | Tbinop _ | Tnot _ | Ttrue | Tfalse -> raise (TermExpected t)
  in
  check_exit_vc_term t info.info_in_goal info.info_vc_term;


and print_tapp info fmt = function
  | [] -> ()
  | tl -> fprintf fmt "(%a)" (print_list comma (print_term info)) tl

and print_fmla info fmt f =
  if check_for_counterexample f then
    begin match f.t_node with
    | Tapp (ls,_) ->
      info.info_model <- add_model_element (ls,f.t_loc,f.t_attrs) info.info_model
    | _ -> assert false (* cannot happen because check_for_counterexample is true *)
    end;
  check_enter_vc_term f info.info_in_goal info.info_vc_term;

  let () = if info.info_show_attrs then
    match Sattr.elements f.t_attrs with
      | [] -> print_fmla_node info fmt f
      | l ->
        fprintf fmt "(%a : %a)"
          (print_list colon print_attr) l
          (print_fmla_node info) f
  else
    print_fmla_node info fmt f
  in
  check_exit_vc_term f info.info_in_goal info.info_vc_term

and print_fmla_node info fmt f = match f.t_node with
  | Tapp ({ ls_name = id }, []) ->
      print_ident info fmt id
  | Tapp (ls, tl) -> begin match query_syntax info.info_syn ls.ls_name with
      | Some s -> syntax_arguments s (print_term info) fmt tl
      | None -> fprintf fmt "%a(%a)" (print_ident info) ls.ls_name
                    (print_list comma (print_term info)) tl
    end
  | Tquant (q, fq) ->
      let vl, tl, f = t_open_quant fq in
      let q, tl = match q with
        | Tforall -> "forall", tl
        | Texists -> "exists", [] (* Alt-ergo has no triggers for exists *)
      in
      let forall fmt v =
        fprintf fmt "%s %a:%a" q (print_ident_attr info) v.vs_name
          (print_type info) v.vs_ty
      in
      fprintf fmt "@[(%a%a.@ %a)@]" (print_list dot forall) vl
        (print_triggers info) tl (print_fmla info) f;
      List.iter (forget_var info) vl
  | Tbinop (Tand, f1, f2) ->
      fprintf fmt "(%a and@ %a)" (print_fmla info) f1 (print_fmla info) f2
  | Tbinop (Tor, f1, f2) ->
      fprintf fmt "(%a or@ %a)" (print_fmla info) f1 (print_fmla info) f2
  | Tbinop (Timplies, f1, f2) ->
      fprintf fmt "(%a ->@ %a)" (print_fmla info) f1 (print_fmla info) f2
  | Tbinop (Tiff, f1, f2) ->
      fprintf fmt "(%a <->@ %a)" (print_fmla info) f1 (print_fmla info) f2
  | Tnot f ->
      fprintf fmt "(not %a)" (print_fmla info) f
  | Ttrue ->
      pp_print_string fmt "true"
  | Tfalse ->
      pp_print_string fmt "false"
  | Tif(t1,t2,t3) ->
     fprintf fmt "(if %a then %a else %a)"
       (print_fmla info) t1 (print_fmla info) t2 (print_fmla info) t3
  | Tlet (t1, tb) ->
      let v, f2 = t_open_bound tb in
      fprintf fmt "(let %a =@ %a@ : %a in@ %a)"
        (print_ident info) v.vs_name
        (print_term info) t1
         (* some version of alt-ergo have an inefficient typing of let *)
        (print_type info) v.vs_ty
        (print_fmla info) f2;
      forget_var info v
  | Tcase _ -> unsupportedTerm f
      "alt-ergo: you must eliminate match"
  | Tvar _ | Tconst _ | Teps _ -> raise (FmlaExpected f)

and print_expr info fmt =
  TermTF.t_select (print_term info fmt) (print_fmla info fmt)

and print_triggers info fmt tl =
  let filter = function
    | { t_ty = Some _ } -> true
    | { t_node = Tapp (ps,_) } -> not (Sls.mem ps info.info_inv_trig)
    | _ -> false in
  let tl = List.map (List.filter filter) tl in
  let tl = List.filter (function [] -> false | _::_ -> true) tl in
  if tl = [] then () else fprintf fmt "@ [%a]"
    (print_list alt (print_list comma (print_expr info))) tl

let print_logic_binder info fmt v =
  fprintf fmt "%a: %a" (print_ident info) v.vs_name (print_type info) v.vs_ty

let print_type_decl info fmt ts = match ts.ts_args with
  | [] -> fprintf fmt "type %a"
      (print_ident info) ts.ts_name
  | [tv] -> fprintf fmt "type %a %a"
      (print_tvsymbol info) tv (print_ident info) ts.ts_name
  | tl -> fprintf fmt "type (%a) %a"
      (print_list comma (print_tvsymbol info)) tl (print_ident info) ts.ts_name

let print_enum_decl info fmt ts csl =
  let print_cs fmt (ls,_) = print_ident info fmt ls.ls_name in
  fprintf fmt "@[<hov 2>type %a =@ %a@]@\n@\n" (print_ident info) ts.ts_name
    (print_list alt2 print_cs) csl

let print_ty_decl info fmt ts =
  if is_alias_type_def ts.ts_def then () else
  if Mid.mem ts.ts_name info.info_syn then () else
  (fprintf fmt "%a@\n@\n" (print_type_decl info) ts; forget_tvs info)

let print_data_decl info d fmt = function
  | ts, csl (* monomorphic enumeration *)
    when ts.ts_args = [] && List.for_all (fun (_,l) -> l = []) csl ->
      print_enum_decl info fmt ts csl
  | ts, [cs,pjl] (* records *) ->
      if Sid.mem ts.ts_name (get_used_syms_decl d) then
        unsupported "alt-ergo: recursive records are not supported";
      let field_name_ty pj ty =
        let pj =
          match pj with
          | Some pj -> pj.ls_name
          | None ->
             let field_name = id_fresh (cs.ls_name.id_string^"_proj") in
             let field_name = create_vsymbol field_name ty(*dummy*) in
             field_name.vs_name
        in
        let pj = sprintf "%a" (print_ident info) pj in
        pj,ty
      in
      let l = List.map2 field_name_ty pjl cs.ls_args in
      info.info_csm <- Mls.add cs (List.map fst l) info.info_csm;
      let print_field fmt (pj,ty) =
        fprintf fmt "%s@ :@ %a" pj (print_type info) ty
      in
      fprintf fmt "%a@ =@ {@ %a@ }@\n@\n" (print_type_decl info) ts
        (print_list semi print_field) l
  | _, _ -> unsupported
      "alt-ergo: algebraic datatype are not supported"

let print_data_decl info d fmt ((ts, _csl) as p) =
  if Mid.mem ts.ts_name info.info_syn then () else
  print_data_decl info d fmt p

let print_param_decl info fmt ls =
  let sac = if Sls.mem ls info.info_ac then "ac " else "" in
  fprintf fmt "@[<hov 2>logic %s%a : %a%s%a@]@\n@\n"
    sac (print_ident info) ls.ls_name
    (print_list comma (print_type info)) ls.ls_args
    (if ls.ls_args = [] then "" else " -> ")
    (print_option_or_default "prop" (print_type info)) ls.ls_value

let print_param_decl info fmt ls =
  if Mid.mem ls.ls_name info.info_syn then () else
  (print_param_decl info fmt ls; forget_tvs info)

let print_logic_decl info fmt ls ld =
  collect_model_ls info ls;
  let vl,e = open_ls_defn ld in
  begin match e.t_ty with
    | Some _ ->
        (* TODO AC? *)
        fprintf fmt "@[<hov 2>function %a(%a) : %a =@ %a@]@\n@\n"
          (print_ident info) ls.ls_name
          (print_list comma (print_logic_binder info)) vl
          (print_type info) (Option.get ls.ls_value)
          (print_term info) e
    | None ->
        fprintf fmt "@[<hov 2>predicate %a(%a) =@ %a@]@\n@\n"
          (print_ident info) ls.ls_name
          (print_list comma (print_logic_binder info)) vl
          (print_fmla info) e
  end;
  List.iter (forget_var info) vl

let print_logic_decl info fmt (ls,ld) =
  if Mid.mem ls.ls_name info.info_syn then () else
  (print_logic_decl info fmt ls ld; forget_tvs info)

let print_info_model info =
  (* Prints the content of info.info_model *)
  let info_model = info.info_model in
  if not (S.is_empty info_model) && info.info_cntexample then
    begin
      let model_map =
        S.fold
          (fun ((ls,_,_) as el) acc ->
            let s = asprintf "%a" (print_ident info) ls.ls_name in
            Mstr.add s el acc)
          info_model
          Mstr.empty in ();

        (* Printing model has modification of info.info_model as undesirable
        side-effect. Revert it back. *)
        info.info_model <- info_model;
        model_map
    end
  else
    Mstr.empty

let print_prop_decl vc_loc vc_attrs env printing_info info fmt k pr f =
  match k with
  | Paxiom ->
      fprintf fmt "@[<hov 2>axiom %a :@ %a@]@\n@\n"
        (print_ident info) pr.pr_name (print_fmla info) f
  | Pgoal ->
      let model_list = print_info_model info in
      printing_info := Some {
        why3_env = env;
        vc_term_loc = vc_loc;
        vc_term_attrs = vc_attrs;
        queried_terms = model_list;
        type_coercions = Mty.empty;
        type_fields = Mty.empty;
        type_sorts = Mstr.empty;
        record_fields = Mls.empty;
        constructors = Mstr.empty;
        set_str = Mstr.empty;
      };
      fprintf fmt "@[<hov 2>goal %a :@ %a@]@\n"
        (print_ident info) pr.pr_name (print_fmla info) f
  | Plemma -> assert false

let print_prop_decl vc_loc vc_attrs env printing_info info fmt k pr f =
  if Mid.mem pr.pr_name info.info_syn
    then () else (print_prop_decl vc_loc vc_attrs env printing_info info fmt k pr f; forget_tvs info)

let print_decl vc_loc vc_attrs env printing_info info fmt d =
  match d.d_node with
  | Dtype ts ->
      print_ty_decl info fmt ts
  | Ddata dl ->
      print_list nothing (print_data_decl info d) fmt dl
  | Dparam ls ->
      collect_model_ls info ls;
      print_param_decl info fmt ls
  | Dlogic dl ->
      print_list nothing (print_logic_decl info) fmt dl
  | Dind _ -> unsupportedDecl d
      "alt-ergo: inductive definitions are not supported"
  | Dprop (k,pr,f) -> print_prop_decl vc_loc vc_attrs env printing_info info fmt k pr f

let check_options ((show,cast) as acc) = function
  | [Theory.MAstr "show_attrs"] -> true, cast
  | [Theory.MAstr "no_type_cast"] -> show, false
  | [Theory.MAstr _] -> acc
  | _ -> assert false

let print_task args ?old:_ fmt task =
  let inv_trig = Task.on_tagged_ls meta_invalid_trigger task in
  let show,cast = Task.on_meta meta_printer_option
    check_options (false,true) task in
  let cntexample = Driver.get_counterexmp task in
  let g,_ = Task.task_separate_goal task in
  let vc_loc =
    Theory.(match g.td_node with
        | Decl { d_node = Dprop (_,_,t) } -> t.t_loc
        | _ -> None)
  in
  let vc_attrs = (Task.task_goal_fmla task).t_attrs in
  let vc_info = {vc_inside = false; vc_loc; vc_func_name = None} in
  let info = {
    info_syn = Discriminate.get_syntax_map task;
    info_ac  = Task.on_tagged_ls meta_ac task;
    info_show_attrs = show;
    info_type_casts = cast;
    info_csm = Mls.empty;
    info_inv_trig = Sls.add ps_equ inv_trig;
    info_printer = ident_printer ();
    info_model = S.empty;
    info_vc_term = vc_info;
    info_in_goal = false;
    info_cntexample = cntexample;
  } in
  print_prelude fmt args.prelude;
  print_th_prelude task fmt args.th_prelude;
  let rec print_decls = function
    | Some t ->
        print_decls t.Task.task_prev;
        begin match t.Task.task_decl.Theory.td_node with
        | Theory.Decl d ->
            begin try print_decl vc_loc vc_attrs args.env args.printing_info info fmt d
            with Unsupported s -> raise (UnsupportedDecl (d,s)) end
        | _ -> () end
    | None -> () in
  print_decls task;
  pp_print_flush fmt ()

let () = register_printer "alt-ergo" print_task
  ~desc:"Printer for the Alt-Ergo theorem prover."
