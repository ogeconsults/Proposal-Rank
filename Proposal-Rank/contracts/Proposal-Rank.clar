;; ProposalRank - Governance platform with reputation system
;; Track proposal success rates and maintain on-chain reputation

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u102))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u103))
(define-constant ERR_VOTING_ENDED (err u104))
(define-constant ERR_VOTING_NOT_ENDED (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var voting-period uint u1440) ;; blocks (~10 days)

;; Proposal States
(define-constant PROPOSAL_PENDING u0)
(define-constant PROPOSAL_ACTIVE u1)
(define-constant PROPOSAL_PASSED u2)
(define-constant PROPOSAL_FAILED u3)
(define-constant PROPOSAL_EXECUTED u4)

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    status: uint,
    executed: bool
  }
)

(define-map user-reputation
  { user: principal }
  {
    total-proposals: uint,
    successful-proposals: uint,
    reputation-score: uint,
    total-votes-cast: uint
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-map user-voting-power
  { user: principal }
  { power: uint }
)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
  (default-to 
    { total-proposals: u0, successful-proposals: u0, reputation-score: u0, total-votes-cast: u0 }
    (map-get? user-reputation { user: user })
  )
)

;; Calculate reputation score (success rate * 100 + bonus for activity)
(define-read-only (calculate-reputation (user principal))
  (let ((rep-data (get-user-reputation user)))
    (let ((total-proposals (get total-proposals rep-data))
          (successful-proposals (get successful-proposals rep-data))
          (total-votes (get total-votes-cast rep-data)))
      (if (is-eq total-proposals u0)
        u0
        (+ (* (/ (* successful-proposals u100) total-proposals) u1)
           (/ total-votes u10)) ;; bonus points for voting activity
      )
    )
  )
)

;; Get voting power (based on reputation)
(define-read-only (get-voting-power (user principal))
  (let ((base-power u1)
        (reputation (calculate-reputation user)))
    (+ base-power (/ reputation u10))
  )
)

;; Check if proposal voting has ended
(define-read-only (is-voting-ended (proposal-id uint))
  (match (get-proposal proposal-id)
    proposal-data (>= burn-block-height (get end-block proposal-data))
    false
  )
)

;; Get current proposal counter
(define-read-only (get-proposal-counter)
  (var-get proposal-counter)
)

;; Check if user has voted on proposal
(define-read-only (has-user-voted (proposal-id uint) (user principal))
  (is-some (map-get? proposal-votes { proposal-id: proposal-id, voter: user }))
)

;; Public functions

;; Submit a new proposal
(define-public (submit-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let ((proposal-id (+ (var-get proposal-counter) u1))
        (start-block burn-block-height)
        (end-block (+ burn-block-height (var-get voting-period))))
    
    ;; Create proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        votes-for: u0,
        votes-against: u0,
        start-block: start-block,
        end-block: end-block,
        status: PROPOSAL_ACTIVE,
        executed: false
      }
    )
    
    ;; Update proposal counter
    (var-set proposal-counter proposal-id)
    
    ;; Update user reputation - increment total proposals
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep { total-proposals: (+ (get total-proposals current-rep) u1) })
      )
    )
    
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let ((proposal-data (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (voter-power (get-voting-power tx-sender)))
    
    ;; Check if voting period is still active
    (asserts! (not (is-voting-ended proposal-id)) ERR_VOTING_ENDED)
    
    ;; Check if user already voted
    (asserts! (not (has-user-voted proposal-id tx-sender)) ERR_ALREADY_VOTED)
    
    ;; Record the vote
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for, voting-power: voter-power }
    )
    
    ;; Update proposal vote counts
    (if vote-for
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal-data { votes-for: (+ (get votes-for proposal-data) voter-power) })
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal-data { votes-against: (+ (get votes-against proposal-data) voter-power) })
      )
    )
    
    ;; Update user voting activity
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep { total-votes-cast: (+ (get total-votes-cast current-rep) u1) })
      )
    )
    
    (ok true)
  )
)

;; Finalize proposal (determine if passed or failed)
(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    
    ;; Check if voting has ended
    (asserts! (is-voting-ended proposal-id) ERR_VOTING_NOT_ENDED)
    
    ;; Check if proposal is still active
    (asserts! (is-eq (get status proposal-data) PROPOSAL_ACTIVE) ERR_PROPOSAL_ALREADY_EXECUTED)
    
    (let ((votes-for (get votes-for proposal-data))
          (votes-against (get votes-against proposal-data))
          (proposer (get proposer proposal-data)))
      
      ;; Determine if proposal passed (simple majority)
      (let ((passed (> votes-for votes-against))
            (new-status (if passed PROPOSAL_PASSED PROPOSAL_FAILED)))
        
        ;; Update proposal status
        (map-set proposals
          { proposal-id: proposal-id }
          (merge proposal-data { status: new-status })
        )
        
        ;; Update proposer reputation if proposal passed
        (if passed
          (let ((current-rep (get-user-reputation proposer)))
            (map-set user-reputation
              { user: proposer }
              (merge current-rep 
                { successful-proposals: (+ (get successful-proposals current-rep) u1) }
              )
            )
          )
          true
        )
        
        (ok passed)
      )
    )
  )
)

;; Execute a passed proposal (placeholder - actual execution logic would depend on proposal type)
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal-data (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    
    ;; Check if proposal passed
    (asserts! (is-eq (get status proposal-data) PROPOSAL_PASSED) ERR_UNAUTHORIZED)
    
    ;; Check if already executed
    (asserts! (not (get executed proposal-data)) ERR_PROPOSAL_ALREADY_EXECUTED)
    
    ;; Mark as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal-data { executed: true, status: PROPOSAL_EXECUTED })
    )
    
    ;; Execution logic would go here depending on proposal type
    ;; For now, just mark as executed
    
    (ok true)
  )
)

;; Admin function to update voting period
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period new-period)
    (ok true)
  )
)

;; Initialize/bootstrap voting power for early users (admin only)
(define-public (set-initial-voting-power (user principal) (power uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set user-voting-power { user: user } { power: power })
    (ok true)
  )
)