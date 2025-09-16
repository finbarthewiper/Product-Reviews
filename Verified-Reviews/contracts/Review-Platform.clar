;; ReviewChain: Decentralized Product Review Platform Contract
;;
;; A blockchain-powered review ecosystem that enables transparent product cataloging,
;; authentic customer feedback collection, and tamper-proof review aggregation.
;; Features include immutable review storage, real-time analytics, paginated browsing,
;; and decentralized governance with community-driven moderation capabilities.

;; Application error constants for comprehensive error handling
(define-constant ERR-UNAUTHORIZED-ACCESS u1)
(define-constant ERR-PRODUCT-NOT-FOUND u2)
(define-constant ERR-INSUFFICIENT-PERMISSIONS u3)
(define-constant ERR-INVALID-RATING-SCORE u4)
(define-constant ERR-REVIEW-NOT-FOUND u5)
(define-constant ERR-PRODUCT-ALREADY-EXISTS u6)
(define-constant ERR-PRODUCT-INACTIVE u7)
(define-constant ERR-OPERATION-FAILED u8)
(define-constant ERR-INVALID-PAGE-NUMBER u9)
(define-constant ERR-INVALID-INPUT-DATA u10)
(define-constant ERR-PRODUCT-NAME-TOO-LONG u11)
(define-constant ERR-DESCRIPTION-TOO-LONG u12)
(define-constant ERR-INVALID-PRODUCT-ID u13)
(define-constant ERR-INVALID-REVIEW-ID u14)

;; Platform configuration and business logic constants
(define-constant minimum-rating-value u1)
(define-constant maximum-rating-value u5)
(define-constant reviews-per-page-limit u20)
(define-constant product-name-character-limit u50)
(define-constant description-character-limit u500)

;; Global platform state variables
(define-data-var platform-administrator principal tx-sender)
(define-data-var next-product-identifier uint u1)
(define-data-var next-review-identifier uint u1)

;; Primary data storage for product information
(define-map product-registry
  { product-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 500),
    creator: principal,
    created-at-block: uint,
    is-active: bool
  }
)

;; Customer review storage with comprehensive metadata
(define-map customer-reviews
  { review-id: uint }
  {
    target-product-id: uint,
    author: principal,
    rating-score: uint,
    review-content: (string-ascii 500),
    submitted-at-block: uint,
    verified-purchase: bool
  }
)

;; Relationship mapping between products and their reviews
(define-map product-to-review-mapping
  { product-id: uint, review-id: uint }
  { relationship-active: bool }
)

;; Real-time analytics and performance metrics per product
(define-map product-statistics
  { product-id: uint }
  { 
    review-count: uint, 
    total-rating-points: uint 
  }
)

;; Pagination system for efficient review browsing
(define-map paginated-review-index
  { product-id: uint, page-index: uint }
  { reviews-on-page: (list 20 uint) }
)

;; Core validation utilities for data integrity
(define-private (does-product-exist (product-identifier uint))
  (is-some (map-get? product-registry { product-id: product-identifier }))
)

(define-private (does-review-exist (review-identifier uint))
  (is-some (map-get? customer-reviews { review-id: review-identifier }))
)

(define-private (is-rating-valid (rating-value uint))
  (and (>= rating-value minimum-rating-value) (<= rating-value maximum-rating-value))
)

(define-private (is-product-id-valid (product-identifier uint))
  (and 
    (>= product-identifier u1)
    (< product-identifier (var-get next-product-identifier))
    (does-product-exist product-identifier)
  )
)

(define-private (is-review-id-valid (review-identifier uint))
  (and 
    (>= review-identifier u1) 
    (< review-identifier (var-get next-review-identifier))
    (does-review-exist review-identifier)
  )
)

(define-private (is-product-name-valid (product-name (string-ascii 50)))
  (and 
    (> (len product-name) u0)
    (<= (len product-name) product-name-character-limit)
  )
)

(define-private (is-description-valid (description-text (string-ascii 500)))
  (<= (len description-text) description-character-limit)
)

