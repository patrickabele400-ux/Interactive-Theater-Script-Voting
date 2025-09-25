(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SCRIPT-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-VOTING-CLOSED (err u103))
(define-constant ERR-VOTING-NOT-STARTED (err u104))
(define-constant ERR-INVALID-SCRIPT-ID (err u105))
(define-constant ERR-SCRIPT-EXISTS (err u106))
(define-constant ERR-INVALID-TITLE (err u107))
(define-constant ERR-INVALID-DESCRIPTION (err u108))
(define-constant ERR-VOTING-PERIOD-TOO-SHORT (err u109))
(define-constant ERR-CANNOT-VOTE-OWN-SCRIPT (err u110))

(define-constant MIN-VOTING-PERIOD u144)
(define-constant MAX-TITLE-LENGTH u100)
(define-constant MAX-DESCRIPTION-LENGTH u500)
(define-constant VOTING-FEE u1000000)

(define-data-var contract-owner principal tx-sender)
(define-data-var next-script-id uint u1)
(define-data-var total-scripts uint u0)

(define-map Scripts
    { script-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        author: principal,
        votes: uint,
        created-at: uint,
        voting-ends-at: uint,
        is-active: bool
    }
)

(define-map Votes
    { voter: principal, script-id: uint }
    { voted-at: uint }
)

(define-map UserVoteCounts
    { user: principal, script-id: uint }
    { count: uint }
)

(define-map ScriptVoters
    { script-id: uint, voter: principal }
    { timestamp: uint }
)

(define-public (submit-script (title (string-ascii 100)) (description (string-ascii 500)) (voting-duration uint))
    (let
        (
            (script-id (var-get next-script-id))
            (current-block burn-block-height)
            (voting-end-block (+ current-block voting-duration))
        )
        (asserts! (> (len title) u0) ERR-INVALID-TITLE)
        (asserts! (<= (len title) MAX-TITLE-LENGTH) ERR-INVALID-TITLE)
        (asserts! (> (len description) u0) ERR-INVALID-DESCRIPTION)
        (asserts! (<= (len description) MAX-DESCRIPTION-LENGTH) ERR-INVALID-DESCRIPTION)
        (asserts! (>= voting-duration MIN-VOTING-PERIOD) ERR-VOTING-PERIOD-TOO-SHORT)
        
        (try! (stx-transfer? VOTING-FEE tx-sender (var-get contract-owner)))
        
        (map-set Scripts
            { script-id: script-id }
            {
                title: title,
                description: description,
                author: tx-sender,
                votes: u0,
                created-at: current-block,
                voting-ends-at: voting-end-block,
                is-active: true
            }
        )
        
        (var-set next-script-id (+ script-id u1))
        (var-set total-scripts (+ (var-get total-scripts) u1))
        
        (print { event: "script-submitted", script-id: script-id, author: tx-sender, title: title })
        (ok script-id)
    )
)

(define-public (vote-for-script (script-id uint))
    (let
        (
            (script (unwrap! (map-get? Scripts { script-id: script-id }) ERR-SCRIPT-NOT-FOUND))
            (current-block burn-block-height)
            (voter-key { voter: tx-sender, script-id: script-id })
        )
        (asserts! (get is-active script) ERR-VOTING-CLOSED)
        (asserts! (>= current-block (get created-at script)) ERR-VOTING-NOT-STARTED)
        (asserts! (< current-block (get voting-ends-at script)) ERR-VOTING-CLOSED)
        (asserts! (not (is-eq tx-sender (get author script))) ERR-CANNOT-VOTE-OWN-SCRIPT)
        (asserts! (is-none (map-get? Votes voter-key)) ERR-ALREADY-VOTED)
        
        (map-set Votes voter-key { voted-at: current-block })
        
        (map-set ScriptVoters
            { script-id: script-id, voter: tx-sender }
            { timestamp: current-block }
        )
        
        (map-set Scripts
            { script-id: script-id }
            (merge script { votes: (+ (get votes script) u1) })
        )
        
        (print { event: "vote-cast", script-id: script-id, voter: tx-sender, total-votes: (+ (get votes script) u1) })
        (ok true)
    )
)

