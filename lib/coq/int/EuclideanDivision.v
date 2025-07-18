(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2025 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(********************************************************************)

(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require int.Abs.

Require Import Lia.

(* Why3 goal *)
Definition div : Numbers.BinNums.Z -> Numbers.BinNums.Z -> Numbers.BinNums.Z.
Proof.
intros x y.
case (Z_le_dec 0 (Zmod x y)) ; intros H.
exact (Z.div x y).
exact (Z.div x y + 1)%Z.
Defined.

(* Why3 goal *)
Definition mod1 :
  Numbers.BinNums.Z -> Numbers.BinNums.Z -> Numbers.BinNums.Z.
Proof.
intros x y.
exact (x - y * div x y)%Z.
Defined.

(* Why3 goal *)
Lemma Div_mod :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z), ~ (y = 0%Z) ->
  (x = ((y * (div x y))%Z + (mod1 x y))%Z).
Proof.
intros x y Zy.
unfold mod1, div.
case Z_le_dec ; intros H ; ring.
Qed.

(* Why3 goal *)
Lemma Mod_bound :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z), ~ (y = 0%Z) ->
  (0%Z <= (mod1 x y))%Z /\ ((mod1 x y) < (ZArith.BinInt.Z.abs y))%Z.
Proof.
intros x y Zy.
assert (H := Zabs_spec y).
assert (H1 := Z_mod_neg x y).
assert (H2 := Z_mod_lt x y).
unfold mod1, div.
case Z_le_dec ; intros H0.
rewrite Zmult_comm, <- Zmod_eq_full with (1 := Zy).
lia.
replace (x - y * (x / y + 1))%Z with (x - x / y * y - y)%Z by ring.
rewrite <- Zmod_eq_full with (1 := Zy).
lia.
Qed.

(* Why3 goal *)
Lemma Div_unique :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z) (q:Numbers.BinNums.Z),
  (0%Z < y)%Z -> ((q * y)%Z <= x)%Z /\ (x < ((q * y)%Z + y)%Z)%Z ->
  ((div x y) = q).
Proof.
intros x y q h1 (h2,h3).
assert (h:(~(y=0))%Z) by lia.
generalize (Mod_bound x y h); intro h0.
rewrite Z.abs_eq in h0; auto with zarith.
generalize (Div_mod x y h); clear h; intro h.
assert (cases:(div x y = q \/ (div x y <= q - 1 \/ div x y >= q+1))%Z) by lia.
destruct cases as [h4 | [h5 | h6]]; auto.
assert (y * div x y <= y * (q - 1))%Z.
 apply  Zmult_le_compat_l; auto with zarith.
replace (y*(q-1))%Z with (q*y - y)%Z in H by ring.
exfalso; lia.
assert (y * div x y >= y * (q + 1))%Z.
 apply  Zmult_ge_compat_l; auto with zarith.
replace (y*(q+1))%Z with (q*y + y)%Z in H by ring.
exfalso; lia.
Qed.

(* Why3 goal *)
Lemma Div_bound :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z),
  (0%Z <= x)%Z /\ (0%Z < y)%Z -> (0%Z <= (div x y))%Z /\ ((div x y) <= x)%Z.
Proof.
intros x y (Hx,Hy).
unfold div.
case Z_le_dec ; intros H.
split.
apply Z_div_pos with (2 := Hx).
now apply Z.lt_gt.
destruct (Z.eq_dec y 1) as [H'|H'].
rewrite H', Zdiv_1_r.
apply Z.le_refl.
rewrite <- (Zdiv_1_r x) at 2.
apply Zdiv_le_compat_l with (1 := Hx).
lia.
elim H.
apply Z_mod_lt.
now apply Z.lt_gt.
Qed.

(* Why3 goal *)
Lemma Mod_1 : forall (x:Numbers.BinNums.Z), ((mod1 x 1%Z) = 0%Z).
Proof.
intros x.
unfold mod1, div.
rewrite Zmod_1_r, Zdiv_1_r, Zmult_1_l.
apply Zminus_diag.
Qed.

(* Why3 goal *)
Lemma Div_1 : forall (x:Numbers.BinNums.Z), ((div x 1%Z) = x).
Proof.
intros x.
unfold div.
now rewrite Zmod_1_r, Zdiv_1_r.
Qed.

(* Why3 goal *)
Lemma Div_inf :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z),
  (0%Z <= x)%Z /\ (x < y)%Z -> ((div x y) = 0%Z).