;; Advanced business logic for relationship and analytics management
(define-private (create-product-review-association (product-identifier uint) (review-identifier uint) (rating-value uint))
  (begin
    (asserts! (is-product-id-valid product-identifier) false)
    (asserts! (is-review-id-valid review-identifier) false)
    (asserts! (is-rating-valid rating-value) false)
    
    (map-insert product-to-review-mapping 
      { product-id: product-identifier, review-id: review-identifier }
      { relationship-active: true }
    )
    
    (match (map-get? product-statistics { product-id: product-identifier })
      existing-stats (map-set product-statistics 
                        { product-id: product-identifier }
                        { 
                          review-count: (+ (get review-count existing-stats) u1),
                          total-rating-points: (+ (get total-rating-points existing-stats) rating-value)
                        })
      (map-insert product-statistics 
        { product-id: product-identifier }
        { review-count: u1, total-rating-points: rating-value })
    )
    
    (let 
      (
        (updated-stats (unwrap-panic (map-get? product-statistics { product-id: product-identifier })))
        (current-review-count (get review-count updated-stats))
        (target-page-index (/ (- current-review-count u1) reviews-per-page-limit))
        (position-in-page (mod (- current-review-count u1) reviews-per-page-limit))
      )
      (match (map-get? paginated-review-index { product-id: product-identifier, page-index: target-page-index })
        existing-page 
          (if (< (len (get reviews-on-page existing-page)) reviews-per-page-limit)
            (map-set paginated-review-index
              { product-id: product-identifier, page-index: target-page-index }
              { reviews-on-page: (unwrap-panic 
                  (as-max-len? 
                    (append (get reviews-on-page existing-page) review-identifier) 
                    u20)) })
            (map-insert paginated-review-index
              { product-id: product-identifier, page-index: (+ u1 target-page-index) }
              { reviews-on-page: (list review-identifier) }))
        (map-insert paginated-review-index
          { product-id: product-identifier, page-index: target-page-index }
          { reviews-on-page: (list review-identifier) })
      )
    )
    
    true
  )
)

(define-private (verify-product-review-relationship (product-identifier uint) (review-identifier uint))
  (default-to 
    false
    (get relationship-active (map-get? product-to-review-mapping { product-id: product-identifier, review-id: review-identifier }))
  )
)

(define-private (update-statistics-after-review-removal (product-identifier uint) (removed-rating uint))
  (begin
    (asserts! (is-product-id-valid product-identifier) false)
    (asserts! (is-rating-valid removed-rating) false)
    
    (match (map-get? product-statistics { product-id: product-identifier })
      current-stats 
        (let 
          (
            (new-review-count (if (> (get review-count current-stats) u0) 
                               (- (get review-count current-stats) u1) 
                               u0))
            (new-rating-total (if (>= (get total-rating-points current-stats) removed-rating)
                               (- (get total-rating-points current-stats) removed-rating)
                               u0))
          )
          (map-set product-statistics 
            { product-id: product-identifier }
            { review-count: new-review-count, total-rating-points: new-rating-total })
          true
        )
      false
    )
  )
)

;; Public read-only functions for data retrieval
(define-read-only (get-product-information (product-identifier uint))
  (if (is-product-id-valid product-identifier)
    (map-get? product-registry { product-id: product-identifier })
    none
  )
)

(define-read-only (get-review-information (review-identifier uint))
  (if (is-review-id-valid review-identifier)
    (map-get? customer-reviews { review-id: review-identifier })
    none
  )
)

(define-read-only (is-caller-platform-admin)
  (is-eq tx-sender (var-get platform-administrator))
)

(define-read-only (get-product-performance-data (product-identifier uint))
  (if (is-product-id-valid product-identifier)
    (default-to 
      { review-count: u0, total-rating-points: u0 } 
      (map-get? product-statistics { product-id: product-identifier }))
    { review-count: u0, total-rating-points: u0 }
  )
)

(define-read-only (calculate-average-product-rating (product-identifier uint))
  (let 
    (
      (performance-data (get-product-performance-data product-identifier))
      (total-reviews (get review-count performance-data))
      (total-points (get total-rating-points performance-data))
    )
    (if (> total-reviews u0)
      (/ total-points total-reviews)
      u0)
  )
)

