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

import Cedar.Data.SizeOf
import Cedar.Partial.Evaluator
import Cedar.Partial.Expr
import Cedar.Spec.Evaluator
import Cedar.Thm.Ext
import Cedar.Thm.Partial.Evaluation.And
import Cedar.Thm.Partial.Evaluation.AndOr
import Cedar.Thm.Partial.Evaluation.Binary
import Cedar.Thm.Partial.Evaluation.Call
import Cedar.Thm.Partial.Evaluation.GetAttr
import Cedar.Thm.Partial.Evaluation.HasAttr
import Cedar.Thm.Partial.Evaluation.Ite
import Cedar.Thm.Partial.Evaluation.Or
import Cedar.Thm.Partial.Evaluation.Props
import Cedar.Thm.Partial.Evaluation.Record
import Cedar.Thm.Partial.Evaluation.Set
import Cedar.Thm.Partial.Evaluation.Unary
import Cedar.Thm.Partial.Evaluation.Var
import Cedar.Thm.Partial.Evaluation.WellFormed
import Cedar.Thm.Data.Control

/-! This file contains theorems about Cedar's partial evaluator. -/

namespace Cedar.Thm.Partial.Evaluation

open Cedar.Data
open Cedar.Partial (Unknown)
open Cedar.Spec (Error Prim Result)

/--
  Partial evaluation with concrete inputs gives the same output as
  concrete evaluation with those inputs
-/
theorem on_concrete_eqv_concrete_eval' (expr : Spec.Expr) (request : Spec.Request) (entities : Spec.Entities)
  (wf : request.context.WellFormed) :
  PartialEvalEquivConcreteEval expr request entities
:= by
  unfold PartialEvalEquivConcreteEval
  cases expr
  case lit p => simp [Partial.evaluate, Spec.evaluate, Spec.Expr.asPartialExpr, Except.map]
  case var v =>
    have h := Var.on_concrete_eqv_concrete_eval v request entities wf
    unfold PartialEvalEquivConcreteEval at h ; exact h
  case and x₁ x₂ | or x₁ x₂ =>
    have ih₁ := on_concrete_eqv_concrete_eval' x₁ request entities wf
    have ih₂ := on_concrete_eqv_concrete_eval' x₂ request entities wf
    have := AndOr.on_concrete_eqv_concrete_eval ih₁ ih₂
    first | exact this.left | exact this.right
  case ite x₁ x₂ x₃ =>
    have ih₁ := on_concrete_eqv_concrete_eval' x₁ request entities wf
    have ih₂ := on_concrete_eqv_concrete_eval' x₂ request entities wf
    have ih₃ := on_concrete_eqv_concrete_eval' x₃ request entities wf
    exact Ite.on_concrete_eqv_concrete_eval ih₁ ih₂ ih₃
  case unaryApp op x₁ =>
    have ih₁ := on_concrete_eqv_concrete_eval' x₁ request entities wf
    exact Unary.on_concrete_eqv_concrete_eval ih₁
  case binaryApp op x₁ x₂ =>
    have ih₁ := on_concrete_eqv_concrete_eval' x₁ request entities wf
    have ih₂ := on_concrete_eqv_concrete_eval' x₂ request entities wf
    exact Binary.on_concrete_eqv_concrete_eval ih₁ ih₂
  case getAttr x₁ attr =>
    have ih₁ := on_concrete_eqv_concrete_eval' x₁ request entities wf
    exact GetAttr.on_concrete_eqv_concrete_eval ih₁
  case hasAttr x₁ attr =>
    have ih₁ := on_concrete_eqv_concrete_eval' x₁ request entities wf
    exact HasAttr.on_concrete_eqv_concrete_eval ih₁
  case set xs =>
    have ih : ∀ x ∈ xs, PartialEvalEquivConcreteEval x request entities := by
      intro x h₁
      have := List.sizeOf_lt_of_mem h₁
      apply on_concrete_eqv_concrete_eval' x request entities wf
    exact Set.on_concrete_eqv_concrete_eval ih
  case record attrs =>
    have ih : ∀ kv ∈ attrs, PartialEvalEquivConcreteEval kv.snd request entities := by
      intro kv h₁
      have := List.sizeOf_lt_of_mem h₁
      apply on_concrete_eqv_concrete_eval' kv.snd request entities wf
    exact Record.on_concrete_eqv_concrete_eval ih
  case call xfn args =>
    have ih : ∀ arg ∈ args, PartialEvalEquivConcreteEval arg request entities := by
      intro arg h₁
      have := List.sizeOf_lt_of_mem h₁
      apply on_concrete_eqv_concrete_eval' arg request entities wf
    exact Call.on_concrete_eqv_concrete_eval ih
