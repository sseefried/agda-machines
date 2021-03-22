-- Another attempt as netlists, this time with better static typing.

module NetlistB where

import Misc as F
open import Ty
open import Symbolic.ExtrinsicTy

private variable A B C D : Ty

mutual

  infix 0 _⇨_
  record _⇨_ (A B : Ty) : Set where
    inductive
    constructor netFun
    field
      { netlist } : Netlist A
      source : Source netlist B

  -- Netlist with input type
  data Netlist (A : Ty) : Set where
    input : Netlist A
    snoc  : A ⇨ B → B p.⇨ C → Netlist A

  private variable nets : Netlist A

  infix 4 _∈⇨_
  _∈⇨_ : Ty → A ⇨ B → Set
  C ∈⇨ netFun { nets } _ = C ∈ nets

  -- Type as output of a netlist component
  infix 4 _∈_
  data _∈_ (C : Ty) : Netlist A → Set where
    input∈ : C ∈ input {C}
    here   : ∀ (f : A ⇨ B) (p : B p.⇨ C)          → C ∈ snoc f p
    there  : ∀ {f : A ⇨ B} {p : B p.⇨ D} → C ∈⇨ f → C ∈ snoc f p

  -- Data source
  infixr 8 _∙_
  data Source : Netlist A → Ty → Set where
    tt  : Source nets ⊤
    _∙_ : Source nets B → Source nets C → Source nets (B × C)
    bit : B ∈ nets → BitIx B → Source nets Bool

mutual

  ⟦_∈⟧ : {nets : Netlist A} → B ∈ nets → A →ᵗ B
  ⟦ input∈   ∈⟧ = F.id
  ⟦ here f p ∈⟧ = p.⟦ p ⟧ F.∘ ⟦ f ⟧
  ⟦ there i  ∈⟧ = ⟦ i ∈⟧

  ⟦_⟧ : A ⇨ B → A →ᵗ B
  ⟦ netFun tt ⟧ = F.!
  ⟦ netFun (s₁ ∙ s₂) ⟧ = ⟦ netFun s₁ ⟧ F.△ ⟦ netFun s₂ ⟧
  ⟦ netFun (bit B∈f i) ⟧ = ⟦ i ⟧ᵇ F.∘ ⟦ B∈f ∈⟧

  -- Use of F.△ here loses all sharing and so will be inefficient.
  -- Do we care? I think we can improve.


-- TODO: Maybe add some optimizations like constant folding and hash consing
-- (common subexpression elimination).
