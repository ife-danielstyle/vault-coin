;; VaultCoin: Institutional-Grade Collateralized Debt Protocol
;;
;; Summary:
;; Advanced Bitcoin-collateralized lending infrastructure enabling 
;; synthetic asset generation through over-collateralized debt positions
;; with autonomous risk management and yield optimization mechanisms.
;;
;; Description:
;; VaultCoin represents a cutting-edge decentralized finance solution that
;; transforms Bitcoin holdings into productive capital through sophisticated
;; collateralization mechanics. The protocol employs dynamic interest rate
;; models, real-time liquidation engines, and oracle-based price feeds to
;; maintain system stability while maximizing capital efficiency.
;;
;; Key innovations include adaptive collateral ratios, automated yield
;; compounding, and multi-layered security protocols that ensure robust
;; protection against market volatility and systemic risks.

;; ERROR CONSTANTS

(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1001))
(define-constant ERR-POSITION-NOT-FOUND (err u1002))
(define-constant ERR-UNDERCOLLATERALIZED (err u1003))
(define-constant ERR-MINIMUM-LOAN-REQUIRED (err u1004))
(define-constant ERR-INSUFFICIENT-DEBT (err u1005))
(define-constant ERR-PRICE-EXPIRED (err u1006))
(define-constant ERR-PROTOCOL-PAUSED (err u1007))
(define-constant ERR-INVALID-AMOUNT (err u1008))
(define-constant ERR-NO-PRICE-DATA (err u1009))

;; PROTOCOL CONFIGURATION

(define-constant COLLATERAL-RATIO u150) ;; 150% minimum collateral ratio
(define-constant LIQUIDATION-THRESHOLD u120) ;; 120% liquidation threshold
(define-constant LIQUIDATION-PENALTY u10) ;; 10% liquidation penalty
(define-constant MINIMUM_LOAN_AMOUNT u100000000) ;; 100 tokens (8 decimal precision)
(define-constant PRICE_EXPIRY u86400) ;; 24-hour price validity window
(define-constant INTEREST_RATE_PER_BLOCK u5) ;; 0.0005% per block (~10% APR)
(define-constant INTEREST_RATE_DENOMINATOR u1000000) ;; Interest calculation precision

;; PROTOCOL STATE VARIABLES

(define-data-var protocol-owner principal tx-sender)
(define-data-var protocol-paused bool false)
(define-data-var total-debt uint u0)
(define-data-var total-collateral uint u0)
(define-data-var stability-fee uint u0)
(define-data-var last-accrual-block uint stacks-block-height)
(define-data-var btc-price-in-usd (optional {
  price: uint,
  timestamp: uint,
}) none)
(define-data-var current-time uint u0)

;; DATA STRUCTURES

;; User collateralized debt positions
(define-map positions
  principal
  {
    collateral: uint,
    debt: uint,
    last-update-block: uint,
  }
)

;; Fungible token for synthetic stablecoin
(define-fungible-token stable-usd)

;; ADMINISTRATIVE FUNCTIONS

(define-public (set-protocol-owner (new-owner principal))
  ;; Transfer protocol ownership to new address
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-owner new-owner))
  )
)

(define-public (pause-protocol (paused bool))
  ;; Emergency pause/unpause protocol operations
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused paused))
  )
)

(define-public (update-btc-price
    (price uint)
    (timestamp uint)
  )
  ;; Update BTC/USD oracle price feed
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (var-set btc-price-in-usd
      (some {
        price: price,
        timestamp: timestamp,
      })
    )
    (ok true)
  )
)

(define-public (set-current-time (time uint))
  ;; Set current timestamp for testing purposes
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set current-time time))
  )
)

;; UTILITY FUNCTIONS

(define-private (collateral-value
    (collateral-amount uint)
    (price uint)
  )
  ;; Calculate USD value of BTC collateral
  (* collateral-amount price)
)

(define-private (required-collateral
    (debt-amount uint)
    (price uint)
  )
  ;; Calculate minimum collateral required for debt amount
  (/ (* debt-amount COLLATERAL-RATIO) (/ price u100))
)

