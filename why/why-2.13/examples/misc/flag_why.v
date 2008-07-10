(* This file was originally generated by why.
   It can be modified; only the generated parts will be overwritten. *)

Require Import Why.
Require Import Sumbool.


(*Why logic*) Definition N : Z.
Admitted.

Axiom N_non_negative : (0 <= N)%Z.

Inductive color : Set :=
  | blue : color
  | white : color
  | red : color.

Lemma eq_color_dec : forall c1 c2:color, {c1 = c2} + {c1 <> c2}.
 Proof.
 intros; decide equality c1 c2.
Qed.

Definition eq_blue c := bool_of_sumbool (eq_color_dec c blue).
Definition eq_white c := bool_of_sumbool (eq_color_dec c white).

Definition monochrome (t:array color) (i j:Z) (c:color) : Prop :=
  forall k:Z, (i <= k < j)%Z -> access t k = c.


(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_1 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\ (monochrome t 0 0 blue) /\
  (monochrome t 0 0 white) /\ (monochrome t N N red) /\ (array_length t) = N.
Proof.
unfold monochrome; intuition; try (elimtype False; omega).
exact N_non_negative.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_2 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  0 <= i /\ i < (array_length t0).
Proof.
intuition.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_3 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_7: result = blue),
  0 <= b /\ b < (array_length t0).
Proof.
intuition.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_4 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_7: result = blue),
  forall (HW_8: 0 <= b /\ b < (array_length t0)),
  forall (result0: color),
  forall (HW_9: result0 = (access t0 b)),
  forall (HW_10: 0 <= i /\ i < (array_length t0)),
  forall (result1: color),
  forall (HW_11: result1 = (access t0 i)),
  forall (HW_12: 0 <= b /\ b < (array_length t0)),
  forall (t1: (array color)),
  forall (HW_13: t1 = (update t0 b result1)),
  0 <= i /\ i < (array_length t1).
Proof.
intuition.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_5 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_7: result = blue),
  forall (HW_8: 0 <= b /\ b < (array_length t0)),
  forall (result0: color),
  forall (HW_9: result0 = (access t0 b)),
  forall (HW_10: 0 <= i /\ i < (array_length t0)),
  forall (result1: color),
  forall (HW_11: result1 = (access t0 i)),
  forall (HW_12: 0 <= b /\ b < (array_length t0)),
  forall (t1: (array color)),
  forall (HW_13: t1 = (update t0 b result1)),
  forall (HW_14: 0 <= i /\ i < (array_length t1)),
  forall (t2: (array color)),
  forall (HW_15: t2 = (update t1 i result0)),
  forall (b0: Z),
  forall (HW_16: b0 = (b + 1)),
  forall (i0: Z),
  forall (HW_17: i0 = (i + 1)),
  ((0 <= b0 /\ b0 <= i0) /\ (i0 <= r /\ r <= N) /\
  (monochrome t2 0 b0 blue) /\ (monochrome t2 b0 i0 white) /\
  (monochrome t2 r N red) /\ (array_length t2) = N) /\
  (Zwf 0 (r - i0) (r - i)).
Proof.
intuition; subst; auto.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_6 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_18: ~(result = blue)),
  forall (HW_19: 0 <= i /\ i < (array_length t0)),
  forall (result0: color),
  forall (HW_20: result0 = (access t0 i)),
  forall (HW_21: result0 = white),
  forall (i0: Z),
  forall (HW_22: i0 = (i + 1)),
  ((0 <= b /\ b <= i0) /\ (i0 <= r /\ r <= N) /\ (monochrome t0 0 b blue) /\
  (monochrome t0 b i0 white) /\ (monochrome t0 r N red) /\
  (array_length t0) = N) /\ (Zwf 0 (r - i0) (r - i)).
Proof.
intuition.
ArraySubst t1.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_7 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_18: ~(result = blue)),
  forall (HW_19: 0 <= i /\ i < (array_length t0)),
  forall (result0: color),
  forall (HW_20: result0 = (access t0 i)),
  forall (HW_23: ~(result0 = white)),
  forall (r0: Z),
  forall (HW_24: r0 = (r - 1)),
  0 <= r0 /\ r0 < (array_length t0).
Proof.
unfold monochrome, Zwf; intuition try omega.
assert (h: (k < b)%Z \/ k = b).
 omega.
 intuition.
subst t2; AccessOther.
subst t1; AccessOther.
auto.
subst.
assert (h: b = i \/ (b < i)).
 omega.
 intuition.
subst.
AccessSame.
assumption.
AccessOther.
assumption.
assert (h: k = i \/ (k < i)).
 omega.
 intuition.