(define-read-only (get-total-review-pages (product-identifier uint))
  (let 
    (
      (performance-data (get-product-performance-data product-identifier))
      (total-reviews (get review-count performance-data))
    )
    (+ (/ total-reviews reviews-per-page-limit) 
       (if (> (mod total-reviews reviews-per-page-limit) u0) u1 u0))
  )
)

(define-read-only (get-reviews-for-page (product-identifier uint) (page-number uint))
  (if (not (is-product-id-valid product-identifier))
    { reviews-on-page: (list) }
    (let 
      (
        (available-pages (get-total-review-pages product-identifier))
      )
      (if (or (>= page-number available-pages) (is-eq available-pages u0))
        { reviews-on-page: (list) }
        (default-to 
          { reviews-on-page: (list) } 
          (map-get? paginated-review-index { product-id: product-identifier, page-index: page-number }))
      )
    )
  )
)

(define-read-only (get-detailed-reviews-for-page (product-identifier uint) (page-number uint))
  (if (not (is-product-id-valid product-identifier))
    (list)
    (let 
      (
        (page-data (get-reviews-for-page product-identifier page-number))
        (review-identifiers (get reviews-on-page page-data))
        (review-details (map get-review-information review-identifiers))
      )
      review-details
    )
  )
)

;; Product management functions for platform administrators
(define-public (register-new-product (product-name (string-ascii 50)) (product-description (string-ascii 500)))
  (let
    (
      (new-product-id (var-get next-product-identifier))
    )
    (asserts! (is-product-name-valid product-name) (err ERR-PRODUCT-NAME-TOO-LONG))
    (asserts! (is-description-valid product-description) (err ERR-DESCRIPTION-TOO-LONG))
    (asserts! (is-eq tx-sender (var-get platform-administrator)) (err ERR-UNAUTHORIZED-ACCESS))
    
    (var-set next-product-identifier (+ new-product-id u1))
    
    (ok (map-insert product-registry 
      { product-id: new-product-id }
      {
        name: product-name,
        description: product-description,
        creator: tx-sender,
        created-at-block: block-height,
        is-active: true
      }
    ))
  )
)

(define-public (modify-product-details (product-identifier uint) 
                                      (new-name (string-ascii 50)) 
                                      (new-description (string-ascii 500)) 
                                      (active-status bool))
  (begin
    (asserts! (is-product-id-valid product-identifier) (err ERR-INVALID-PRODUCT-ID))
    (asserts! (is-product-name-valid new-name) (err ERR-PRODUCT-NAME-TOO-LONG))
    (asserts! (is-description-valid new-description) (err ERR-DESCRIPTION-TOO-LONG))
    
    (let
      (
        (current-product-data (map-get? product-registry { product-id: product-identifier }))
      )
      (asserts! (is-some current-product-data) (err ERR-PRODUCT-NOT-FOUND))
      
      (asserts! (or 
        (is-eq tx-sender (var-get platform-administrator))
        (is-eq tx-sender (get creator (unwrap-panic current-product-data)))
      ) (err ERR-INSUFFICIENT-PERMISSIONS))
      
      (ok (map-set product-registry
        { product-id: product-identifier }
        {
          name: new-name,
          description: new-description,
          creator: (get creator (unwrap-panic current-product-data)),
          created-at-block: (get created-at-block (unwrap-panic current-product-data)),
          is-active: active-status
        }
      ))
    )
  )
)

