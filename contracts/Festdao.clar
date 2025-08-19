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
(define-constant ERR_SKILL_NOT_FOUND (err u411))
(define-constant ERR_TASK_NOT_FOUND (err u412))
(define-constant ERR_ALREADY_APPLIED (err u413))
(define-constant ERR_TASK_NOT_OPEN (err u414))
(define-constant ERR_INVALID_COMPLETION_STATUS (err u415))
(define-constant ERR_NOT_TASK_CREATOR (err u416))
(define-constant ERR_NOT_ASSIGNED_PROVIDER (err u417))
(define-constant ERR_TASK_ALREADY_COMPLETED (err u418))
(define-constant ERR_INSUFFICIENT_SKILL_REPUTATION (err u419))

(define-data-var next-event-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-resource-id uint u1)
(define-data-var next-reservation-id uint u1)
(define-data-var next-skill-id uint u1)
(define-data-var next-task-id uint u1)
(define-data-var next-application-id uint u1)
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

(define-map skills
  uint
  {
    provider: principal,
    category: (string-ascii 50),
    title: (string-ascii 100),
    description: (string-ascii 300),
    hourly-rate: uint,
    skill-level: uint,
    total-rating: uint,
    rating-count: uint,
    completed-tasks: uint,
    available: bool,
    portfolio-link: (string-ascii 200),
    created-at: uint
  }
)

(define-map tasks
  uint
  {
    creator: principal,
    event-id: (optional uint),
    category: (string-ascii 50),
    title: (string-ascii 100),
    description: (string-ascii 500),
    budget: uint,
    duration-hours: uint,
    skill-level-required: uint,
    deadline: uint,
    status: (string-ascii 20),
    assigned-provider: (optional principal),
    completion-rating: uint,
    created-at: uint
  }
)

(define-map task-applications
  uint
  {
    task-id: uint,
    applicant: principal,
    proposed-rate: uint,
    message: (string-ascii 300),
    skill-id: uint,
    status: (string-ascii 20),
    applied-at: uint
  }
)

(define-map skill-ratings
  {skill-id: uint, rater: principal}
  {rating: uint, comment: (string-ascii 200), task-id: uint, created-at: uint}
)

(define-map member-skill-reputation
  {member: principal, category: (string-ascii 50)}
  {reputation-score: uint, tasks-completed: uint, avg-rating: uint}
)

(define-map task-applicant-check
  {task-id: uint, applicant: principal}
  bool
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

(define-public (create-skill (category (string-ascii 50)) (title (string-ascii 100)) (description (string-ascii 300)) (hourly-rate uint) (skill-level uint) (portfolio-link (string-ascii 200)))
  (let ((skill-id (var-get next-skill-id)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> hourly-rate u0) ERR_INVALID_AMOUNT)
    (asserts! (<= skill-level u5) ERR_INVALID_RATING)
    (asserts! (> skill-level u0) ERR_INVALID_RATING)
    
    (map-set skills skill-id {
      provider: tx-sender,
      category: category,
      title: title,
      description: description,
      hourly-rate: hourly-rate,
      skill-level: skill-level,
      total-rating: u0,
      rating-count: u0,
      completed-tasks: u0,
      available: true,
      portfolio-link: portfolio-link,
      created-at: stacks-block-height
    })
    
    (var-set next-skill-id (+ skill-id u1))
    (ok skill-id)
  )
)

(define-public (update-skill-availability (skill-id uint) (available bool))
  (let ((skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get provider skill-data)) ERR_UNAUTHORIZED)
    
    (map-set skills skill-id (merge skill-data {available: available}))
    (ok true)
  )
)

