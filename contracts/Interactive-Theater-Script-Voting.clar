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
(define-constant ERR-INVALID-RATING (err u111))
(define-constant ERR-COMMENT-TOO-LONG (err u112))
(define-constant ERR-ALREADY-RATED (err u113))
(define-constant ERR-NOT-BOOKMARKED (err u114))
(define-constant ERR-ALREADY-BOOKMARKED (err u115))

(define-constant MIN-VOTING-PERIOD u144)
(define-constant MAX-TITLE-LENGTH u100)
(define-constant MAX-DESCRIPTION-LENGTH u500)
(define-constant VOTING-FEE u1000000)
(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)
(define-constant MAX-COMMENT-LENGTH u200)

(define-data-var contract-owner principal tx-sender)
(define-data-var next-script-id uint u1)
(define-data-var total-scripts uint u0)
(define-data-var voting-fee-setting uint VOTING-FEE)
(define-data-var min-voting-period-setting uint MIN-VOTING-PERIOD)

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

(define-map ScriptRatings
    { script-id: uint, rater: principal }
    {
        rating: uint,
        comment: (string-ascii 200),
        rated-at: uint
    }
)

(define-map ScriptRatingStats
    { script-id: uint }
    {
        total-ratings: uint,
        rating-sum: uint,
        average-rating: uint
    }
)

(define-map UserBookmarks
    { user: principal, script-id: uint }
    { bookmarked-at: uint }
)

(define-map UserBookmarkCounts
    { user: principal }
    { count: uint }
)

(define-map ScriptBookmarkCounts
    { script-id: uint }
    { count: uint }
)

