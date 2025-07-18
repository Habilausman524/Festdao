;; Festdao - Community Celebration DAO
;; Transparent event planning and budget management

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_ALREADY_VOTED (err u403))
(define-constant ERR_VOTING_CLOSED (err u405))
(define-constant ERR_EVENT_NOT_ACTIVE (err u406))
(define-constant ERR_RESOURCE_NOT_AVAILABLE (err u407))
(define-constant ERR_ALREADY_RESERVED (err u408))
(define-constant ERR_NOT_BORROWED (err u409))
(define-constant ERR_INVALID_RATING (err u410))

(define-data-var next-event-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-resource-id uint u1)
(define-data-var next-reservation-id uint u1)
(define-data-var treasury-balance uint u0)
(define-data-var min-voting-period uint u144)

(define-map members principal bool)
(define-map member-reputation principal uint)

(define-map events
  uint
  {
    creator: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    budget-requested: uint,
    budget-approved: uint,
    status: (string-ascii 20),
    created-at: uint,
    event-date: uint
  }
)

(define-map event-expenses
  {event-id: uint, expense-id: uint}
  {
    description: (string-ascii 200),
    amount: uint,
    recipient: principal,
    approved: bool,
    created-at: uint
  }
)

(define-map proposals
  uint
  {
    proposer: principal,
    event-id: uint,
    proposal-type: (string-ascii 50),
    amount: uint,
    description: (string-ascii 300),
    votes-for: uint,
    votes-against: uint,
    voting-end: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {vote: bool, weight: uint}
)

(define-map event-participants
  {event-id: uint, participant: principal}
  {joined-at: uint, contribution: uint}
)

(define-map resources
  uint
  {
    owner: principal,
    name: (string-ascii 100),
    description: (string-ascii 300),
    category: (string-ascii 50),
    daily-rate: uint,
    available: bool,
    location: (string-ascii 200),
    deposit-required: uint,
    total-ratings: uint,
    rating-count: uint,
    created-at: uint
  }
)

(define-map resource-reservations
  uint
  {
    resource-id: uint,
    borrower: principal,
    start-date: uint,
    end-date: uint,
    total-cost: uint,
    deposit-paid: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map resource-ratings
  {resource-id: uint, rater: principal}
  {rating: uint, comment: (string-ascii 200), created-at: uint}
)

(define-public (become-member)
  (begin
    (asserts! (is-none (map-get? members tx-sender)) ERR_ALREADY_EXISTS)
    (map-set members tx-sender true)
    (map-set member-reputation tx-sender u1)
    (ok true)
  )
)

(define-public (create-event (name (string-ascii 100)) (description (string-ascii 500)) (budget-requested uint) (event-date uint))
  (let ((event-id (var-get next-event-id)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> budget-requested u0) ERR_INVALID_AMOUNT)
    (asserts! (> event-date stacks-block-height) ERR_INVALID_AMOUNT)
    
    (map-set events event-id {
      creator: tx-sender,
      name: name,
      description: description,
      budget-requested: budget-requested,
      budget-approved: u0,
      status: "pending",
      created-at: stacks-block-height,
      event-date: event-date
    })
    
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

(define-public (create-budget-proposal (event-id uint) (amount uint) (description (string-ascii 300)))
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? events event-id)) ERR_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (map-set proposals proposal-id {
      proposer: tx-sender,
      event-id: event-id,
      proposal-type: "budget",
      amount: amount,
      description: description,
      votes-for: u0,
      votes-against: u0,
      voting-end: (+ stacks-block-height (var-get min-voting-period)),
      status: "active",
      created-at: stacks-block-height
    })
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND))
    (voter-reputation (unwrap! (map-get? member-reputation tx-sender) ERR_UNAUTHORIZED))
    (existing-vote (map-get? votes {proposal-id: proposal-id, voter: tx-sender}))
  )
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    (asserts! (< stacks-block-height (get voting-end proposal)) ERR_VOTING_CLOSED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    
    (map-set votes {proposal-id: proposal-id, voter: tx-sender} {vote: vote-for, weight: voter-reputation})
    
    (if vote-for
      (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) voter-reputation)}))
      (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) voter-reputation)}))
    )
    
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= stacks-block-height (get voting-end proposal)) ERR_VOTING_CLOSED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    
    (let (
      (votes-for (get votes-for proposal))
      (votes-against (get votes-against proposal))
      (passed (> votes-for votes-against))
    )
      (if passed
        (begin
          (map-set proposals proposal-id (merge proposal {status: "passed"}))
          (try! (approve-event-budget (get event-id proposal) (get amount proposal)))
          (ok true)
        )
        (begin
          (map-set proposals proposal-id (merge proposal {status: "rejected"}))
          (ok false)
        )
      )
    )
  )
)

