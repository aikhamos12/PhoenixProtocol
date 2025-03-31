;; PhoenixProtocol: A staged resource allocation system with verification mechanisms
;; This protocol enables resource contributions through a secure milestone-based framework
;; with built-in verification, monitoring, and safety systems.

;; Core protocol parameters
(define-constant GOVERNANCE_CONTROLLER tx-sender)
(define-constant ERROR_ACCESS_DENIED (err u300))
(define-constant ERROR_ENTITY_MISSING (err u301))
(define-constant ERROR_ASSETS_ALREADY_ALLOCATED (err u302))
(define-constant ERROR_OPERATION_FAILURE (err u303))
(define-constant ERROR_PARAMETER_INVALID (err u304))
(define-constant ERROR_PHASE_VALIDATION_FAILED (err u305))
(define-constant ERROR_TIMELOCK_VIOLATION (err u306))
(define-constant ALLOCATION_TIMELOCK_PERIOD u1008)

;; Resource tracking matrix
(define-map ResourceAllocations
  { phoenix-id: uint }
  {
    provider: principal,
    beneficiary: principal,
    resource-amount: uint,
    lifecycle-state: (string-ascii 10),
    genesis-block: uint,
    conclusion-block: uint,
    allocation-phases: (list 5 uint),
    phase-completions: uint
  }
)

(define-data-var current-phoenix-id uint u0)

;; Protocol security circuit breaker
(define-constant PROTOCOL_SUSPENSION_PERIOD u720)
(define-constant ERROR_PROTOCOL_SUSPENDED (err u322))
(define-constant ERROR_COOLING_PERIOD_ACTIVE (err u323))

;; Utility validation functions
(define-private (verify-beneficiary-eligibility (beneficiary principal))
  (not (is-eq beneficiary tx-sender))
)

(define-private (verify-allocation-exists (phoenix-id uint))
  (<= phoenix-id (var-get current-phoenix-id))
)

;; Multi-beneficiary configuration parameters
(define-constant MULTI_BENEFICIARY_LIMIT u5)
(define-constant ERROR_BENEFICIARY_OVERFLOW (err u324))
(define-constant ERROR_ALLOCATION_IMBALANCE (err u325))

;; Multi-beneficiary resource allocation tracking
(define-map BranchedResourceAllocations
  { branch-id: uint }
  {
    provider: principal,
    branches: (list 5 { target-entity: principal, share-percentage: uint }),
    aggregate-resources: uint,
    formation-timestamp: uint,
    branch-status: (string-ascii 10)
  }
)

(define-data-var current-branch-id uint u0)

;; Percentage calculation helper
(define-private (extract-allocation-share (branch-config { target-entity: principal, share-percentage: uint }))
  (get share-percentage branch-config)
)

;; Phoenix protocol core functions

;; Initialize a new phoenix allocation with multiple phases
(define-public (spawn-phoenix-allocation (beneficiary principal) (resource-quantity uint) (allocation-phases (list 5 uint)))
  (let
    (
      (phoenix-id (+ (var-get current-phoenix-id) u1))
      (termination-block (+ block-height ALLOCATION_TIMELOCK_PERIOD))
    )
    (asserts! (> resource-quantity u0) ERROR_PARAMETER_INVALID)
    (asserts! (verify-beneficiary-eligibility beneficiary) ERROR_PHASE_VALIDATION_FAILED)
    (asserts! (> (len allocation-phases) u0) ERROR_PHASE_VALIDATION_FAILED)
    (match (stx-transfer? resource-quantity tx-sender (as-contract tx-sender))
      success
        (begin
          (map-set ResourceAllocations
            { phoenix-id: phoenix-id }
            {
              provider: tx-sender,
              beneficiary: beneficiary,
              resource-amount: resource-quantity,
              lifecycle-state: "active",
              genesis-block: block-height,
              conclusion-block: termination-block,
              allocation-phases: allocation-phases,
              phase-completions: u0
            }
          )
          (var-set current-phoenix-id phoenix-id)
          (ok phoenix-id)
        )
      error ERROR_OPERATION_FAILURE
    )
  )
)

;; Release resources for a completed allocation phase
(define-public (release-phase-allocation (phoenix-id uint))
  (begin
    (asserts! (verify-allocation-exists phoenix-id) ERROR_PARAMETER_INVALID)
    (let
      (
        (allocation-record (unwrap! (map-get? ResourceAllocations { phoenix-id: phoenix-id }) ERROR_ENTITY_MISSING))
        (allocation-phases (get allocation-phases allocation-record))
        (completed-phases (get phase-completions allocation-record))
        (beneficiary (get beneficiary allocation-record))
        (total-resources (get resource-amount allocation-record))
        (phase-resource-amount (/ total-resources (len allocation-phases)))
      )
      (asserts! (< completed-phases (len allocation-phases)) ERROR_ASSETS_ALREADY_ALLOCATED)
      (asserts! (is-eq tx-sender GOVERNANCE_CONTROLLER) ERROR_ACCESS_DENIED)
      (match (stx-transfer? phase-resource-amount (as-contract tx-sender) beneficiary)
        success
          (begin
            (map-set ResourceAllocations
              { phoenix-id: phoenix-id }
              (merge allocation-record { phase-completions: (+ completed-phases u1) })
            )
            (ok true)
          )
        error ERROR_OPERATION_FAILURE
      )
    )
  )
)

;; Multi-beneficiary allocation creation
(define-public (create-branched-allocation (branches (list 5 { target-entity: principal, share-percentage: uint })) (resource-quantity uint))
  (begin
    (asserts! (> resource-quantity u0) ERROR_PARAMETER_INVALID)
    (asserts! (> (len branches) u0) ERROR_PARAMETER_INVALID)
    (asserts! (<= (len branches) MULTI_BENEFICIARY_LIMIT) ERROR_BENEFICIARY_OVERFLOW)

    (let
      (
        (total-percentage (fold + (map extract-allocation-share branches) u0))
      )
      (asserts! (is-eq total-percentage u100) ERROR_ALLOCATION_IMBALANCE)

      (match (stx-transfer? resource-quantity tx-sender (as-contract tx-sender))
        success
          (let
            (
              (branch-id (+ (var-get current-branch-id) u1))
            )
            (map-set BranchedResourceAllocations
              { branch-id: branch-id }
              {
                provider: tx-sender,
                branches: branches,
                aggregate-resources: resource-quantity,
                formation-timestamp: block-height,
                branch-status: "pending"
              }
            )
            (var-set current-branch-id branch-id)
            (ok branch-id)
          )
        error ERROR_OPERATION_FAILURE
      )
    )
  )
)

