;; Bidding Process Contract
;; Manages transparent bidding processes for government contracts

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_BID_NOT_FOUND (err u201))
(define-constant ERR_BIDDING_CLOSED (err u202))
(define-constant ERR_INVALID_VENDOR (err u203))
(define-constant ERR_BID_TOO_LOW (err u204))

;; Bidding status
(define-constant BIDDING_OPEN u0)
(define-constant BIDDING_CLOSED u1)
(define-constant BIDDING_AWARDED u2)

;; Procurement data structure
(define-map procurements
  { procurement-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 500),
    budget: uint,
    deadline: uint,
    status: uint,
    created-by: principal,
    winner-vendor-id: (optional uint)
  }
)

;; Bid data structure
(define-map bids
  { procurement-id: uint, vendor-id: uint }
  {
    amount: uint,
    proposal: (string-ascii 500),
    submitted-at: uint,
    bidder: principal
  }
)

(define-data-var next-procurement-id uint u1)

;; Create a new procurement
(define-public (create-procurement (title (string-ascii 200)) (description (string-ascii 500)) (budget uint) (deadline uint))
  (let ((procurement-id (var-get next-procurement-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set procurements
      { procurement-id: procurement-id }
      {
        title: title,
        description: description,
        budget: budget,
        deadline: deadline,
        status: BIDDING_OPEN,
        created-by: tx-sender,
        winner-vendor-id: none
      }
    )
    (var-set next-procurement-id (+ procurement-id u1))
    (ok procurement-id)
  )
)

;; Submit a bid
(define-public (submit-bid (procurement-id uint) (vendor-id uint) (amount uint) (proposal (string-ascii 500)))
  (match (map-get? procurements { procurement-id: procurement-id })
    procurement-data (begin
      (asserts! (is-eq (get status procurement-data) BIDDING_OPEN) ERR_BIDDING_CLOSED)
      (asserts! (< block-height (get deadline procurement-data)) ERR_BIDDING_CLOSED)
      (asserts! (<= amount (get budget procurement-data)) ERR_BID_TOO_LOW)
      (map-set bids
        { procurement-id: procurement-id, vendor-id: vendor-id }
        {
          amount: amount,
          proposal: proposal,
          submitted-at: block-height,
          bidder: tx-sender
        }
      )
      (ok true)
    )
    ERR_BID_NOT_FOUND
  )
)

;; Award contract to winning vendor
(define-public (award-contract (procurement-id uint) (winner-vendor-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? procurements { procurement-id: procurement-id })
      procurement-data (begin
        (map-set procurements
          { procurement-id: procurement-id }
          (merge procurement-data { status: BIDDING_AWARDED, winner-vendor-id: (some winner-vendor-id) })
        )
        (ok true)
      )
      ERR_BID_NOT_FOUND
    )
  )
)

;; Get procurement details
(define-read-only (get-procurement (procurement-id uint))
  (map-get? procurements { procurement-id: procurement-id })
)

;; Get bid details
(define-read-only (get-bid (procurement-id uint) (vendor-id uint))
  (map-get? bids { procurement-id: procurement-id, vendor-id: vendor-id })
)
