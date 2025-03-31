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