termination_by expr
decreasing_by
  all_goals simp_wf
  all_goals try omega
  case _ => -- record
    have h₂ : sizeOf kv.snd < sizeOf kv := by simp only [sizeOf, Prod._sizeOf_1] ; omega
    apply Nat.lt_trans h₂
    omega

/--
  Corollary, written with `PartialEvalEquivConcreteEval` spelled out, which is
  easier for consumers
-/
theorem on_concrete_eqv_concrete_eval (expr : Spec.Expr) (request : Spec.Request) (entities : Spec.Entities)
  (wf : request.context.WellFormed) :
  Partial.evaluate expr request entities = (Spec.evaluate expr request entities).map Partial.Value.value
:= by
  have h := on_concrete_eqv_concrete_eval' expr request entities wf
  unfold PartialEvalEquivConcreteEval at h
  exact h

/--
  `Prop` that a given `Result Partial.Value` is either a concrete value or an
  error, not a residual
-/
def isValueOrError : Result Partial.Value → Prop
  | .ok (.value _) => true
  | .ok (.residual _) => false
  | .error _ => true

/--
  Corollary to the above: partial evaluation with concrete inputs gives a
  concrete value (or an error)
-/
theorem on_concrete_gives_concrete (expr : Spec.Expr) (request : Spec.Request) (entities : Spec.Entities)
  (wf : request.context.WellFormed) :
  isValueOrError (Partial.evaluate expr request entities)
:= by
  rw [on_concrete_eqv_concrete_eval expr request entities wf]
  simp only [Except.map, isValueOrError]
  split
  <;> rename_i h
  <;> split at h
  <;> simp only [Except.ok.injEq, Except.error.injEq, Partial.Value.value.injEq] at h
  <;> trivial

/--
  Partial evaluation always returns well-formed results
-/
theorem partial_eval_wf {expr : Partial.Expr} {request : Partial.Request} {entities : Partial.Entities}
  (wf_r : request.WellFormed)
  (wf_e : entities.WellFormed) :
  EvaluatesToWellFormed expr request entities
:= by
  cases expr
  case lit p =>
    unfold EvaluatesToWellFormed
    unfold Partial.evaluate
    intro pval
    intro h₁ ; simp at h₁ ; subst h₁
    simp [Partial.Value.WellFormed, Spec.Value.WellFormed, Prim.WellFormed]
  case var v => exact Var.partial_eval_wf wf_r
  case unknown u =>
    unfold EvaluatesToWellFormed
    unfold Partial.evaluate
    intro pval
    intro h₁ ; simp at h₁ ; subst h₁
    simp [Partial.Value.WellFormed]
  case and x₁ x₂ | or x₁ x₂ =>
    intro pval
    have := AndOr.partial_eval_wf x₁ x₂ request entities
    first | exact this.left pval | exact this.right pval
  case unaryApp op x₁ => exact Unary.partial_eval_wf
  case binaryApp op x₁ x₂ =>
    have ih₁ := partial_eval_wf wf_r wf_e (expr := x₁) (request := request) (entities := entities)
    have ih₂ := partial_eval_wf wf_r wf_e (expr := x₂) (request := request) (entities := entities)
    exact Binary.partial_eval_wf ih₁ ih₂
  case hasAttr x₁ attr => exact HasAttr.partial_eval_wf
  case getAttr x₁ attr =>
    have ih₁ := partial_eval_wf wf_r wf_e (expr := x₁) (request := request) (entities := entities)
    exact GetAttr.partial_eval_wf ih₁ wf_e
  case ite x₁ x₂ x₃ =>
    have ih₂ := partial_eval_wf wf_r wf_e (expr := x₂) (request := request) (entities := entities)
    have ih₃ := partial_eval_wf wf_r wf_e (expr := x₃) (request := request) (entities := entities)
    exact Ite.partial_eval_wf ih₂ ih₃
  case set xs =>
    have ih : ∀ x ∈ xs, EvaluatesToWellFormed x request entities := by
      intro x h₁
      have := List.sizeOf_lt_of_mem h₁
      apply partial_eval_wf wf_r wf_e
    exact Set.partial_eval_wf ih
  case record attrs =>
    have ih : ∀ kv ∈ attrs, EvaluatesToWellFormed kv.snd request entities := by
      intro kv h₁
      have := List.sizeOf_lt_of_mem h₁
      apply partial_eval_wf wf_r wf_e
    exact Record.partial_eval_wf ih
  case call xfn xs =>
    have ih : ∀ x ∈ xs, EvaluatesToWellFormed x request entities := by
      intro x h₁
      have := List.sizeOf_lt_of_mem h₁
      apply partial_eval_wf wf_r wf_e
    exact Call.partial_eval_wf ih