;; Review submission and management functions
(define-public (submit-product-review (product-identifier uint) 
                                     (user-rating uint) 
                                     (review-text (string-ascii 500)) 
                                     (is-verified-purchase bool))
  (begin
    (asserts! (is-product-id-valid product-identifier) (err ERR-INVALID-PRODUCT-ID))
    (asserts! (is-rating-valid user-rating) (err ERR-INVALID-RATING-SCORE))
    (asserts! (is-description-valid review-text) (err ERR-DESCRIPTION-TOO-LONG))
    
    (let
      (
        (new-review-id (var-get next-review-identifier))
        (target-product (map-get? product-registry { product-id: product-identifier }))
      )
      (asserts! (is-some target-product) (err ERR-PRODUCT-NOT-FOUND))
      (asserts! (get is-active (unwrap-panic target-product)) (err ERR-PRODUCT-INACTIVE))
      
      (var-set next-review-identifier (+ new-review-id u1))
      
      (begin
        (map-insert customer-reviews
          { review-id: new-review-id }
          {
            target-product-id: product-identifier,
            author: tx-sender,
            rating-score: user-rating,
            review-content: review-text,
            submitted-at-block: block-height,
            verified-purchase: is-verified-purchase
          }
        )
        
        (asserts! (create-product-review-association product-identifier new-review-id user-rating) (err ERR-OPERATION-FAILED))
        
        (ok new-review-id)
      )
    )
  )
)

(define-public (modify-submitted-review (review-identifier uint) 
                                       (updated-rating uint) 
                                       (updated-content (string-ascii 500)))
  (begin
    (asserts! (is-review-id-valid review-identifier) (err ERR-INVALID-REVIEW-ID))
    (asserts! (is-rating-valid updated-rating) (err ERR-INVALID-RATING-SCORE))
    (asserts! (is-description-valid updated-content) (err ERR-DESCRIPTION-TOO-LONG))
    
    (let
      (
        (current-review (map-get? customer-reviews { review-id: review-identifier }))
      )
      (asserts! (is-some current-review) (err ERR-REVIEW-NOT-FOUND))
      (asserts! (is-eq tx-sender (get author (unwrap-panic current-review))) (err ERR-INSUFFICIENT-PERMISSIONS))
      
      (let 
        (
          (review-data (unwrap-panic current-review))
          (old-rating (get rating-score review-data))
          (associated-product (get target-product-id review-data))
          (current-stats (unwrap-panic (map-get? product-statistics { product-id: associated-product })))
          (old-total-points (get total-rating-points current-stats))
          (new-total-points (+ (- old-total-points old-rating) updated-rating))
        )
        (map-set product-statistics 
          { product-id: associated-product }
          { review-count: (get review-count current-stats), total-rating-points: new-total-points }
        )
        
        (ok (map-set customer-reviews
          { review-id: review-identifier }
          {
            target-product-id: associated-product,
            author: tx-sender,
            rating-score: updated-rating,
            review-content: updated-content,
            submitted-at-block: (get submitted-at-block review-data),
            verified-purchase: (get verified-purchase review-data)
          }
        ))
      )
    )
  )
)

(define-public (delete-customer-review (review-identifier uint))
  (begin
    (asserts! (is-review-id-valid review-identifier) (err ERR-INVALID-REVIEW-ID))
    
    (let
      (
        (target-review (map-get? customer-reviews { review-id: review-identifier }))
      )
      (asserts! (is-some target-review) (err ERR-REVIEW-NOT-FOUND))
      
      (asserts! (or 
        (is-eq tx-sender (var-get platform-administrator))
        (is-eq tx-sender (get author (unwrap-panic target-review)))
      ) (err ERR-INSUFFICIENT-PERMISSIONS))
      
      (let
        (
          (review-data (unwrap-panic target-review))
          (associated-product (get target-product-id review-data))
          (review-rating (get rating-score review-data))
        )
        (asserts! (update-statistics-after-review-removal associated-product review-rating) (err ERR-OPERATION-FAILED))
        
        (begin
          (map-delete customer-reviews { review-id: review-identifier })
          (map-delete product-to-review-mapping { 
            product-id: associated-product, 
            review-id: review-identifier 
          })
          (ok true)
        )
      )
    )
  )
)

;; Platform administration and governance functions
(define-public (transfer-platform-ownership (new-administrator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) (err ERR-UNAUTHORIZED-ACCESS))
    (asserts! (not (is-eq new-administrator 'SP000000000000000000002Q6VF78)) (err ERR-INVALID-INPUT-DATA))
    
    (var-set platform-administrator new-administrator)
    (ok true)
  )
)