Proof.
intros x y Hxy.
unfold div.
case Z_le_dec ; intros H.
now apply Zdiv_small.
elim H.
now rewrite Zmod_small.
Qed.

(* Why3 goal *)
Lemma Div_inf_neg :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z),
  (0%Z < x)%Z /\ (x <= y)%Z -> ((div (-x)%Z y) = (-1%Z)%Z).
Proof.
intros x y Hxy.
assert (h: (x < y \/ x = y)%Z) by lia.
destruct h.
(* case 0 < x < y *)
assert (h1: (x mod y = x)%Z).
  rewrite Zmod_small; auto with zarith.
assert (h2: ((-x) mod y = y - x)%Z).
  rewrite Z_mod_nz_opp_full.
  rewrite h1; auto.
rewrite h1; auto with zarith.
unfold div.
case Z_le_dec; auto with zarith.
intros h3.
rewrite Z_div_nz_opp_full; auto with zarith.
rewrite Zdiv_small; auto with zarith.

(* case x = y *)
subst.
assert (h1: (y mod y = 0)%Z).
  rewrite Z_mod_same_full; auto with zarith.
assert (h2: ((-y) mod y = 0)%Z).
  rewrite Z_mod_zero_opp_full; auto with zarith.
unfold div.
case Z_le_dec; rewrite h2; auto with zarith.
intro.
rewrite Z_div_zero_opp_full; auto with zarith.
rewrite Z_div_same_full; auto with zarith.
Qed.

(* Why3 goal *)
Lemma Mod_0 :
  forall (y:Numbers.BinNums.Z), ~ (y = 0%Z) -> ((mod1 0%Z y) = 0%Z).
Proof.
intros y Hy.
unfold mod1, div.
rewrite Zmod_0_l.
simpl.
now rewrite Zdiv_0_l, Zmult_0_r.
Qed.

(* Why3 goal *)
Lemma Div_1_left :
  forall (y:Numbers.BinNums.Z), (1%Z < y)%Z -> ((div 1%Z y) = 0%Z).
Proof.
intros y Hy.
rewrite Div_inf; auto with zarith.
Qed.

(* Why3 goal *)
Lemma Div_minus1_left :
  forall (y:Numbers.BinNums.Z), (1%Z < y)%Z -> ((div (-1%Z)%Z y) = (-1%Z)%Z).
Proof.
intros y Hy.
unfold div.
assert (h1: (1 mod y = 1)%Z).
apply Zmod_1_l; auto.
assert (h2: ((-(1)) mod y = y-1)%Z).
  rewrite Z_mod_nz_opp_full; auto with zarith.
case Z_le_dec; auto with zarith.
intro.
rewrite Z_div_nz_opp_full; auto with zarith.
rewrite Zdiv_small; auto with zarith.
Qed.

(* Why3 goal *)
Lemma Mod_1_left :
  forall (y:Numbers.BinNums.Z), (1%Z < y)%Z -> ((mod1 1%Z y) = 1%Z).
Proof.
intros y Hy.
unfold mod1.
rewrite Div_1_left; auto with zarith.
Qed.

(* Why3 goal *)
Lemma Mod_minus1_left :
  forall (y:Numbers.BinNums.Z), (1%Z < y)%Z ->
  ((mod1 (-1%Z)%Z y) = (y - 1%Z)%Z).
Proof.
intros y Hy.
unfold mod1.
rewrite Div_minus1_left; auto with zarith.
Qed.

Open Scope Z_scope.

(* Why3 goal *)
Lemma Div_mult :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z) (z:Numbers.BinNums.Z),
  (0%Z < x)%Z -> ((div ((x * y)%Z + z)%Z x) = (y + (div z x))%Z).
Proof.
intros x y z h.
unfold div.
destruct (Z_le_dec 0 (z mod x)).
destruct (Z_le_dec 0 ((x*y+z) mod x)).
rewrite Zmult_comm.
rewrite Z_div_plus_full_l; auto with zarith.
generalize (Z_mod_lt (x * y + z) x); auto with zarith.
generalize (Z_mod_lt z x); auto with zarith.
Qed.

(* Why3 goal *)
Lemma Mod_mult :
  forall (x:Numbers.BinNums.Z) (y:Numbers.BinNums.Z) (z:Numbers.BinNums.Z),
  (0%Z < x)%Z -> ((mod1 ((x * y)%Z + z)%Z x) = (mod1 z x)).
Proof.
intros x y z h.
unfold mod1.
rewrite Div_mult.
ring.
auto with zarith.
Qed.

