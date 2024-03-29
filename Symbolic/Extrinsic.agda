-- Symbolic representation or Mealy machines, suitable for analysis and code
-- generation (e.g., Verilog).

module Symbolic.Extrinsic where

open import Data.Product using (_,_)
open import Data.Unit using (tt)
open import Data.Bool using (false;true)
open import Data.String using (String)
open import Relation.Binary.PropositionalEquality using (_≗_; refl)
open import Function using (_on_) renaming (const to const′)

open import Ty

import Category as C
open C

private
  variable
    A B C D σ τ : Ty

showBit : Bool → String
showBit false = "0"
showBit true  = "1"

-- Generalized routing. Maybe move to Ty.
module r where

  infix 1 _⇨_
  record _⇨_ (A B : Ty) : Set where
    constructor mk
    field
      f : TyIx B → TyIx A

  ⟦_⟧′ : A ⇨ B → ∀ {X} → TyF X A → TyF X B
  ⟦ mk f ⟧′ = swizzle′ f

  instance

    meaningful : ∀ {a b} → Meaningful {μ = a ty.⇨ b} (a ⇨ b)
    meaningful {a}{b} = record { ⟦_⟧ = λ (mk r) → ty.mk (swizzle r) }

    category : Category _⇨_
    category = record
      { id = mk id
      ; _∘_ = λ (mk f) (mk g) → mk (g ∘ f)
      }

    monoidal : Monoidal _⇨_
    monoidal = record
      { _⊗_ = λ (mk f) (mk g) → mk λ { (left x) → left (f x) ; (right x) → right (g x) }
      ; unitorᵉˡ = mk right
      ; unitorᵉʳ = mk left
      ; unitorⁱˡ = mk λ { (right x) → x }
      ; unitorⁱʳ = mk λ { (left  x) → x }
      ; assocʳ = mk λ { (left x) → left (left x)
                      ; (right (left x)) → left (right x)
                      ; (right (right x)) → right x
                      }
      ; assocˡ = mk λ { (left (left x)) → left x
                      ; (left (right x)) → right (left x)
                      ; (right x) → right (right x)
                      }
      ; ! = mk λ ()
      }

    braided : Braided _⇨_
    braided = record { swap = mk λ { (left x) → right x ; (right x) → left x } }

    cartesian : Cartesian _⇨_
    cartesian = record { exl = mk left ; exr = mk right ; dup = mk λ { (left x) → x ; (right x) → x } }

-- open r hiding (_⇨_)


