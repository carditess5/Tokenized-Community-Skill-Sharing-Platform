;; Payment Processing Contract
;; Handles compensation for skill-sharing services

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-PAYMENT-NOT-FOUND (err u401))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-PAYMENT-ALREADY-PROCESSED (err u403))
(define-constant ERR-INVALID-AMOUNT (err u404))
(define-constant ERR-ESCROW-NOT-FOUND (err u405))

;; Data Variables
(define-data-var next-payment-id uint u1)
(define-data-var platform-fee-rate uint u500) ;; 5% in basis points
(define-data-var dispute-window uint u144) ;; 24 hours in blocks

;; Payment Status Constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-ESCROWED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-REFUNDED u4)
(define-constant STATUS-DISPUTED u5)

;; Data Maps
(define-map payments
  { payment-id: uint }
  {
    payer: principal,
    payee: principal,
    session-id: uint,
    amount: uint,
    platform-fee: uint,
    status: uint,
    created-at: uint,
    processed-at: (optional uint),
    dispute-reason: (optional (string-ascii 200))
  }
)

(define-map escrow-balances
  { session-id: uint, payer: principal }
  {
    amount: uint,
    locked-at: uint,
    release-at: uint,
    is-locked: bool
  }
)

(define-map teacher-earnings
  { teacher: principal }
  {
    total-earned: uint,
    pending-amount: uint,
    withdrawn-amount: uint,
    session-count: uint,
    last-payment: uint
  }
)

(define-map payment-disputes
  { payment-id: uint }
  {
    disputed-by: principal,
    dispute-reason: (string-ascii 200),
    disputed-at: uint,
    resolved-at: (optional uint),
    resolution: (optional (string-ascii 200)),
    resolved-by: (optional principal)
  }
)

(define-map refund-requests
  { payment-id: uint }
  {
    requested-by: principal,
    reason: (string-ascii 200),
    requested-at: uint,
    approved: bool,
    processed-at: (optional uint)
  }
)

;; Public Functions

