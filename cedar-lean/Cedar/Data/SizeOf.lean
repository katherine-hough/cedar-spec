/-
 Copyright Cedar Contributors

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-/

import Cedar.Data.Map
import Cedar.Data.Set

/-!
  Lemmas involving `sizeOf`, which are located here rather than in `Cedar/Thm`
  because they are needed for some definitions in `Cedar/Spec` and/or
  `Cedar/Partial`, and our convention prevents files in `Cedar/Spec` or
  `Cedar/Partial` from depending on lemmas in `Cedar/Thm`.
-/
namespace Cedar.Data.List
theorem in_lists_means_smaller [SizeOf α] (x : α) (list : List α)
  (h : x ∈ list) :
  sizeOf x < sizeOf list
  := by
  cases list
  case nil =>
    cases h
  case cons head tail =>
    cases h
    case _ =>
      simp
      omega
    case _ in_tail =>
      have step : sizeOf x < sizeOf tail := by
        apply in_lists_means_smaller
        assumption
      simp
      omega
end Cedar.Data.List

namespace Cedar.Data.Map

/-! ## Map -/

theorem sizeOf_lt_of_value [SizeOf α] [SizeOf β] {m : Map α β} {k : α} {v : β}
  (h : (k, v) ∈ m.1) :
  sizeOf v < sizeOf m
:= by
  simp only [Membership.mem] at h
  replace h := List.sizeOf_lt_of_mem h
  have v_lt_kv : sizeOf v < sizeOf (k, v) := by
    simp only [sizeOf, Prod._sizeOf_1]
    omega
  have m1_lt_m : sizeOf m.1 < sizeOf m := by
    simp only [sizeOf, Map._sizeOf_1]
    omega
  let a := sizeOf v
  let c := sizeOf m.1
  let d := sizeOf m
  have v_lt_m1 : a < c := by apply Nat.lt_trans v_lt_kv h
  have v_lt_m : a < d := by apply Nat.lt_trans v_lt_m1 m1_lt_m
  have ha : a = sizeOf v := by simp
  have hd : d = sizeOf m := by simp
  rw [ha, hd] at v_lt_m
  exact v_lt_m

theorem sizeOf_lt_of_kvs [SizeOf α] [SizeOf β] (m : Map α β) :
  sizeOf m.kvs < sizeOf m
:= by
  unfold kvs
  conv => rhs ; unfold sizeOf _sizeOf_inst _sizeOf_1 ; simp only
  generalize sizeOf m.1 = s
  omega


theorem sizeOf_lt_of_in_values [SizeOf α] [SizeOf β] {m : Map α β} {v : β}
  (h : v ∈ m.values) :
  sizeOf v < sizeOf m
  := by
  simp [Map.values] at h
  replace ⟨kv, h⟩ := h
  have step₁ : sizeOf m.kvs < sizeOf m := by
    apply sizeOf_lt_of_kvs
  have step₂ : sizeOf kv < sizeOf m.kvs := by
    apply List.in_lists_means_smaller
    simp [h]
  have step₃ : sizeOf v < sizeOf kv := by
    have ⟨k,v'⟩ := kv
    simp at h
    simp [h]
    omega
  omega


theorem sizeOf_lt_of_tl [SizeOf α] [SizeOf β] {m : Map α β} {tl : List (α × β)}
  (h : m.kvs = (k, v) :: tl) :
  1 + sizeOf tl < sizeOf m
:= by
  conv => rhs ; unfold sizeOf _sizeOf_inst _sizeOf_1
  simp only
  unfold kvs at h
  simp only [h, List.cons.sizeOf_spec, Prod.mk.sizeOf_spec]
  generalize sizeOf k = kn
  generalize sizeOf v = vn
  generalize sizeOf tl = tn
  omega

end Cedar.Data.Map

namespace Cedar.Data.Set

/-! ## Set -/

theorem sizeOf_lt_of_mem [SizeOf α] {s : Set α}
  (h : a ∈ s) :
  sizeOf a < sizeOf s
:= by
  simp only [Membership.mem, elts] at h
  replace h := List.sizeOf_lt_of_mem h
  have _ : sizeOf s.1 < sizeOf s := by
    simp only [sizeOf, _sizeOf_1]
    omega
  omega

theorem sizeOf_lt_of_elts [SizeOf α] {s : Set α} :
  sizeOf s.elts < sizeOf s
:= by
  simp only [elts]
  conv => rhs ; unfold sizeOf _sizeOf_inst _sizeOf_1 ; simp
  omega

end Cedar.Data.Set