termination_by expr
decreasing_by
  all_goals simp_wf
  all_goals try omega
  case _ => -- record
    conv at this => lhs ; unfold sizeOf Prod._sizeOf_inst Prod._sizeOf_1
    simp at this
    omega

/--
  Partial evaluation of a Spec.Value always succeeds and returns the value
-/
theorem eval_spec_value (v : Spec.Value) (request : Partial.Request) (entities : Partial.Entities)
  (wf : v.WellFormed) :
  Partial.evaluate v.asPartialExpr request entities = .ok (.value v)
:= by
  cases v
  case prim p => simp [Partial.evaluate, Spec.Value.asPartialExpr]
  case set vs =>
    unfold Spec.Value.WellFormed at wf
    apply Set.eval_spec_value vs request entities wf.left wf.right
    intro v h₁
    exact eval_spec_value v request entities (wf.right v h₁)
  case record attrs =>
    unfold Spec.Value.WellFormed at wf
    apply Record.eval_spec_value attrs request entities wf.left
    intro v h₁
    replace ⟨k, h₁⟩ := Map.in_values_exists_key h₁
    exact eval_spec_value v request entities (wf.right (k, v) h₁)
  case ext x =>
    unfold Partial.evaluate Spec.Value.asPartialExpr
    cases x <;> simp
    <;> rw [List.mapM₁_eq_mapM (Partial.evaluate · request entities)]
    case decimal d =>
      simp [Partial.evaluate, Partial.evaluateCall]
      simp [Ext.decimal_toString_inverse d]
    case ipaddr ip =>
      simp [Partial.evaluate, Partial.evaluateCall]
      simp [Ext.ipaddr_toString_inverse ip]
termination_by v
decreasing_by
  all_goals simp_wf
  all_goals try omega
  case _ => -- set
    rename_i h₂ ; subst h₂
    exact Nat.lt_trans (Set.sizeOf_lt_of_mem h₁) (Set.sizeOf_lt_of_val _)
  case _ => -- record
    rename_i h₂ _ ; subst h₂
    apply Nat.lt_trans (Map.sizeOf_lt_of_value h₁)
    rw [Map.mk_kvs_id]
    apply Map.sizeOf_lt_of_val

/--
  Corollary: partial evaluation of a Prim always succeeds and returns the value
  (no WF precondition needed from caller)
-/
theorem eval_spec_prim (p : Prim) (request : Partial.Request) (entities : Partial.Entities) :
  Partial.evaluate (Spec.Value.prim p).asPartialExpr request entities = .ok (.value (.prim p))
:= by
  exact eval_spec_value (.prim p) request entities (by simp [Spec.Value.WellFormed, Prim.WellFormed])

/--
  Another way to state `eval_spec_value`
-/
theorem eval_spec_value' (v : Spec.Value) (request : Partial.Request) (entities : Partial.Entities)
  (wf : v.WellFormed) :
  Partial.evaluate (Partial.Value.value v).asPartialExpr request entities = .ok (.value v)
:= by
  apply eval_spec_value v request entities wf

/--
  Corollary: partial evaluation of a Prim always succeeds and returns the value
  (no WF precondition needed from caller)
-/
theorem eval_spec_prim' (p : Prim) (request : Partial.Request) (entities : Partial.Entities) :
  Partial.evaluate (Partial.Value.value (Spec.Value.prim p)).asPartialExpr request entities = .ok (.value (.prim p))
:= by
  exact eval_spec_value' (.prim p) request entities (by simp [Spec.Value.WellFormed, Prim.WellFormed])

/--
  If partial evaluation returns a concrete value, then it returns the same value
  after any substitution of unknowns