-- Combinational primitives
module p where

  infix 1 _⇨_
  data _⇨_ : Ty → Ty → Set where
    `∧ `∨ `xor : Bool × Bool ⇨ Bool
    `not : Bool ⇨ Bool
    `const : ⟦ A ⟧ → ⊤ ⇨ A

  instance

    meaningful : ∀ {a b} → Meaningful {μ = a ty.⇨ b} (a ⇨ b)
    meaningful {a}{b} = record
      { ⟦_⟧ = λ { `∧         → ty.mk ∧
                ; `∨         → ty.mk ∨
                ; `xor       → ty.mk xor
                ; `not       → ty.mk not
                ; (`const a) → ty.mk (const a) } }

    p-show : ∀ {a b} → Show (a ⇨ b)
    p-show = record { show = λ { `∧ → "∧"
                               ; `∨ → "∨"
                               ; `xor → "⊕"
                               ; `not → "not"
                               ; (`const x) → showTy x
                               }
                    }

    constants : Constant _⇨_
    constants = record { const = `const }

    logic : Logic _⇨_
    logic = record { ∧ = `∧ ; ∨ = `∨ ; xor = `xor ; not = `not }

  dom : A ⇨ B → Ty
  dom {A}{B} _ = A

  cod : A ⇨ B → Ty
  cod {A}{B} _ = B


-- Combinational circuits
module c where

  infix  0 _⇨_
  infixr 7 _⊗ᶜ_
  infixr 9 _∘ᶜ_

  data _⇨_ : Ty → Ty → Set where
    route : A r.⇨ B → A ⇨ B
    prim : A p.⇨ B → A ⇨ B
    _∘ᶜ_ : B ⇨ C → A ⇨ B → A ⇨ C
    _⊗ᶜ_ : A ⇨ C → B ⇨ D → A × B ⇨ C × D

  instance

    meaningful : ∀ {a b} → Meaningful (a ⇨ b)
    meaningful {a}{b} = record { ⟦_⟧ = ⟦_⟧ᶜ }
     where
       ⟦_⟧ᶜ : A ⇨ B → A ty.⇨ B
       ⟦ route f ⟧ᶜ = ⟦ f ⟧
       ⟦ prim  p ⟧ᶜ = ⟦ p ⟧
       ⟦  g ∘ᶜ f  ⟧ᶜ = ⟦ g ⟧ᶜ ∘ ⟦ f ⟧ᶜ
       ⟦  f ⊗ᶜ g  ⟧ᶜ = ⟦ f ⟧ᶜ ⊗ ⟦ g ⟧ᶜ

    category : Category _⇨_
    category = record { id = route id ; _∘_ = _∘ᶜ_ }

    monoidal : Monoidal _⇨_
    monoidal = record
                 { _⊗_ = _⊗ᶜ_
                 ; ! = route !
                 ; unitorᵉˡ = route unitorᵉˡ
                 ; unitorᵉʳ = route unitorᵉʳ
                 ; unitorⁱˡ = route unitorⁱˡ
                 ; unitorⁱʳ = route unitorⁱʳ
                 ; assocʳ   = route assocʳ
                 ; assocˡ   = route assocˡ
                 }

    braided : Braided _⇨_
    braided = record { swap = route swap }

    cartesian : Cartesian _⇨_
    cartesian = record { exl = route exl ; exr = route exr ; dup = route dup }

    constants : Constant _⇨_
    constants = record { const = prim ∘ const }

    logic : Logic _⇨_
    logic =
      record { ∧ = prim ∧ ; ∨ = prim ∨ ; xor = prim xor ; not = prim not}

-- Synchronous state machine.
module s where

  -- For composability, the state type is invisible in the type.
  infix  0 _⇨_
  record _⇨_ (A B : Ty) : Set where
    constructor mealy
    field
      { State } : Ty
      start : ⟦ State ⟧
      transition : A × State c.⇨ B × State

  comb : A c.⇨ B → A ⇨ B
  comb f = mealy tt (first f)

  -- prim : A p.⇨ B → A ⇨ B
  -- prim p = comb (c.prim p)

  delay : ⟦ A ⟧ → A ⇨ A
  delay a₀ = mealy a₀ swap

  -- import Mealy as m

  instance

    -- meaningful : ∀ {A B} → Meaningful {μ = ⟦ A ⟧ m.⇨ ⟦ B ⟧} (A ⇨ B)
    -- meaningful {A}{B} =
    --   record { ⟦_⟧ = λ { (mealy s₀ f) → m.mealy s₀ (ty.mk⁻¹ ⟦ f ⟧) } }

    category : Category _⇨_
    category = record { id = comb id ; _∘_ = _⊙_ }
     where
       _⊙_ : B ⇨ C → A ⇨ B → A ⇨ C
       mealy t₀ g ⊙ mealy s₀ f = mealy (s₀ , t₀)
         (swiz₂ ∘ second g ∘ swiz₁ ∘ first f ∘ assocˡ)
        where
          swiz₁ : (B × σ) × τ c.⇨ σ × (B × τ)
          swiz₁ = exr ∘ exl △ first exl
          swiz₂ : σ × (C × τ) c.⇨ C × (σ × τ)
          swiz₂ = exl ∘ exr △ second exr

    monoidal : Monoidal _⇨_
    monoidal = record
      { _⊗_ = λ { (mealy s₀ f) (mealy t₀ g) →
                mealy (s₀ , t₀) (transpose ∘ (f ⊗ g) ∘ transpose) }
      ; ! = comb !
      ; unitorᵉˡ = comb unitorᵉˡ
      ; unitorᵉʳ = comb unitorᵉʳ
      ; unitorⁱˡ = comb unitorⁱˡ
      ; unitorⁱʳ = comb unitorⁱʳ
      ; assocʳ = comb assocʳ
      ; assocˡ = comb assocˡ
      }

    braided : Braided _⇨_
    braided = record { swap = comb swap }

    cartesian : Cartesian _⇨_
    cartesian = record { exl = comb exl ; exr = comb exr ; dup = comb dup }

    constants : Constant _⇨_
    constants = record { const = comb ∘ const }

    logic : Logic _⇨_
    logic = record { ∧ = comb ∧ ; ∨ = comb ∨ ; xor = comb xor ; not = comb not }
