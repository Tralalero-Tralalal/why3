(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2025 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(********************************************************************)

(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require Import ZArith.
Require Import Rbase.
Require Import Rbasic_fun.
Require int.Int.
Require real.Real.
Require real.Abs.
Require real.FromInt.
Require floating_point.Rounding.

Require Import Lia.
Require Import Flocq.Core.Core.
Require Import Flocq.IEEE754.BinarySingleNaN.
Require Import int.Abs.

Section GenFloat.
Global Coercion B2R_coercion prec emax := @B2R prec emax.

Variable prec emax : Z.
Hypothesis Hprec : Zlt_bool 0 prec = true.
Hypothesis Hemax : Zlt_bool prec emax = true.
Let emin := (3 - emax - prec)%Z.
Notation fexp := (FLT_exp emin prec).

Lemma Hprec': (0 < prec)%Z. revert Hprec. now case Zlt_bool_spec. Qed.
Lemma Hemax': (prec < emax)%Z. revert Hemax. now case Zlt_bool_spec. Qed.

Instance Hprec'' : Prec_gt_0 prec := Hprec'.

Record t : Set := mk_fp {
  binary : binary_float prec emax;
  value := (binary : R);
  exact : R;
  model : R
}.

Lemma t_inv :
  forall x xe xm y ye ym,
  (x = y -> xe = ye -> xm = ym -> False) ->
  (mk_fp x xe xm <> mk_fp y ye ym).
Proof.
intros x xe xm y ye ym H H'.
apply H.
exact (f_equal binary H').
exact (f_equal exact H').
exact (f_equal model H').
Qed.

Lemma t_WhyType : WhyType t.
Proof with
match goal with
| _ => try ( right ; apply t_inv ; easy )
end.
split.
split.
apply B754_zero.
exact false.
exact R0.
exact R0.
intros x y.
destruct x as (x,xv,xe,xm).
destruct y as (y,yv,ye,ym).
destruct (Req_EM_T xe ye) as [He|He]...
destruct (Req_EM_T xm ym) as [Hm|Hm]...
rewrite He, Hm.
destruct x as [xs|xs| |xs xm' xe' xH] ;
  destruct y as [ys|ys| |ys ym' ye' yH]...
clear.
destruct (Bool.bool_dec xs ys) as [->|Hs].
now left.
right.
apply t_inv.
intros H _ _.
now injection H.
clear.
destruct (Bool.bool_dec xs ys) as [->|Hs].
now left.
right.
apply t_inv.
intros H _ _.
now injection H.
now left.
destruct (Req_EM_T xv yv) as [Hv|Hv].
left.
apply f_equal3 ; try easy.
now apply B2R_inj.
right.
apply t_inv.
intros H _ _.
apply Hv.
now apply f_equal.
Qed.

Record t_strict: Set := mk_fp_strict {
  datum :> t;
  finite : is_finite (binary datum) = true
}.

Import Rounding.
Definition rnd_of_mode (m:mode) :=
  match m with
  |  NearestTiesToEven => mode_NE
  |  ToZero            => mode_ZR
  |  Up                => mode_UP
  |  Down              => mode_DN
  |  NearestTiesToAway => mode_NA
  end.

Definition r_to_fp rnd x : binary_float prec emax :=
  let r := round radix2 fexp (round_mode rnd) x in
  let m := Ztrunc (scaled_mantissa radix2 fexp r) in
  let e := cexp radix2 fexp r in
  binary_normalize prec emax Hprec' Hemax' rnd m e false.

Theorem r_to_fp_correct :
  forall rnd x,
  let r := round radix2 fexp (round_mode rnd) x in
  (Rabs r < bpow radix2 emax)%R ->
  is_finite (r_to_fp rnd x) = true /\
  r_to_fp rnd x = r :>R.
Proof with auto with typeclass_instances.
intros rnd x r Bx.
unfold r_to_fp. fold r.
generalize (binary_normalize_correct prec emax Hprec' Hemax' rnd (Ztrunc (scaled_mantissa radix2 fexp r)) (cexp radix2 fexp r) false).
unfold r.
elim generic_format_round...
fold emin r.
rewrite round_generic...
rewrite Rlt_bool_true with (1 := Bx).
now split.
apply generic_format_round...
Qed.

Theorem r_to_fp_format :
  forall rnd x,
  FLT_format radix2 emin prec x ->
  (Rabs x < bpow radix2 emax)%R ->
  r_to_fp rnd x = x :>R.
Proof with auto with typeclass_instances.
intros rnd x Fx Bx.
assert (Gx: generic_format radix2 fexp x).
apply generic_format_FLT.
apply Fx.
pattern x at 2 ; rewrite <- round_generic with (rnd := round_mode rnd) (2 := Gx)...
refine (proj2 (r_to_fp_correct _ _ _)).
rewrite round_generic...
Qed.

Definition r_to_fp_aux (m:mode) (r r1 r2:R) :=
  mk_fp (r_to_fp (rnd_of_mode m) r) r1 r2.

(* Why3 goal *)
Definition round: floating_point.Rounding.mode -> R -> R.
exact (fun m => round radix2 fexp (round_mode (rnd_of_mode m))).
Defined.

(* Why3 assumption *)
Definition round_error(x:t): R := (Rabs ((value x) - (exact x))%R).

(* Why3 assumption *)
Definition total_error(x:t): R := (Rabs ((value x) - (model x))%R).

(* Why3 goal *)
Definition max: R.
exact (F2R (Float radix2 (Zpower 2 prec - 1) (emax - prec))).
Defined.

(* Why3 assumption *)
Definition no_overflow(m:floating_point.Rounding.mode) (x:R): Prop :=
  ((Rabs (round m x)) <= max)%R.

(* Why3 goal *)
Lemma Bounded_real_no_overflow : forall (m:floating_point.Rounding.mode)
  (x:R), ((Rabs x) <= max)%R -> (no_overflow m x).
Proof with auto with typeclass_instances.
intros m x Hx.
apply Rabs_le.
assert (generic_format radix2 fexp max).
apply generic_format_F2R.
intros H.
unfold cexp.
rewrite mag_F2R with (1 := H).
rewrite (mag_unique _ _ prec).
ring_simplify (prec + (emax - prec))%Z.
unfold FLT_exp.
rewrite Z.max_l.
apply Z.le_refl.
unfold emin.
generalize Hprec' Hemax' ; clear ; lia.
rewrite <- abs_IZR, Z.abs_eq, <- 2!IZR_Zpower.
split.
apply IZR_le.
apply Zlt_succ_le.
change (2 ^ prec - 1)%Z with (Z.pred (2^prec))%Z.
rewrite <- Zsucc_pred.
apply lt_IZR.
change 2%Z with (radix_val radix2).
rewrite 2!IZR_Zpower.
apply bpow_lt.
apply Zlt_pred.
apply Zlt_le_weak.
exact Hprec'.
generalize Hprec' ; clear ; lia.
apply IZR_lt.
apply Zlt_pred.
apply Zlt_le_weak.
exact Hprec'.
generalize Hprec' ; clear ; lia.
apply Zlt_succ_le.
change (2 ^ prec - 1)%Z with (Z.pred (2^prec))%Z.
rewrite <- Zsucc_pred.
change 2%Z with (radix_val radix2).
apply Zpower_gt_0.
apply Zlt_le_weak.
exact Hprec'.
generalize (Rabs_le_inv _ _ Hx).
split.
apply round_ge_generic...
now apply generic_format_opp.
apply H0.
apply round_le_generic...
apply H0.
Qed.

(* Why3 goal *)
Lemma Round_monotonic : forall (m:floating_point.Rounding.mode) (x:R) (y:R),
  (x <= y)%R -> ((round m x) <= (round m y))%R.
Proof with auto with typeclass_instances.
intros m x y Hxy.
apply round_le with (3 := Hxy)...
Qed.

(* Why3 goal *)
Lemma Round_idempotent : forall (m1:floating_point.Rounding.mode)
  (m2:floating_point.Rounding.mode) (x:R), ((round m1 (round m2
  x)) = (round m2 x)).
Proof with auto with typeclass_instances.
intros m1 m2 x.
apply round_generic...
apply generic_format_round...
Qed.

(* Why3 goal *)
Lemma Round_value : forall (m:floating_point.Rounding.mode) (x:t), ((round m
  (value x)) = (value x)).
Proof with auto with typeclass_instances.
intros m x.
apply round_generic...
apply generic_format_B2R.
Qed.

(* Why3 goal *)
Lemma Bounded_value : forall (x:t), ((Rabs (value x)) <= max)%R.
Proof with auto with typeclass_instances.
intros x.
replace max with (pred radix2 fexp (bpow radix2 emax)).
apply pred_ge_gt...
apply generic_format_abs.
apply generic_format_B2R.
apply generic_format_bpow.
unfold FLT_exp, emin.
zify ; generalize Hprec' Hemax' ; lia.
apply abs_B2R_lt_emax.
rewrite pred_eq_pos.
unfold pred_pos.
rewrite mag_bpow.
ring_simplify (emax+1-1)%Z.
rewrite Req_bool_true by easy.
unfold FLT_exp, emin.
rewrite Z.max_l.
unfold max, F2R; simpl.
pattern emax at 1; replace emax with (prec+(emax-prec))%Z by ring.
rewrite bpow_plus.
change 2%Z with (radix_val radix2).
rewrite minus_IZR, IZR_Zpower.
simpl; ring.
apply Zlt_le_weak.
exact Hprec'.
generalize Hprec' Hemax' ; lia.
apply bpow_ge_0.
Qed.

(* Why3 goal *)
Definition max_representable_integer: Z.
exact (Zpower 2 prec).
Defined.

(* Why3 goal *)
Lemma Exact_rounding_for_integers : forall (m:floating_point.Rounding.mode)
  (i:Z), (((-max_representable_integer)%Z <= i)%Z /\
  (i <= max_representable_integer)%Z) -> ((round m (IZR i)) = (IZR i)).
Proof with auto with typeclass_instances.
intros m z Hz.
apply round_generic...
assert (Z.abs z <= max_representable_integer)%Z.
apply Abs_le with (1:=Hz).
destruct (Zle_lt_or_eq _ _ H) as [Bz|Bz] ; clear H Hz.
apply generic_format_FLT.
exists (Float radix2 z 0).
unfold F2R ; simpl.
now rewrite Rmult_1_r.
easy.
simpl; unfold emin; generalize Hprec' Hemax'; lia.
unfold max_representable_integer in Bz.
change 2%Z with (radix_val radix2) in Bz.
apply generic_format_abs_inv.
rewrite <- abs_IZR, Bz, IZR_Zpower.
apply generic_format_bpow.
unfold FLT_exp, emin.
clear Bz; generalize Hprec' Hemax'; zify.
lia.
apply Zlt_le_weak.
apply Hprec'.
Qed.

(* Why3 goal *)
Lemma Round_down_le : forall (x:R), ((round floating_point.Rounding.Down
  x) <= x)%R.
Proof with auto with typeclass_instances.
intros x.
apply round_DN_pt...
Qed.

(* Why3 goal *)
Lemma Round_up_ge : forall (x:R), (x <= (round floating_point.Rounding.Up
  x))%R.
Proof with auto with typeclass_instances.
intros x.
apply round_UP_pt...
Qed.

(* Why3 goal *)
Lemma Round_down_neg : forall (x:R), ((round floating_point.Rounding.Down
  (-x)%R) = (-(round floating_point.Rounding.Up x))%R).
Proof.
intros x.
apply round_opp.
Qed.

(* Why3 goal *)
Lemma Round_up_neg : forall (x:R), ((round floating_point.Rounding.Up
  (-x)%R) = (-(round floating_point.Rounding.Down x))%R).
Proof.
intros x.
pattern x at 2 ; rewrite <- Ropp_involutive.
rewrite Round_down_neg.
now rewrite Ropp_involutive.
Qed.

(* Why3 goal *)
Definition round_logic: floating_point.Rounding.mode -> R -> t.
exact (fun m r => r_to_fp_aux m r r r).
Defined.

(* Why3 goal *)
Lemma Round_logic_def : forall (m:floating_point.Rounding.mode) (x:R),
  (no_overflow m x) -> ((value (round_logic m x)) = (round m x)).
Proof.
intros m x h1.
unfold value, round_logic.
simpl.
apply r_to_fp_correct.
apply Rle_lt_trans with (1 := h1).
replace emax with (prec + (emax - prec))%Z by ring.
rewrite bpow_plus.
apply Rmult_lt_compat_r.
apply bpow_gt_0.
simpl.
rewrite <- IZR_Zpower.
apply IZR_lt.
apply Zlt_pred.
apply Zlt_le_weak.
exact Hprec'.
Qed.

End GenFloat.