-/
theorem subst_preserves_evaluation_to_value {expr : Partial.Expr} {req req' : Partial.Request} {entities : Partial.Entities} {v : Spec.Value} {subsmap : Map Unknown Partial.Value}
  (wf_r : req.WellFormed)
  (wf_e : entities.WellFormed) :
  req.subst subsmap = some req' →
  Partial.evaluate expr req entities = .ok (.value v) →
  Partial.evaluate (expr.subst subsmap) req' (entities.subst subsmap) = .ok (.value v)
:= by
  cases expr
  case lit p =>
    unfold Partial.evaluate
    simp only [Except.ok.injEq, Partial.Value.value.injEq, Bool.not_eq_true']
    intro _ h₁ ; subst h₁
    simp only [Partial.Expr.subst]
  case var var =>
    have h₁ := Var.subst_preserves_evaluation_to_value var req req' entities subsmap wf_r
    unfold SubstPreservesEvaluationToConcrete at h₁
    intro h_req
    exact h₁ h_req v
  case unknown u =>
    unfold Partial.evaluate
    simp only [Except.ok.injEq, Bool.not_eq_true', false_implies, implies_true]
  case and x₁ x₂ =>
    intro h_req h₁
    have h₂ := And.evals_to_concrete_then_operands_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    rcases h₂ with h₂ | ⟨⟨v₁, hx₁⟩, ⟨v₂, hx₂⟩⟩
    · have ih := subst_preserves_evaluation_to_value wf_r wf_e h_req h₂
      unfold Partial.Expr.subst Partial.evaluate Spec.Value.asBool
      unfold Partial.evaluate Spec.Value.asBool at h₁
      simp only [Bool.not_eq_true', Except.bind_ok, reduceIte, Except.ok.injEq,
        Partial.Value.value.injEq] at *
      simp only [ih]
      simp only [h₂] at h₁
      exact h₁
    · have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
      have ih₂ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₂
      apply (AndOr.subst_preserves_evaluation_to_value _ _).left h_req v h₁
      · unfold SubstPreservesEvaluationToConcrete
        intro _ v₁' hx₁'
        simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
        subst v₁'
        exact ih₁
      · unfold SubstPreservesEvaluationToConcrete
        intro _ v₂' hx₂'
        simp only [hx₂', Except.ok.injEq, Partial.Value.value.injEq] at hx₂
        subst v₂'
        exact ih₂
  case or x₁ x₂ =>
    intro h_req h₁
    have h₂ := Or.evals_to_concrete_then_operands_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    rcases h₂ with h₂ | ⟨⟨v₁, hx₁⟩, ⟨v₂, hx₂⟩⟩
    · have ih := subst_preserves_evaluation_to_value wf_r wf_e h_req h₂
      unfold Partial.Expr.subst Partial.evaluate Spec.Value.asBool
      unfold Partial.evaluate Spec.Value.asBool at h₁
      simp only [Bool.not_eq_true', Except.bind_ok, reduceIte, Except.ok.injEq,
        Partial.Value.value.injEq] at *
      simp only [ih]
      simp only [h₂] at h₁
      exact h₁
    · have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
      have ih₂ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₂
      apply (AndOr.subst_preserves_evaluation_to_value _ _).right h_req v h₁
      · unfold SubstPreservesEvaluationToConcrete
        intro _ v₁' hx₁'
        simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
        subst v₁'
        exact ih₁
      · unfold SubstPreservesEvaluationToConcrete
        intro _ v₂' hx₂'
        simp only [hx₂', Except.ok.injEq, Partial.Value.value.injEq] at hx₂
        subst v₂'
        exact ih₂
  case binaryApp op x₁ x₂ =>
    intro h_req h₁
    have h₂ := Binary.evals_to_concrete_then_operands_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    have ⟨⟨v₁, hx₁⟩, ⟨v₂, hx₂⟩⟩ := h₂ ; clear h₂
    have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
    have ih₂ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₂
    apply Binary.subst_preserves_evaluation_to_value _ _ h_req v h₁
    · unfold SubstPreservesEvaluationToConcrete
      intro _ v₁' hx₁'
      simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
      subst v₁'
      exact ih₁
    · unfold SubstPreservesEvaluationToConcrete
      intro _ v₂' hx₂'
      simp only [hx₂', Except.ok.injEq, Partial.Value.value.injEq] at hx₂
      subst v₂'
      exact ih₂
  case unaryApp op x₁ =>
    intro h_req h₁
    have h₂ := Unary.evals_to_concrete_then_operand_evals_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    have ⟨v₁, hx₁⟩ := h₂ ; clear h₂
    have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
    apply Unary.subst_preserves_evaluation_to_value _ h_req v h₁
    · unfold SubstPreservesEvaluationToConcrete
      intro _ v₁' hx₁'
      simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
      subst v₁'
      exact ih₁
  case ite x₁ x₂ x₃ =>
    intro h_req h₁
    have h₂ := Ite.evals_to_concrete_then_operands_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    rcases h₂ with ⟨hx₁, ⟨v₂, hx₂⟩⟩ | ⟨hx₁, ⟨v₃, hx₃⟩⟩
    · have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
      have ih₂ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₂
      apply Ite.subst_preserves_evaluation_to_value _ _ h_req v h₁
      · unfold SubstPreservesEvaluationToConcrete
        intro _ v₁' hx₁'
        simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
        subst v₁'
        exact ih₁
      · unfold SubstPreservesEvaluationToConcrete
        left
        apply And.intro hx₁
        intro _ v₂' hx₂'
        simp only [hx₂', Except.ok.injEq, Partial.Value.value.injEq] at hx₂
        subst v₂'
        exact ih₂
    · have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
      have ih₃ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₃
      apply Ite.subst_preserves_evaluation_to_value _ _ h_req v h₁
      · unfold SubstPreservesEvaluationToConcrete
        intro _ v₁' hx₁'
        simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
        subst v₁'
        exact ih₁
      · unfold SubstPreservesEvaluationToConcrete
        right
        apply And.intro hx₁
        intro _ v₃' hx₃'
        simp only [hx₃', Except.ok.injEq, Partial.Value.value.injEq] at hx₃
        subst v₃'
        exact ih₃
  case getAttr x₁ attr =>
    intro h_req h₁
    have h₂ := GetAttr.evals_to_concrete_then_operand_evals_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    have ⟨v₁, hx₁⟩ := h₂ ; clear h₂
    have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
    apply GetAttr.subst_preserves_evaluation_to_value wf_e _ h_req v h₁
    · unfold SubstPreservesEvaluationToConcrete
      intro _ v₁' hx₁'
      simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
      subst v₁'
      exact ih₁
  case hasAttr x₁ attr =>
    intro h_req h₁
    have h₂ := HasAttr.evals_to_concrete_then_operand_evals_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at h₂
    have ⟨v₁, hx₁⟩ := h₂ ; clear h₂
    have ih₁ := subst_preserves_evaluation_to_value wf_r wf_e h_req hx₁
    apply HasAttr.subst_preserves_evaluation_to_value wf_e _ h_req v h₁
    · unfold SubstPreservesEvaluationToConcrete
      intro _ v₁' hx₁'
      simp only [hx₁', Except.ok.injEq, Partial.Value.value.injEq] at hx₁
      subst v₁'
      exact ih₁
  case set xs =>
    intro h_req h₁
    have hx := Set.evals_to_concrete_then_elts_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at hx
    have ih : ∀ x ∈ xs, SubstPreservesEvaluationToConcrete x req req' entities subsmap := by
      unfold SubstPreservesEvaluationToConcrete
      intro x h₂ _ v' hx'
      replace ⟨v, hx⟩ := hx x h₂
      simp only [hx, Except.ok.injEq, Partial.Value.value.injEq] at hx'
      subst v'
      have := List.sizeOf_lt_of_mem h₂
      exact subst_preserves_evaluation_to_value wf_r wf_e h_req hx
    exact Set.subst_preserves_evaluation_to_value ih h_req v h₁
  case record attrs =>
    intro h_req h₁
    have hx := Record.evals_to_concrete_then_vals_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at hx
    have ih: ∀ kv ∈ attrs, SubstPreservesEvaluationToConcrete kv.snd req req' entities subsmap := by
      unfold SubstPreservesEvaluationToConcrete
      intro (k, x) h₂ _ v' hx'
      replace ⟨v, hx⟩ := hx (k, x) h₂
      simp only [hx, Except.ok.injEq, Partial.Value.value.injEq] at hx'
      subst v'
      have := Map.sizeOf_lt_of_value h₂
      exact subst_preserves_evaluation_to_value wf_r wf_e h_req hx
    exact Record.subst_preserves_evaluation_to_value ih h_req v h₁
  case call xfn xs =>
    intro h_req h₁
    have hx := Call.evals_to_concrete_then_args_eval_to_concrete (by
      unfold EvaluatesToConcrete
      exists v
    )
    unfold EvaluatesToConcrete at hx
    have ih : ∀ x ∈ xs, SubstPreservesEvaluationToConcrete x req req' entities subsmap := by
      unfold SubstPreservesEvaluationToConcrete
      intro x h₂ _ v' hx'
      replace ⟨v, hx⟩ := hx x h₂
      simp only [hx, Except.ok.injEq, Partial.Value.value.injEq] at hx'
      subst v'
      have := List.sizeOf_lt_of_mem h₂
      exact subst_preserves_evaluation_to_value wf_r wf_e h_req hx
    exact Call.subst_preserves_evaluation_to_value ih h_req v h₁
termination_by expr
