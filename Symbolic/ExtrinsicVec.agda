-- Symbolic representation or Mealy machines, suitable for analysis and code
-- generation (e.g., Verilog).

module Symbolic.ExtrinsicVec where

open import Data.Nat
open import Data.Fin using (Fin; raise; inject+) renaming (splitAt to splitAtᶠ)
open import Data.Vec hiding (transpose)
import Data.Bool as Bool
open Bool using (Bool; if_then_else_)
open import Data.Product using (_×_ ; _,_; uncurry) renaming (map to map×)
import Data.Sum as ⊎
open ⊎ using (_⊎_; inj₁; inj₂)
open import Data.String using (String; intersperse)
import Data.List as L

import Misc as F

private variable a b c d : ℕ

Bits : ℕ → Set
Bits = Vec Bool

bool : ∀ {ℓ}{A : Set ℓ} → A → A → Bool → A
bool e t b = if b then t else e

showBits : Bits a → String
showBits bs = intersperse "," (L.map (bool "0" "1") (toList bs))

-- Is this function defined somewhere?
mergeᶠ : Fin a ⊎ Fin b → Fin (a + b)
mergeᶠ {a}{b} = ⊎.[ inject+ b , raise a ]

split′ : ∀ {ℓ}{X : Set ℓ} → Vec X (a + b) → Vec X a × Vec X b
split′ {a = a} xs = let (u , v , _) = splitAt a xs in u , v

module v (A : Set) where

  infix 0 _⇨_
  _⇨_ : ℕ → ℕ → Set
  m ⇨ n = Vec A m → Vec A n

  id : a ⇨ a
  id = F.id

  infixr 9 _∘_
  _∘_ : b ⇨ c → a ⇨ b → a ⇨ c
  _∘_ = F._∘_

  infixr 7 _⊗_
  _⊗_ : a ⇨ c → b ⇨ d → a + b ⇨ c + d
  f ⊗ g = uncurry _++_ F.∘ map× f g F.∘ split′

  first : a ⇨ c → a + b ⇨ c + b
  first f = f ⊗ id

  second : b ⇨ d → a + b ⇨ a + d
  second g = id ⊗ g

  exl : a + b ⇨ a
  exl = F.exl F.∘ split′

  exr : a + b ⇨ b
  exr = F.exr F.∘ split′

  dup : a ⇨ a + a
  dup = uncurry _++_ F.∘ F.dup

  infixr 7 _△_
  _△_ : a ⇨ c → a ⇨ d → a ⇨ c + d
  f △ g = (f ⊗ g) ∘ dup

  swap : a + b ⇨ b + a
  swap {a} = exr △ exl {a}

  ! : a ⇨ 0
  ! = F.const []

module b where
  open v Bool public

-- -- TODO: phase out _→ᵇ_ in favor of v._⇨_
-- infix 0 _→ᵇ_
-- _→ᵇ_ : ℕ → ℕ → Set
-- _→ᵇ_ = b._⇨_
  

-- Routing.  TODO: consider generalizing from Bool.
module r where

  infix 1 _⇨_
  _⇨_ : ℕ → ℕ → Set
  a ⇨ b = Fin b → Fin a

  ⟦_⟧ : (a ⇨ b) → (a b.⇨ b)
  ⟦ f ⟧ a = tabulate (lookup a F.∘ f)

  id : a ⇨ a
  id = F.id

  infixr 9 _∘_
  _∘_ : b ⇨ c → a ⇨ b → a ⇨ c
  g ∘ f = f F.∘ g

  infixr 7 _⊗_
  _⊗_ : a ⇨ c → b ⇨ d → a + b ⇨ c + d
  _⊗_ {c = c} f g = mergeᶠ F.∘ ⊎.map f g F.∘ splitAtᶠ c

  first : a ⇨ c → a + b ⇨ c + b
  first f = f ⊗ id

  second : b ⇨ d → a + b ⇨ a + d
  second g = id ⊗ g

  exl : a + b ⇨ a
  exl {a}{b} = inject+ b

  exr : a + b ⇨ b
  exr {a}{b} = raise a

  dup : a ⇨ a + a
  dup {a} = F.jam F.∘ splitAtᶠ a

  infixr 7 _△_
  _△_ : a ⇨ c → a ⇨ d → a ⇨ c + d
  f △ g = (f ⊗ g) ∘ dup

  swap : a + b ⇨ b + a
  swap {a} = exr △ exl {a}

  ! : a ⇨ 0
  ! ()

-- Combinational primitives
module p where

  1→1 : (Bool → Bool) → 1 b.⇨ 1
  1→1 f (x ∷ []) = f x ∷ []

  2→1 : (Bool → Bool → Bool) → 2 b.⇨ 1
  2→1 _∙_ (x ∷ y ∷ []) = x ∙ y ∷ []

  infix 1 _⇨_
  data _⇨_ : ℕ → ℕ → Set where
    ∧ ∨ xor : 2 ⇨ 1
    not : 1 ⇨ 1
    const : Bits a → 0 ⇨ a
    -- The next two are introduced by graph generation
    input  : 0 ⇨ a
    output : b ⇨ 0

  ⟦_⟧ : a ⇨ b → a b.⇨ b
  ⟦ ∧ ⟧       = 2→1 Bool._∧_
  ⟦ ∨ ⟧       = 2→1 Bool._∨_
  ⟦ xor ⟧     = 2→1 Bool._xor_
  ⟦ not ⟧     = 1→1 Bool.not
  ⟦ const a ⟧ = F.const a
  ⟦ input ⟧   = F.const (replicate Bool.false)
  ⟦ output ⟧  = F.const []

  show : a ⇨ b → String
  show ∧         = "∧"
  show ∨         = "∨"
  show xor       = "xor"
  show not       = "not"
  show (const x) = showBits x
  show input     = "input"
  show output    = "output"