subst; AccessSame.
auto with *.
subst t2; AccessOther.
subst; AccessOther.
auto with *.
subst t2; AccessOther.
subst; AccessOther.
auto with *.
ArraySubst t1.
subst t2 t1; simpl; auto.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_8 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_18: ~(result = blue)),
  forall (HW_19: 0 <= i /\ i < (array_length t0)),
  forall (result0: color),
  forall (HW_20: result0 = (access t0 i)),
  forall (HW_23: ~(result0 = white)),
  forall (r0: Z),
  forall (HW_24: r0 = (r - 1)),
  forall (HW_25: 0 <= r0 /\ r0 < (array_length t0)),
  forall (result1: color),
  forall (HW_26: result1 = (access t0 r0)),
  forall (HW_27: 0 <= i /\ i < (array_length t0)),
  forall (result2: color),
  forall (HW_28: result2 = (access t0 i)),
  forall (HW_29: 0 <= r0 /\ r0 < (array_length t0)),
  forall (t1: (array color)),
  forall (HW_30: t1 = (update t0 r0 result2)),
  0 <= i /\ i < (array_length t1).
Proof.
intuition.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_9 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_4: i < r),
  forall (HW_5: 0 <= i /\ i < (array_length t0)),
  forall (result: color),
  forall (HW_6: result = (access t0 i)),
  forall (HW_18: ~(result = blue)),
  forall (HW_19: 0 <= i /\ i < (array_length t0)),
  forall (result0: color),
  forall (HW_20: result0 = (access t0 i)),
  forall (HW_23: ~(result0 = white)),
  forall (r0: Z),
  forall (HW_24: r0 = (r - 1)),
  forall (HW_25: 0 <= r0 /\ r0 < (array_length t0)),
  forall (result1: color),
  forall (HW_26: result1 = (access t0 r0)),
  forall (HW_27: 0 <= i /\ i < (array_length t0)),
  forall (result2: color),
  forall (HW_28: result2 = (access t0 i)),
  forall (HW_29: 0 <= r0 /\ r0 < (array_length t0)),
  forall (t1: (array color)),
  forall (HW_30: t1 = (update t0 r0 result2)),
  forall (HW_31: 0 <= i /\ i < (array_length t1)),
  forall (t2: (array color)),
  forall (HW_32: t2 = (update t1 i result1)),
  ((0 <= b /\ b <= i) /\ (i <= r0 /\ r0 <= N) /\ (monochrome t2 0 b blue) /\
  (monochrome t2 b i white) /\ (monochrome t2 r0 N red) /\
  (array_length t2) = N) /\ (Zwf 0 (r0 - i) (r - i)).
Proof.
unfold monochrome, Zwf; intuition try omega.
assert (h: (k < i)%Z \/ k = i).
 omega.
 intuition.
subst; assumption.
Qed.

(* Why obligation from file "", line 0, characters 0-0: *)
(*Why goal*) Lemma dutch_flag_po_10 : 
  forall (t: (array color)),
  forall (HW_1: (array_length t) = N),
  forall (HW_2: (0 <= 0 /\ 0 <= 0) /\ (0 <= N /\ N <= N) /\
                (monochrome t 0 0 blue) /\ (monochrome t 0 0 white) /\
                (monochrome t N N red) /\ (array_length t) = N),
  forall (b: Z),
  forall (i: Z),
  forall (r: Z),
  forall (t0: (array color)),
  forall (HW_3: (0 <= b /\ b <= i) /\ (i <= r /\ r <= N) /\
                (monochrome t0 0 b blue) /\ (monochrome t0 b i white) /\
                (monochrome t0 r N red) /\ (array_length t0) = N),
  forall (HW_33: i >= r),
  (monochrome t0 0 b blue) /\ (monochrome t0 b r white) /\
  (monochrome t0 r N red).
Proof.
intuition.
Qed.


Proof.
intuition.
Save.

Proof.
intuition.
Save.

Proof.
intuition.
ArraySubst t1.
Save.

Proof.
unfold monochrome, Zwf; intuition try omega.
subst t2 t1; do 2 AccessOther.
auto with *.
subst t2 t1; do 2 AccessOther.
 auto with *.
assert (h: k = r0 \/ (r0 < k)).
 omega.
 intuition.
assert (h': k = i \/ (i < k)).
 omega.
 intuition.
subst; subst i; AccessSame.
destruct (access t0 (r-1)); tauto.
subst; AccessOther.
destruct (access t0 i); tauto.
subst; do 2 AccessOther.
auto with *.
subst t2 t1; simpl; trivial.
Save.

Proof.
intuition.
replace r with i.
 trivial.
 omega.
Save.

(*Why*) Parameter dutch_flag_valid :
  forall (_: unit), forall (t: (array color)), forall (_: (array_length t) =
  N),
  (sig_2 (array color) unit
   (fun (t0: (array color)) (result: unit)  => (True))).