(define-public (approve-event-budget (event-id uint) (amount uint))
  (let ((event-data (unwrap! (map-get? events event-id) ERR_NOT_FOUND)))
    (asserts! (>= (var-get treasury-balance) amount) ERR_INSUFFICIENT_FUNDS)
    
    (map-set events event-id (merge event-data {
      budget-approved: amount,
      status: "approved"
    }))
    
    (var-set treasury-balance (- (var-get treasury-balance) amount))
    (ok true)
  )
)

(define-public (join-event (event-id uint))
  (let ((event-data (unwrap! (map-get? events event-id) ERR_NOT_FOUND)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status event-data) "approved") ERR_EVENT_NOT_ACTIVE)
    
    (map-set event-participants {event-id: event-id, participant: tx-sender} {
      joined-at: stacks-block-height,
      contribution: u0
    })
    
    (ok true)
  )
)

(define-public (add-expense (event-id uint) (expense-id uint) (description (string-ascii 200)) (amount uint) (recipient principal))
  (let ((event-data (unwrap! (map-get? events event-id) ERR_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get creator event-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (map-set event-expenses {event-id: event-id, expense-id: expense-id} {
      description: description,
      amount: amount,
      recipient: recipient,
      approved: false,
      created-at: stacks-block-height
    })
    
    (ok true)
  )
)

(define-public (approve-expense (event-id uint) (expense-id uint))
  (let (
    (expense (unwrap! (map-get? event-expenses {event-id: event-id, expense-id: expense-id}) ERR_NOT_FOUND))
    (event-data (unwrap! (map-get? events event-id) ERR_NOT_FOUND))
  )
    (asserts! (or (is-eq tx-sender (get creator event-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (not (get approved expense)) ERR_ALREADY_EXISTS)
    
    (map-set event-expenses {event-id: event-id, expense-id: expense-id} 
      (merge expense {approved: true}))
    
    (ok true)
  )
)

(define-public (contribute-to-treasury (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    
    (match (map-get? member-reputation tx-sender)
      current-rep (map-set member-reputation tx-sender (+ current-rep u1))
      (map-set member-reputation tx-sender u1)
    )
    
    (ok true)
  )
)

(define-public (update-member-reputation (member principal) (new-reputation uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-member member) ERR_NOT_FOUND)
    (map-set member-reputation member new-reputation)
    (ok true)
  )
)

(define-public (complete-event (event-id uint))
  (let ((event-data (unwrap! (map-get? events event-id) ERR_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get creator event-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status event-data) "approved") ERR_EVENT_NOT_ACTIVE)
    
    (map-set events event-id (merge event-data {status: "completed"}))
    
    (let ((creator-reputation (default-to u1 (map-get? member-reputation (get creator event-data)))))
      (map-set member-reputation (get creator event-data) (+ creator-reputation u2))
    )
    
    (ok true)
  )
)

(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-member-reputation (member principal))
  (map-get? member-reputation member)
)

(define-read-only (is-member (address principal))
  (default-to false (map-get? members address))
)

(define-read-only (get-treasury-balance)
  (var-get treasury-balance)
)

(define-read-only (get-expense (event-id uint) (expense-id uint))
  (map-get? event-expenses {event-id: event-id, expense-id: expense-id})
)

(define-read-only (get-participant-info (event-id uint) (participant principal))
  (map-get? event-participants {event-id: event-id, participant: participant})
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)

(define-public (create-resource (name (string-ascii 100)) (description (string-ascii 300)) (category (string-ascii 50)) (daily-rate uint) (location (string-ascii 200)) (deposit-required uint))
  (let ((resource-id (var-get next-resource-id)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> daily-rate u0) ERR_INVALID_AMOUNT)
    
    (map-set resources resource-id {
      owner: tx-sender,
      name: name,
      description: description,
      category: category,
      daily-rate: daily-rate,
      available: true,
      location: location,
      deposit-required: deposit-required,
      total-ratings: u0,
      rating-count: u0,
      created-at: stacks-block-height
    })
    
    (var-set next-resource-id (+ resource-id u1))
    (ok resource-id)
  )
)

(define-public (update-resource-availability (resource-id uint) (available bool))
  (let ((resource-data (unwrap! (map-get? resources resource-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner resource-data)) ERR_UNAUTHORIZED)
    
    (map-set resources resource-id (merge resource-data {available: available}))
    (ok true)
  )
)

(define-public (reserve-resource (resource-id uint) (start-date uint) (end-date uint))
  (let (
    (resource-data (unwrap! (map-get? resources resource-id) ERR_NOT_FOUND))
    (reservation-id (var-get next-reservation-id))
    (duration (- end-date start-date))
    (total-cost (* duration (get daily-rate resource-data)))
    (deposit-required (get deposit-required resource-data))
  )
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get available resource-data) ERR_RESOURCE_NOT_AVAILABLE)
    (asserts! (> end-date start-date) ERR_INVALID_AMOUNT)
    (asserts! (> start-date stacks-block-height) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tx-sender (get owner resource-data))) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? (+ total-cost deposit-required) tx-sender (get owner resource-data)))
    
    (map-set resource-reservations reservation-id {
      resource-id: resource-id,
      borrower: tx-sender,
      start-date: start-date,
      end-date: end-date,
      total-cost: total-cost,
      deposit-paid: deposit-required,
      status: "active",
      created-at: stacks-block-height
    })
    
    (map-set resources resource-id (merge resource-data {available: false}))
    
    (var-set next-reservation-id (+ reservation-id u1))
    (ok reservation-id)
  )
)

(define-public (return-resource (reservation-id uint))
  (let (
    (reservation (unwrap! (map-get? resource-reservations reservation-id) ERR_NOT_FOUND))
    (resource-data (unwrap! (map-get? resources (get resource-id reservation)) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get borrower reservation)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status reservation) "active") ERR_NOT_BORROWED)
    
    (map-set resource-reservations reservation-id (merge reservation {status: "completed"}))
    (map-set resources (get resource-id reservation) (merge resource-data {available: true}))
    
    (let ((deposit-return (get deposit-paid reservation)))
      (if (> deposit-return u0)
        (try! (stx-transfer? deposit-return (get owner resource-data) tx-sender))
        true
      )
    )
    
    (ok true)
  )
)