(define-public (close-voting (script-id uint))
    (let
        (
            (script (unwrap! (map-get? Scripts { script-id: script-id }) ERR-SCRIPT-NOT-FOUND))
            (current-block burn-block-height)
        )
        (asserts! (or (is-eq tx-sender (get author script)) (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
        (asserts! (>= current-block (get voting-ends-at script)) ERR-VOTING-CLOSED)
        (asserts! (get is-active script) ERR-VOTING-CLOSED)
        
        (map-set Scripts
            { script-id: script-id }
            (merge script { is-active: false })
        )
        
        (print { event: "voting-closed", script-id: script-id, final-votes: (get votes script) })
        (ok true)
    )
)

(define-public (extend-voting (script-id uint) (additional-blocks uint))
    (let
        (
            (script (unwrap! (map-get? Scripts { script-id: script-id }) ERR-SCRIPT-NOT-FOUND))
            (current-block burn-block-height)
        )
        (asserts! (is-eq tx-sender (get author script)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active script) ERR-VOTING-CLOSED)
        (asserts! (< current-block (get voting-ends-at script)) ERR-VOTING-CLOSED)
        
        (map-set Scripts
            { script-id: script-id }
            (merge script { voting-ends-at: (+ (get voting-ends-at script) additional-blocks) })
        )
        
        (print { event: "voting-extended", script-id: script-id, new-end-block: (+ (get voting-ends-at script) additional-blocks) })
        (ok true)
    )
)

(define-public (update-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (print { event: "owner-updated", old-owner: tx-sender, new-owner: new-owner })
        (ok true)
    )
)

(define-read-only (get-script-details (script-id uint))
    (map-get? Scripts { script-id: script-id })
)

(define-read-only (get-vote-status (voter principal) (script-id uint))
    (is-some (map-get? Votes { voter: voter, script-id: script-id }))
)

(define-read-only (get-current-block)
    burn-block-height
)

(define-read-only (get-voting-status (script-id uint))
    (match (map-get? Scripts { script-id: script-id })
        script
        (let
            (
                (current-block burn-block-height)
                (is-active (get is-active script))
                (voting-ended (>= current-block (get voting-ends-at script)))
            )
            (ok {
                is-active: is-active,
                voting-ended: voting-ended,
                blocks-remaining: (if voting-ended u0 (- (get voting-ends-at script) current-block)),
                total-votes: (get votes script)
            })
        )
        ERR-SCRIPT-NOT-FOUND
    )
)

(define-read-only (get-top-scripts (limit uint))
    (ok (var-get total-scripts))
)

(define-read-only (get-script-by-author (author principal))
    (ok author)
)

(define-read-only (has-user-voted (user principal) (script-id uint))
    (is-some (map-get? Votes { voter: user, script-id: script-id }))
)

(define-read-only (get-contract-stats)
    (ok {
        total-scripts: (var-get total-scripts),
        next-script-id: (var-get next-script-id),
        contract-owner: (var-get contract-owner),
        current-block: burn-block-height,
        voting-fee: VOTING-FEE,
        min-voting-period: MIN-VOTING-PERIOD
    })
)

(define-read-only (get-script-vote-count (script-id uint))
    (match (map-get? Scripts { script-id: script-id })
        script (ok (get votes script))
        ERR-SCRIPT-NOT-FOUND
    )
)

(define-read-only (is-voting-active (script-id uint))
    (match (map-get? Scripts { script-id: script-id })
        script
        (let
            (
                (current-block burn-block-height)
            )
            (ok (and
                (get is-active script)
                (< current-block (get voting-ends-at script))
            ))
        )
        ERR-SCRIPT-NOT-FOUND
    )
)