(define-public (create-task (event-id (optional uint)) (category (string-ascii 50)) (title (string-ascii 100)) (description (string-ascii 500)) (budget uint) (duration-hours uint) (skill-level-required uint) (deadline uint))
  (let ((task-id (var-get next-task-id)))
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> budget u0) ERR_INVALID_AMOUNT)
    (asserts! (> duration-hours u0) ERR_INVALID_AMOUNT)
    (asserts! (<= skill-level-required u5) ERR_INVALID_RATING)
    (asserts! (> skill-level-required u0) ERR_INVALID_RATING)
    (asserts! (> deadline stacks-block-height) ERR_INVALID_AMOUNT)
    
    (match event-id
      some-event-id (asserts! (is-some (map-get? events some-event-id)) ERR_NOT_FOUND)
      true
    )
    
    (map-set tasks task-id {
      creator: tx-sender,
      event-id: event-id,
      category: category,
      title: title,
      description: description,
      budget: budget,
      duration-hours: duration-hours,
      skill-level-required: skill-level-required,
      deadline: deadline,
      status: "open",
      assigned-provider: none,
      completion-rating: u0,
      created-at: stacks-block-height
    })
    
    (var-set next-task-id (+ task-id u1))
    (ok task-id)
  )
)

(define-public (apply-for-task (task-id uint) (skill-id uint) (proposed-rate uint) (message (string-ascii 300)))
  (let (
    (task-data (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
    (skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND))
    (application-id (var-get next-application-id))
  )
    (asserts! (is-member tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status task-data) "open") ERR_TASK_NOT_OPEN)
    (asserts! (is-eq tx-sender (get provider skill-data)) ERR_UNAUTHORIZED)
    (asserts! (get available skill-data) ERR_RESOURCE_NOT_AVAILABLE)
    (asserts! (>= (get skill-level skill-data) (get skill-level-required task-data)) ERR_INSUFFICIENT_SKILL_REPUTATION)
    (asserts! (is-eq (get category skill-data) (get category task-data)) ERR_INVALID_AMOUNT)
    (asserts! (> proposed-rate u0) ERR_INVALID_AMOUNT)
    
    (asserts! (is-none (map-get? task-applicant-check {task-id: task-id, applicant: tx-sender})) ERR_ALREADY_APPLIED)
    
    (map-set task-applicant-check {task-id: task-id, applicant: tx-sender} true)
    
    (map-set task-applications application-id {
      task-id: task-id,
      applicant: tx-sender,
      proposed-rate: proposed-rate,
      message: message,
      skill-id: skill-id,
      status: "pending",
      applied-at: stacks-block-height
    })
    
    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

(define-public (assign-task (task-id uint) (application-id uint))
  (let (
    (task-data (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
    (application (unwrap! (map-get? task-applications application-id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator task-data)) ERR_NOT_TASK_CREATOR)
    (asserts! (is-eq (get status task-data) "open") ERR_TASK_NOT_OPEN)
    (asserts! (is-eq (get task-id application) task-id) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (get status application) "pending") ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? (get budget task-data) tx-sender (as-contract tx-sender)))
    
    (map-set tasks task-id (merge task-data {
      status: "assigned",
      assigned-provider: (some (get applicant application))
    }))
    
    (map-set task-applications application-id (merge application {status: "accepted"}))
    
    (ok true)
  )
)

(define-public (complete-task (task-id uint))
  (let ((task-data (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
    (asserts! (is-eq (some tx-sender) (get assigned-provider task-data)) ERR_NOT_ASSIGNED_PROVIDER)
    (asserts! (is-eq (get status task-data) "assigned") ERR_TASK_NOT_OPEN)
    
    (map-set tasks task-id (merge task-data {status: "pending-review"}))
    (ok true)
  )
)

(define-public (approve-task-completion (task-id uint) (rating uint))
  (let ((task-data (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator task-data)) ERR_NOT_TASK_CREATOR)
    (asserts! (is-eq (get status task-data) "pending-review") ERR_INVALID_COMPLETION_STATUS)
    (asserts! (<= rating u5) ERR_INVALID_RATING)
    (asserts! (> rating u0) ERR_INVALID_RATING)
    
    (let ((provider (unwrap! (get assigned-provider task-data) ERR_NOT_ASSIGNED_PROVIDER)))
      (try! (as-contract (stx-transfer? (get budget task-data) tx-sender provider)))
      
      (map-set tasks task-id (merge task-data {
        status: "completed",
        completion-rating: rating
      }))
      
      (let ((provider-reputation (default-to u1 (map-get? member-reputation provider))))
        (map-set member-reputation provider (+ provider-reputation u1))
      )
      
      (let ((category-rep (default-to {reputation-score: u0, tasks-completed: u0, avg-rating: u0} 
                                    (map-get? member-skill-reputation {member: provider, category: (get category task-data)}))))
        (let (
          (new-tasks-completed (+ (get tasks-completed category-rep) u1))
          (new-total-rating (+ (* (get avg-rating category-rep) (get tasks-completed category-rep)) rating))
          (new-avg-rating (/ new-total-rating new-tasks-completed))
        )
          (map-set member-skill-reputation {member: provider, category: (get category task-data)} {
            reputation-score: (+ (get reputation-score category-rep) rating),
            tasks-completed: new-tasks-completed,
            avg-rating: new-avg-rating
          })
        )
      )
      
      (ok true)
    )
  )
)

(define-public (rate-skill-performance (skill-id uint) (task-id uint) (rating uint) (comment (string-ascii 200)))
  (let (
    (skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND))
    (task-data (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator task-data)) ERR_NOT_TASK_CREATOR)
    (asserts! (is-eq (get status task-data) "completed") ERR_TASK_NOT_OPEN)
    (asserts! (is-eq (some (get provider skill-data)) (get assigned-provider task-data)) ERR_UNAUTHORIZED)
    (asserts! (<= rating u5) ERR_INVALID_RATING)
    (asserts! (> rating u0) ERR_INVALID_RATING)
    (asserts! (is-none (map-get? skill-ratings {skill-id: skill-id, rater: tx-sender})) ERR_ALREADY_VOTED)
    
    (map-set skill-ratings {skill-id: skill-id, rater: tx-sender} {
      rating: rating,
      comment: comment,
      task-id: task-id,
      created-at: stacks-block-height
    })
    
    (let (
      (new-total-rating (+ (get total-rating skill-data) rating))
      (new-rating-count (+ (get rating-count skill-data) u1))
      (new-completed-tasks (+ (get completed-tasks skill-data) u1))
    )
      (map-set skills skill-id (merge skill-data {
        total-rating: new-total-rating,
        rating-count: new-rating-count,
        completed-tasks: new-completed-tasks
      }))
    )
    
    (ok true)
  )
)

(define-public (cancel-task (task-id uint))
  (let ((task-data (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator task-data)) ERR_NOT_TASK_CREATOR)
    (asserts! (not (is-eq (get status task-data) "completed")) ERR_TASK_ALREADY_COMPLETED)
    
    (if (is-eq (get status task-data) "assigned")
      (try! (as-contract (stx-transfer? (get budget task-data) tx-sender (get creator task-data))))
      true
    )
    
    (map-set tasks task-id (merge task-data {status: "cancelled"}))
    (ok true)
  )
)

(define-read-only (get-skill (skill-id uint))
  (map-get? skills skill-id)
)

(define-read-only (get-task (task-id uint))
  (map-get? tasks task-id)
)

(define-read-only (get-task-application (application-id uint))
  (map-get? task-applications application-id)
)

(define-read-only (get-skill-rating (skill-id uint) (rater principal))
  (map-get? skill-ratings {skill-id: skill-id, rater: rater})
)

(define-read-only (get-skill-average-rating (skill-id uint))
  (let ((skill-data (unwrap! (map-get? skills skill-id) ERR_SKILL_NOT_FOUND)))
    (if (> (get rating-count skill-data) u0)
      (ok (/ (get total-rating skill-data) (get rating-count skill-data)))
      (ok u0)
    )
  )
)

(define-read-only (get-member-skill-reputation (member principal) (category (string-ascii 50)))
  (map-get? member-skill-reputation {member: member, category: category})
)

(define-read-only (get-next-skill-id)
  (var-get next-skill-id)
)

(define-read-only (get-next-task-id)
  (var-get next-task-id)
)

(define-read-only (get-next-application-id)
  (var-get next-application-id)
)