-- Combinational circuits
module c where

  infix  0 _⇨_
  infixr 7 _⊗_
  infixr 9 _∘_

  data _⇨_ : ℕ → ℕ → Set where
    route : a r.⇨ b → a ⇨ b
    prim : a p.⇨ b → a ⇨ b
    _∘_ : b ⇨ c → a ⇨ b → a ⇨ c
    _⊗_ : a ⇨ c → b ⇨ d → a + b ⇨ c + d

  ⟦_⟧ : a ⇨ b → a b.⇨ b
  ⟦ route r ⟧ xs = tabulate (lookup xs F.∘ r)
  ⟦ prim  p ⟧ = p.⟦ p ⟧
  ⟦ g ∘ f ⟧ = ⟦ g ⟧ b.∘ ⟦ f ⟧
  ⟦ f ⊗ g ⟧ = ⟦ f ⟧ b.⊗ ⟦ g ⟧

  -- TODO: Prove the cartesian category laws for _⇨_. Probably easier if
  -- parametrized by denotation.

  id  : a ⇨ a
  dup : a ⇨ a + a
  exl : a + b ⇨ a
  exr : a + b ⇨ b
  !   : a ⇨ 0

  id         = route r.id
  dup {a}    = route (r.dup {a})
  exl {a}{b} = route (r.exl {a}{b})
  exr {a}{b} = route (r.exr {a}{b})
  !          = route λ ()

  -- ∧ ∨ xor : 2 ⇨ 1
  -- not : 1 ⇨ 1
  -- ∧   = prim p.∧
  -- ∨   = prim p.∨
  -- xor = prim p.xor
  -- not = prim p.not

  -- Cartesian-categorical operations with standard definitions:

  infixr 7 _△_
  _△_ : a ⇨ c → a ⇨ d → a ⇨ c + d
  f △ g = (f ⊗ g) ∘ dup

  first : a ⇨ c → a + b ⇨ c + b
  first f = f ⊗ id

  second : b ⇨ d → a + b ⇨ a + d
  second f = id ⊗ f

  -- Some useful composite combinational circuits

  assocˡ : a + (b + c) ⇨ (a + b) + c
  assocʳ : (a + b) + c ⇨ a + (b + c)

  assocˡ {a}{b}{c} = second (exl {b}) △ exr {b} ∘ exr {a}
  assocʳ {a}{b}{c} = exl {a} ∘ exl △ first (exr {a})

  -- assocˡ = second exl △ exr ∘ exr
  -- assocʳ = exl ∘ exl △ first exr

  swap : a + b ⇨ b + a
  swap {a}{b} = exr △ exl {a}

  transpose : (a + b) + (c + d) ⇨ (a + c) + (b + d)
  transpose {a}{b}{c}{d} = (exl {a} ⊗ exl {c}) △ (exr {a} ⊗ exr {c})

  -- If I parametrize by Ty instead of ℕ, the implicit arguments will be inferred.

-- Synchronous state machine.
module s where

  -- For composability, the state type is not visible in the type.
  infix  0 _⇨_
  record _⇨_ (a b : ℕ) : Set where
    constructor mealy
    field
      { σ } : ℕ
      start : Bits σ
      transition : a + σ c.⇨ b + σ


--   import Mealy as m

--   ⟦_⟧ : a ⇨ b → ⟦ a ⟧ᵗ m.⇨ ⟦ b ⟧ᵗ
--   ⟦ mealy s₀ f ⟧ = m.mealy s₀ c.⟦ f ⟧

--   comb : a c.⇨ b → a ⇨ b
--   comb f = mealy tt (c.first f)

--   id : A ⇨ A
--   id = comb c.id

--   delay : ⟦ A ⟧ᵗ → A ⇨ A
--   delay a₀ = mealy a₀ c.swap

--   infixr 9 _∘_
--   _∘_ : b ⇨ c → a ⇨ b → a ⇨ c
--   mealy t₀ g ∘ mealy s₀ f = mealy (s₀ , t₀)
--     (swiz₂ c.∘ c.second g c.∘ swiz₁ c.∘ c.first f c.∘ c.assocˡ)
--    where
--      swiz₁ : (b × σ) × τ c.⇨ σ × (b × τ)
--      swiz₁ = c.exr c.∘ c.exl c.△ c.first c.exl
--      swiz₂ : σ × (c × τ) c.⇨ c × (σ × τ)
--      swiz₂ = c.exl c.∘ c.exr c.△ c.second c.exr

--   infixr 7 _⊗_
--   _⊗_ : a ⇨ c → b ⇨ d → a × b ⇨ c × d
--   mealy s₀ f ⊗ mealy t₀ g = mealy (s₀ , t₀) (c.transpose c.∘ (f c.⊗ g) c.∘ c.transpose)

--   infixr 7 _△_
--   _△_ : a ⇨ c → a ⇨ d → a ⇨ c × d
--   f △ g = (f ⊗ g) ∘ comb c.dup


-- -- TODO: consider making categorical operations (most of the functionality in
-- -- this module) be methods of a common typeclass, so that (a) we can state and
-- -- prove laws conveniently, and (b) we needn't use clumsy names.

-- -- TODO: Rebuild this module in terms of semantic Mealy machines.

-- -- TODO: Prove the cartesian category laws for _⇨_. Probably easier if
-- -- parametrized by denotation.

-- -- TODO: Cocartesian.

-- -- TODO: replicate compiling-to-categories using Agda reflection, and use to
-- -- make definitions like `_∘_` and `_⊗_` above read like their counterparts in
-- -- the Mealy module.