;; Create payment and hold in escrow
(define-public (create-payment (payee principal) (session-id uint) (amount uint))
  (let
    (
      (payment-id (var-get next-payment-id))
      (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
      (total-amount (+ amount platform-fee))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    ;; Transfer total amount to contract for escrow
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

    ;; Record payment
    (map-set payments
      { payment-id: payment-id }
      {
        payer: tx-sender,
        payee: payee,
        session-id: session-id,
        amount: amount,
        platform-fee: platform-fee,
        status: STATUS-ESCROWED,
        created-at: block-height,
        processed-at: none,
        dispute-reason: none
      }
    )

    ;; Record escrow
    (map-set escrow-balances
      { session-id: session-id, payer: tx-sender }
      {
        amount: total-amount,
        locked-at: block-height,
        release-at: (+ block-height (var-get dispute-window)),
        is-locked: true
      }
    )

    (var-set next-payment-id (+ payment-id u1))
    (ok payment-id)
  )
)

;; Release payment to teacher after session completion
(define-public (release-payment (payment-id uint))
  (let
    (
      (payment (unwrap! (map-get? payments { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
      (escrow (unwrap! (map-get? escrow-balances { session-id: (get session-id payment), payer: (get payer payment) }) ERR-ESCROW-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get payer payment)) (is-eq tx-sender (get payee payment))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) STATUS-ESCROWED) ERR-PAYMENT-ALREADY-PROCESSED)
    (asserts! (>= block-height (get release-at escrow)) ERR-NOT-AUTHORIZED)

    ;; Transfer payment to teacher
    (try! (as-contract (stx-transfer? (get amount payment) tx-sender (get payee payment))))

    ;; Transfer platform fee to contract owner
    (try! (as-contract (stx-transfer? (get platform-fee payment) tx-sender CONTRACT-OWNER)))

    ;; Update payment status
    (map-set payments
      { payment-id: payment-id }
      (merge payment {
        status: STATUS-COMPLETED,
        processed-at: (some block-height)
      })
    )

    ;; Update escrow
    (map-set escrow-balances
      { session-id: (get session-id payment), payer: (get payer payment) }
      (merge escrow { is-locked: false })
    )

    ;; Update teacher earnings
    (match (map-get? teacher-earnings { teacher: (get payee payment) })
      earnings (map-set teacher-earnings
        { teacher: (get payee payment) }
        (merge earnings {
          total-earned: (+ (get total-earned earnings) (get amount payment)),
          session-count: (+ (get session-count earnings) u1),
          last-payment: block-height
        })
      )
      (map-set teacher-earnings
        { teacher: (get payee payment) }
        {
          total-earned: (get amount payment),
          pending-amount: u0,
          withdrawn-amount: u0,
          session-count: u1,
          last-payment: block-height
        }
      )
    )

    (ok true)
  )
)

;; Request refund
(define-public (request-refund (payment-id uint) (reason (string-ascii 200)))
  (let
    (
      (payment (unwrap! (map-get? payments { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get payer payment)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) STATUS-ESCROWED) ERR-PAYMENT-ALREADY-PROCESSED)

    (map-set refund-requests
      { payment-id: payment-id }
      {
        requested-by: tx-sender,
        reason: reason,
        requested-at: block-height,
        approved: false,
        processed-at: none
      }
    )

    (ok true)
  )
)

;; Process refund (contract owner only)
(define-public (process-refund (payment-id uint) (approve bool))
  (let
    (
      (payment (unwrap! (map-get? payments { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
      (refund-request (unwrap! (map-get? refund-requests { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
      (escrow (unwrap! (map-get? escrow-balances { session-id: (get session-id payment), payer: (get payer payment) }) ERR-ESCROW-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) STATUS-ESCROWED) ERR-PAYMENT-ALREADY-PROCESSED)

    (if approve
      (begin
        ;; Refund to payer
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get payer payment))))

        ;; Update payment status
        (map-set payments
          { payment-id: payment-id }
          (merge payment {
            status: STATUS-REFUNDED,
            processed-at: (some block-height)
          })
        )

        ;; Update escrow
        (map-set escrow-balances
          { session-id: (get session-id payment), payer: (get payer payment) }
          (merge escrow { is-locked: false })
        )
      )
      true
    )

    ;; Update refund request
    (map-set refund-requests
      { payment-id: payment-id }
      (merge refund-request {
        approved: approve,
        processed-at: (some block-height)
      })
    )

    (ok approve)
  )
)

;; Dispute payment
(define-public (dispute-payment (payment-id uint) (reason (string-ascii 200)))
  (let
    (
      (payment (unwrap! (map-get? payments { payment-id: payment-id }) ERR-PAYMENT-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get payer payment)) (is-eq tx-sender (get payee payment))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status payment) STATUS-ESCROWED) ERR-PAYMENT-ALREADY-PROCESSED)

    (map-set payment-disputes
      { payment-id: payment-id }
      {
        disputed-by: tx-sender,
        dispute-reason: reason,
        disputed-at: block-height,
        resolved-at: none,
        resolution: none,
        resolved-by: none
      }
    )

    (map-set payments
      { payment-id: payment-id }
      (merge payment {
        status: STATUS-DISPUTED,
        dispute-reason: (some reason)
      })
    )

    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-escrow-balance (session-id uint) (payer principal))
  (map-get? escrow-balances { session-id: session-id, payer: payer })
)

(define-read-only (get-teacher-earnings (teacher principal))
  (map-get? teacher-earnings { teacher: teacher })
)

(define-read-only (get-payment-dispute (payment-id uint))
  (map-get? payment-disputes { payment-id: payment-id })
)

(define-read-only (get-refund-request (payment-id uint))
  (map-get? refund-requests { payment-id: payment-id })
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)