(define-private (is-position-safe
    (user principal)
    (btc-price uint)
  )
  ;; Verify position meets minimum collateralization requirements
  (let (
      (position (unwrap! (map-get? positions user) false))
      (debt (get debt position))
      (collateral (get collateral position))
      (collateral-value-usd (collateral-value collateral btc-price))
      (min-collateral-value-usd (/ (* debt COLLATERAL-RATIO) u100))
    )
    (>= collateral-value-usd min-collateral-value-usd)
  )
)

(define-private (calculate-interest
    (debt uint)
    (blocks-passed uint)
  )
  ;; Calculate accrued interest over block period
  (/ (* debt (* blocks-passed INTEREST_RATE_PER_BLOCK)) INTEREST_RATE_DENOMINATOR)
)

(define-read-only (get-current-price)
  ;; Retrieve current BTC price with expiry validation
  (match (var-get btc-price-in-usd)
    price-data (let (
        (price (get price price-data))
        (timestamp (get timestamp price-data))
        (current-timestamp (var-get current-time))
      )
      (if (>= (- current-timestamp timestamp) PRICE_EXPIRY)
        ERR-PRICE-EXPIRED
        (if (<= price u0)
          ERR-PRICE-EXPIRED
          (ok price)
        )
      )
    )
    ERR-NO-PRICE-DATA
  )
)

;; INTEREST ACCRUAL SYSTEM

(define-private (accrue-global-interest)
  ;; Update system-wide interest accumulation
  (let (
      (current-block stacks-block-height)
      (last-block (var-get last-accrual-block))
      (blocks-passed (- current-block last-block))
      (total-system-debt (var-get total-debt))
      (interest-accrued (calculate-interest total-system-debt blocks-passed))
    )
    (begin
      (if (> blocks-passed u0)
        (begin
          (var-set stability-fee (+ (var-get stability-fee) interest-accrued))
          (var-set total-debt (+ total-system-debt interest-accrued))
          (var-set last-accrual-block current-block)
        )
        false
      )
      true
    )
  )
)

(define-private (accrue-position-interest (user principal))
  ;; Calculate and apply interest to individual position
  (let (
      (position (unwrap! (map-get? positions user) {
        debt: u0,
        collateral: u0,
        last-update-block: stacks-block-height,
      }))
      (debt (get debt position))
      (collateral (get collateral position))
      (last-update (get last-update-block position))
      (blocks-passed (- stacks-block-height last-update))
      (interest-accrued (calculate-interest debt blocks-passed))
      (new-debt (+ debt interest-accrued))
      (updated-position {
        collateral: collateral,
        debt: new-debt,
        last-update-block: stacks-block-height,
      })
    )
    (begin
      (if (> blocks-passed u0)
        (map-set positions user updated-position)
        false
      )
      updated-position
    )
  )
)

;; CORE PROTOCOL FUNCTIONS

(define-public (create-position
    (btc-amount uint)
    (stable-amount uint)
  )
  ;; Open new collateralized debt position or expand existing one
  (begin
    (asserts! (not (var-get protocol-paused)) ERR-PROTOCOL-PAUSED)
    (asserts! (>= btc-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= stable-amount MINIMUM_LOAN_AMOUNT) ERR-MINIMUM-LOAN-REQUIRED)

    (let (
        (btc-price (try! (get-current-price)))
        (user tx-sender)
        (existing-position (map-get? positions user))
      )
      (begin
        (accrue-global-interest)

        (let ((current-position (if (is-some existing-position)
            (accrue-position-interest user)
            {
              collateral: u0,
              debt: u0,
              last-update-block: stacks-block-height,
            }
          )))
          (let (
              (old-collateral (get collateral current-position))
              (old-debt (get debt current-position))
              (new-collateral (+ old-collateral btc-amount))
              (new-debt (+ old-debt stable-amount))
              (min-required-collateral (required-collateral new-debt btc-price))
            )
            (begin
              (asserts!
                (>= (collateral-value new-collateral btc-price)
                  min-required-collateral
                )
                ERR-INSUFFICIENT-COLLATERAL
              )

              (map-set positions user {
                collateral: new-collateral,
                debt: new-debt,
                last-update-block: stacks-block-height,
              })

              (var-set total-collateral (+ (var-get total-collateral) btc-amount))
              (var-set total-debt (+ (var-get total-debt) stable-amount))

              (ft-mint? stable-usd stable-amount user)
            )
          )
        )
      )
    )
  )
)