(define-public (submit-script (title (string-ascii 100)) (description (string-ascii 500)) (voting-duration uint))
    (let
        (
            (script-id (var-get next-script-id))
            (current-block burn-block-height)
            (current-voting-fee (var-get voting-fee-setting))
            (current-min-voting-period (var-get min-voting-period-setting))
            (voting-end-block (+ current-block voting-duration))
        )
        (asserts! (> (len title) u0) ERR-INVALID-TITLE)
        (asserts! (<= (len title) MAX-TITLE-LENGTH) ERR-INVALID-TITLE)
        (asserts! (> (len description) u0) ERR-INVALID-DESCRIPTION)
        (asserts! (<= (len description) MAX-DESCRIPTION-LENGTH) ERR-INVALID-DESCRIPTION)
        (asserts! (>= voting-duration current-min-voting-period) ERR-VOTING-PERIOD-TOO-SHORT)
        
        (try! (stx-transfer? current-voting-fee tx-sender (var-get contract-owner)))
        
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

(define-public (rate-and-comment (script-id uint) (rating uint) (comment (string-ascii 200)))
    (let
        (
            (script (unwrap! (map-get? Scripts { script-id: script-id }) ERR-SCRIPT-NOT-FOUND))
            (current-block burn-block-height)
            (rater-key { script-id: script-id, rater: tx-sender })
            (stats-key { script-id: script-id })
            (existing-stats (default-to { total-ratings: u0, rating-sum: u0, average-rating: u0 } 
                           (map-get? ScriptRatingStats stats-key)))
        )
        (asserts! (>= rating MIN-RATING) ERR-INVALID-RATING)
        (asserts! (<= rating MAX-RATING) ERR-INVALID-RATING)
        (asserts! (<= (len comment) MAX-COMMENT-LENGTH) ERR-COMMENT-TOO-LONG)
        (asserts! (not (is-eq tx-sender (get author script))) ERR-CANNOT-VOTE-OWN-SCRIPT)
        (asserts! (is-none (map-get? ScriptRatings rater-key)) ERR-ALREADY-RATED)
        
        (map-set ScriptRatings rater-key
            {
                rating: rating,
                comment: comment,
                rated-at: current-block
            }
        )
        
        (let
            (
                (new-total (+ (get total-ratings existing-stats) u1))
                (new-sum (+ (get rating-sum existing-stats) rating))
                (new-average (/ new-sum new-total))
            )
            (map-set ScriptRatingStats stats-key
                {
                    total-ratings: new-total,
                    rating-sum: new-sum,
                    average-rating: new-average
                }
            )
        )
        
        (print { event: "script-rated", script-id: script-id, rater: tx-sender, rating: rating })
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

(define-public (update-voting-config (new-fee uint) (new-min-period uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (>= new-min-period MIN-VOTING-PERIOD) ERR-VOTING-PERIOD-TOO-SHORT)
        (var-set voting-fee-setting new-fee)
        (var-set min-voting-period-setting new-min-period)
        (print { event: "voting-config-updated", voting-fee: new-fee, min-voting-period: new-min-period })
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
        voting-fee: (var-get voting-fee-setting),
        min-voting-period: (var-get min-voting-period-setting)
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

(define-read-only (get-script-rating (script-id uint) (rater principal))
    (map-get? ScriptRatings { script-id: script-id, rater: rater })
)

(define-read-only (get-script-rating-stats (script-id uint))
    (map-get? ScriptRatingStats { script-id: script-id })
)

(define-read-only (has-user-rated (user principal) (script-id uint))
    (is-some (map-get? ScriptRatings { script-id: script-id, rater: user }))
)

(define-read-only (get-script-average-rating (script-id uint))
    (match (map-get? ScriptRatingStats { script-id: script-id })
        stats (ok (get average-rating stats))
        (ok u0)
    )
)

(define-public (bookmark-script (script-id uint))
    (let
        (
            (script (unwrap! (map-get? Scripts { script-id: script-id }) ERR-SCRIPT-NOT-FOUND))
            (current-block burn-block-height)
            (bookmark-key { user: tx-sender, script-id: script-id })
            (user-count-key { user: tx-sender })
            (script-count-key { script-id: script-id })
            (existing-user-count (default-to { count: u0 } (map-get? UserBookmarkCounts user-count-key)))
            (existing-script-count (default-to { count: u0 } (map-get? ScriptBookmarkCounts script-count-key)))
        )
        (asserts! (is-none (map-get? UserBookmarks bookmark-key)) ERR-ALREADY-BOOKMARKED)
        
        (map-set UserBookmarks bookmark-key { bookmarked-at: current-block })
        (map-set UserBookmarkCounts user-count-key { count: (+ (get count existing-user-count) u1) })
        (map-set ScriptBookmarkCounts script-count-key { count: (+ (get count existing-script-count) u1) })
        
        (print { event: "script-bookmarked", script-id: script-id, user: tx-sender })
        (ok true)
    )
)

(define-public (remove-bookmark (script-id uint))
    (let
        (
            (bookmark-key { user: tx-sender, script-id: script-id })
            (user-count-key { user: tx-sender })
            (script-count-key { script-id: script-id })
            (existing-bookmark (unwrap! (map-get? UserBookmarks bookmark-key) ERR-NOT-BOOKMARKED))
            (existing-user-count (default-to { count: u0 } (map-get? UserBookmarkCounts user-count-key)))
            (existing-script-count (default-to { count: u0 } (map-get? ScriptBookmarkCounts script-count-key)))
        )
        (map-delete UserBookmarks bookmark-key)
        (map-set UserBookmarkCounts user-count-key 
            { count: (if (> (get count existing-user-count) u0) (- (get count existing-user-count) u1) u0) })
        (map-set ScriptBookmarkCounts script-count-key 
            { count: (if (> (get count existing-script-count) u0) (- (get count existing-script-count) u1) u0) })
        
        (print { event: "bookmark-removed", script-id: script-id, user: tx-sender })
        (ok true)
    )
)

(define-read-only (is-script-bookmarked (user principal) (script-id uint))
    (is-some (map-get? UserBookmarks { user: user, script-id: script-id }))
)

(define-read-only (get-user-bookmark-count (user principal))
    (match (map-get? UserBookmarkCounts { user: user })
        data (get count data)
        u0
    )
)

(define-read-only (get-script-bookmark-count (script-id uint))
    (match (map-get? ScriptBookmarkCounts { script-id: script-id })
        data (get count data)
        u0
    )
)

(define-read-only (get-bookmark-details (user principal) (script-id uint))
    (map-get? UserBookmarks { user: user, script-id: script-id })
)

