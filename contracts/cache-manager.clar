;; Paymaster Cache Contract
;; 
;; This contract serves as a decentralized cache management system for paymasters,
;; handling:
;; - Caching transaction gas estimations
;; - Managing cache expiration and invalidation
;; - Supporting cross-chain paymaster operations
;; - Providing efficient fee estimation services

;; ---------- Error Constants ----------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CACHE-ENTRY-NOT-FOUND (err u101))
(define-constant ERR-CACHE-ENTRY-EXPIRED (err u102))
(define-constant ERR-INVALID-CACHE-DURATION (err u103))
(define-constant ERR-CACHE-LIMIT-REACHED (err u104))

;; ---------- Data Maps and Variables ----------

;; Contract administrator 
(define-data-var contract-admin principal tx-sender)

;; Maximum number of cache entries
(define-data-var max-cache-entries uint u1000)

;; Cached transaction gas estimations
(define-map transaction-cache
  { 
    tx-hash: (buff 32),       ;; Unique transaction hash
    chain-id: uint,           ;; Blockchain identifier
  }
  {
    estimated-gas: uint,      ;; Estimated gas cost
    timestamp: uint,          ;; Block height when cached
    expiry-duration: uint     ;; Blocks until cache expires
    paymaster: principal      ;; Originating paymaster
  }
)

;; Cache usage tracking
(define-data-var current-cache-entries uint u0)

;; ---------- Private Functions ----------

;; Check if caller is contract admin
(define-private (is-admin (caller principal))
  (is-eq caller (var-get contract-admin))
)

;; Validate cache entry duration
(define-private (is-valid-duration (duration uint))
  (and (>= duration u10) (<= duration u10000))
)

;; ---------- Read-Only Functions ----------

;; Get current cache statistics
(define-read-only (get-cache-stats)
  {
    current-entries: (var-get current-cache-entries),
    max-entries: (var-get max-cache-entries)
  }
)

;; Check if a transaction is cached
(define-read-only (is-transaction-cached 
  (tx-hash (buff 32))
  (chain-id uint))
  (match (map-get? transaction-cache { tx-hash: tx-hash, chain-id: chain-id })
    entry 
      (> (get expiry-duration entry) (- block-height (get timestamp entry)))
    false
  )
)

;; ---------- Public Functions ----------

;; Update contract administrator
(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-admin new-admin))
  )
)

;; Set maximum cache entries
(define-public (set-max-cache-entries (max-entries uint))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= max-entries u10) ERR-INVALID-CACHE-DURATION)
    (ok (var-set max-cache-entries max-entries))
  )
)

;; Cache a transaction gas estimation
(define-public (cache-transaction 
  (tx-hash (buff 32))
  (chain-id uint)
  (estimated-gas uint)
  (expiry-duration uint))
  (let (
    (sender tx-sender)
    (current-entries (var-get current-cache-entries))
    (max-entries (var-get max-cache-entries))
  )
    ;; Validate expiration duration
    (asserts! (is-valid-duration expiry-duration) ERR-INVALID-CACHE-DURATION)
    
    ;; Check if cache is full
    (asserts! (< current-entries max-entries) ERR-CACHE-LIMIT-REACHED)
    
    ;; Cache the transaction
    (map-set transaction-cache 
      { tx-hash: tx-hash, chain-id: chain-id }
      {
        estimated-gas: estimated-gas,
        timestamp: block-height,
        expiry-duration: expiry-duration,
        paymaster: sender
      }
    )
    
    ;; Increment cache entries
    (var-set current-cache-entries (+ current-entries u1))
    
    (ok true)
  )
)

;; Retrieve cached transaction details
(define-public (get-cached-transaction 
  (tx-hash (buff 32))
  (chain-id uint))
  (match (map-get? transaction-cache { tx-hash: tx-hash, chain-id: chain-id })
    entry 
      (begin
        ;; Check if cache is still valid
        (asserts! 
          (<= (- block-height (get timestamp entry)) (get expiry-duration entry)) 
          ERR-CACHE-ENTRY-EXPIRED
        )
        (ok entry)
      )
    (err ERR-CACHE-ENTRY-NOT-FOUND)
  )
)

;; Clear a specific cache entry
(define-public (clear-cache-entry 
  (tx-hash (buff 32))
  (chain-id uint))
  (let (
    (current-entries (var-get current-cache-entries))
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    
    (match (map-get? transaction-cache { tx-hash: tx-hash, chain-id: chain-id })
      entry 
        (begin
          (map-delete transaction-cache { tx-hash: tx-hash, chain-id: chain-id })
          (var-set current-cache-entries (- current-entries u1))
          (ok true)
        )
      (err ERR-CACHE-ENTRY-NOT-FOUND)
    )
  )
)

;; Bulk clear expired cache entries
(define-public (clear-expired-entries)
  (let (
    (entries-to-delete 
      (filter 
        (lambda (entry) 
          (let (
            (cached-tx (map-get? transaction-cache entry))
          )
            (match cached-tx
              tx 
                (> (- block-height (get timestamp tx)) (get expiry-duration tx))
              false
            )
          )
        )
        (map-keys transaction-cache)
      )
    )
  )
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    
    (fold 
      (lambda (entry result)
        (begin
          (map-delete transaction-cache entry)
          (var-set current-cache-entries (- (var-get current-cache-entries) u1))
          result
        )
      )
      entries-to-delete
      true
    )
    
    (ok true)
  )
)