(define-public (rate-resource (resource-id uint) (rating uint) (comment (string-ascii 200)))
  (let (
    (resource-data (unwrap! (map-get? resources resource-id) ERR_NOT_FOUND))
    (existing-rating (map-get? resource-ratings {resource-id: resource-id, rater: tx-sender}))
  )
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= rating u5) ERR_INVALID_RATING)
    (asserts! (> rating u0) ERR_INVALID_RATING)
    (asserts! (is-none existing-rating) ERR_ALREADY_VOTED)
    
    (map-set resource-ratings {resource-id: resource-id, rater: tx-sender} {
      rating: rating,
      comment: comment,
      created-at: stacks-block-height
    })
    
    (let (
      (new-total-ratings (+ (get total-ratings resource-data) rating))
      (new-rating-count (+ (get rating-count resource-data) u1))
    )
      (map-set resources resource-id (merge resource-data {
        total-ratings: new-total-ratings,
        rating-count: new-rating-count
      }))
    )
    
    (ok true)
  )
)

(define-public (cancel-reservation (reservation-id uint))
  (let (
    (reservation (unwrap! (map-get? resource-reservations reservation-id) ERR_NOT_FOUND))
    (resource-data (unwrap! (map-get? resources (get resource-id reservation)) ERR_NOT_FOUND))
  )
    (asserts! (or (is-eq tx-sender (get borrower reservation)) (is-eq tx-sender (get owner resource-data))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status reservation) "active") ERR_NOT_BORROWED)
    (asserts! (> (get start-date reservation) stacks-block-height) ERR_VOTING_CLOSED)
    
    (map-set resource-reservations reservation-id (merge reservation {status: "cancelled"}))
    (map-set resources (get resource-id reservation) (merge resource-data {available: true}))
    
    (let ((refund-amount (+ (get total-cost reservation) (get deposit-paid reservation))))
      (try! (stx-transfer? refund-amount (get owner resource-data) (get borrower reservation)))
    )
    
    (ok true)
  )
)

(define-read-only (get-resource (resource-id uint))
  (map-get? resources resource-id)
)

(define-read-only (get-reservation (reservation-id uint))
  (map-get? resource-reservations reservation-id)
)

(define-read-only (get-resource-rating (resource-id uint) (rater principal))
  (map-get? resource-ratings {resource-id: resource-id, rater: rater})
)

(define-read-only (get-resource-average-rating (resource-id uint))
  (let ((resource-data (unwrap! (map-get? resources resource-id) ERR_NOT_FOUND)))
    (if (> (get rating-count resource-data) u0)
      (ok (/ (get total-ratings resource-data) (get rating-count resource-data)))
      (ok u0)
    )
  )
)

(define-read-only (get-next-resource-id)
  (var-get next-resource-id)
)

(define-read-only (get-next-reservation-id)
  (var-get next-reservation-id)
)