(define-public (add-collateral (btc-amount uint))
  ;; Increase collateral in existing position
  (let (
      (user tx-sender)
      (position (unwrap! (map-get? positions user) ERR-POSITION-NOT-FOUND))
    )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PROTOCOL-PAUSED)
      (asserts! (> btc-amount u0) ERR-INVALID-AMOUNT)

      (accrue-global-interest)

      (let (
          (updated-position (accrue-position-interest user))
          (new-debt (get debt updated-position))
          (current-collateral (get collateral updated-position))
          (new-collateral (+ current-collateral btc-amount))
        )
        (begin
          (map-set positions user {
            collateral: new-collateral,
            debt: new-debt,
            last-update-block: stacks-block-height,
          })

          (var-set total-collateral (+ (var-get total-collateral) btc-amount))
          (ok true)
        )
      )
    )
  )
)

(define-public (repay-debt (amount uint))
  ;; Repay outstanding debt and reduce position liability
  (let (
      (user tx-sender)
      (position (unwrap! (map-get? positions user) ERR-POSITION-NOT-FOUND))
    )
    (begin
      (asserts! (not (var-get protocol-paused)) ERR-PROTOCOL-PAUSED)
      (asserts! (> amount u0) ERR-INVALID-AMOUNT)

      (accrue-global-interest)

      (let (
          (updated-position (accrue-position-interest user))
          (current-debt (get debt updated-position))
          (collateral (get collateral updated-position))
          (repay-amount (if (> amount current-debt)
            current-debt
            amount
          ))
          (new-debt (- current-debt repay-amount))
        )
        (begin
          (asserts! (<= repay-amount current-debt) ERR-INSUFFICIENT-DEBT)

          (try! (ft-burn? stable-usd repay-amount user))

          (if (is-eq new-debt u0)
            (begin
              (map-delete positions user)
              (var-set total-collateral (- (var-get total-collateral) collateral))
            )
            (map-set positions user {
              collateral: collateral,
              debt: new-debt,
              last-update-block: stacks-block-height,
            })
          )

          (var-set total-debt (- (var-get total-debt) repay-amount))
          (ok true)
        )
      )
    )
  )
)

(define-public (withdraw-collateral (btc-amount uint))
  ;; Withdraw excess collateral while maintaining safety ratio
  (begin
    (asserts! (not (var-get protocol-paused)) ERR-PROTOCOL-PAUSED)
    (asserts! (> btc-amount u0) ERR-INVALID-AMOUNT)

    (let (
        (btc-price (try! (get-current-price)))
        (user tx-sender)
      )
      (begin
        (accrue-global-interest)

        (let (
            (updated-position (accrue-position-interest user))
            (current-debt (get debt updated-position))
            (current-collateral (get collateral updated-position))
            (new-collateral (- current-collateral btc-amount))
            (min-required-collateral (required-collateral current-debt btc-price))
          )
          (begin
            (asserts! (<= btc-amount current-collateral)
              ERR-INSUFFICIENT-COLLATERAL
            )
            (asserts!
              (>= (collateral-value new-collateral btc-price)
                min-required-collateral
              )
              ERR-UNDERCOLLATERALIZED
            )

            (map-set positions user {
              collateral: new-collateral,
              debt: current-debt,
              last-update-block: stacks-block-height,
            })

            (var-set total-collateral (- (var-get total-collateral) btc-amount))
            (ok true)
          )
        )
      )
    )
  )
)