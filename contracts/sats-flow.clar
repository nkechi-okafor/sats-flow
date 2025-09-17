;; Title: SatsFlow - Intelligent Asset Orchestration Protocol

;; Summary: Next-generation decentralized portfolio automation platform
;;          leveraging Bitcoin's security through Stacks Layer 2
;; Description: SatsFlow revolutionizes digital asset management by
;;              providing institutional-grade portfolio orchestration
;;              tools built on Bitcoin's unparalleled security foundation.
;;              Our protocol enables sophisticated investors to construct,
;;              monitor, and dynamically optimize multi-asset portfolios
;;              with algorithmic precision. Through intelligent rebalancing
;;              algorithms and fee-optimized execution, SatsFlow transforms
;;              complex investment strategies into seamless, automated
;;              wealth-building experiences on the Stacks ecosystem.

;; ERROR CODES
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PORTFOLIO (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-TOKEN (err u103))
(define-constant ERR-REBALANCE-FAILED (err u104))
(define-constant ERR-PORTFOLIO-EXISTS (err u105))
(define-constant ERR-INVALID-PERCENTAGE (err u106))
(define-constant ERR-MAX-TOKENS-EXCEEDED (err u107))
(define-constant ERR-LENGTH-MISMATCH (err u108))
(define-constant ERR-USER-STORAGE-FAILED (err u109))
(define-constant ERR-INVALID-TOKEN-ID (err u110))

;; PROTOCOL CONFIGURATION
(define-data-var protocol-owner principal tx-sender)
(define-data-var portfolio-counter uint u0)
(define-data-var protocol-fee uint u25) ;; 0.25% represented as basis points

;; SYSTEM CONSTANTS
(define-constant MAX-TOKENS-PER-PORTFOLIO u10)
(define-constant BASIS-POINTS u10000)

;; CORE DATA STRUCTURES

;; Portfolio metadata and configuration registry
(define-map Portfolios
  uint ;; portfolio-id
  {
    owner: principal,
    created-at: uint,
    last-rebalanced: uint,
    total-value: uint,
    active: bool,
    token-count: uint,
  }
)

;; Individual asset allocation within portfolios
(define-map PortfolioAssets
  {
    portfolio-id: uint,
    token-id: uint,
  }
  {
    target-percentage: uint,
    current-amount: uint,
    token-address: principal,
  }
)

;; User portfolio ownership mapping
(define-map UserPortfolios
  principal
  (list 20 uint)
)

;; PUBLIC READ-ONLY FUNCTIONS

;; Retrieve comprehensive portfolio details by unique identifier
(define-read-only (get-portfolio (portfolio-id uint))
  (map-get? Portfolios portfolio-id)
)

;; Get specific asset allocation configuration within a portfolio
(define-read-only (get-portfolio-asset
    (portfolio-id uint)
    (token-id uint)
  )
  (map-get? PortfolioAssets {
    portfolio-id: portfolio-id,
    token-id: token-id,
  })
)

;; Retrieve all portfolios owned by a specific user
(define-read-only (get-user-portfolios (user principal))
  (default-to (list) (map-get? UserPortfolios user))
)

;; Calculate portfolio rebalancing requirements and status
(define-read-only (calculate-rebalance-amounts (portfolio-id uint))
  (let (
      (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
      (total-value (get total-value portfolio))
    )
    (ok {
      portfolio-id: portfolio-id,
      total-value: total-value,
      needs-rebalance: (> (- stacks-block-height (get last-rebalanced portfolio)) u144), ;; 24 hours in blocks
    })
  )
)

;; PRIVATE UTILITY FUNCTIONS

;; Validate token identifier against portfolio constraints
(define-private (validate-token-id
    (portfolio-id uint)
    (token-id uint)
  )
  (let ((portfolio (unwrap! (get-portfolio portfolio-id) false)))
    (and
      (< token-id MAX-TOKENS-PER-PORTFOLIO)
      (< token-id (get token-count portfolio))
      true
    )
  )
)

;; Validate percentage allocation within acceptable bounds
(define-private (validate-percentage (percentage uint))
  (and (>= percentage u0) (<= percentage BASIS-POINTS))
)

;; Validate total portfolio percentage allocation integrity
(define-private (validate-portfolio-percentages (percentages (list 10 uint)))
  (fold check-percentage-sum percentages true)
)