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

import Cedar.Partial.Evaluator
import Cedar.Spec.Evaluator
import Cedar.Tactic.Csimp
import Cedar.Thm.Data.Control
import Cedar.Thm.Partial.Evaluation.Basic

namespace Cedar.Thm.Partial.Evaluation.Or

open Cedar.Spec (Result)

/--
  Inductive argument that partial evaluating a concrete `Partial.Expr.or`
  expression gives the same output as concrete-evaluating the `Spec.Expr.or`
  with the same subexpressions
-/
theorem on_concrete_eqv_concrete_eval {x₁ x₂ : Spec.Expr} {request : Spec.Request} {entities : Spec.Entities} :
  PartialEvalEquivConcreteEval x₁ request entities →
  PartialEvalEquivConcreteEval x₂ request entities →
  PartialEvalEquivConcreteEval (Spec.Expr.or x₁ x₂) request entities
:= by
  unfold PartialEvalEquivConcreteEval
  intro ih₁ ih₂
  unfold Partial.evaluate Spec.evaluate Spec.Expr.asPartialExpr
  simp only [ih₁, ih₂]
  unfold Except.map
  cases Spec.evaluate x₁ request entities <;> csimp
  case ok v₁ =>
    cases v₁ <;> try csimp
    case prim p =>
      cases p <;> csimp
      case bool b =>
        cases b <;> csimp
        case false =>
          split <;> csimp
          case h_1 e h₂ => simp [h₂]
          case h_2 v h₂ =>
            rw [h₂]
            cases v <;> try csimp
            case prim p => cases p <;> csimp

end Cedar.Thm.Partial.Evaluation.Or
