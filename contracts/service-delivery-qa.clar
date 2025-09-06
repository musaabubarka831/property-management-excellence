;; Service Delivery and Quality Assurance Contract
;; Property Management Excellence - Part of the comprehensive property management system
;; Handles service delivery tracking, quality metrics, and performance analytics

;; ====================
;; CONSTANTS
;; ====================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PROPERTY (err u101))
(define-constant ERR-INVALID-SCORE (err u102))
(define-constant ERR-SERVICE-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-STATUS (err u105))

;; Status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-IN-PROGRESS u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-CANCELLED u3)

;; Quality score thresholds
(define-constant MIN-QUALITY-SCORE u0)
(define-constant MAX-QUALITY-SCORE u100)
(define-constant EXCELLENT-THRESHOLD u90)
(define-constant GOOD-THRESHOLD u75)

;; ====================
;; DATA STRUCTURES
;; ====================

;; Property information
(define-map properties
  { property-id: uint }
  {
    owner: principal,
    address: (string-ascii 128),
    property-type: (string-ascii 32),
    created-at: uint,
    is-active: bool,
    total-services: uint,
    average-quality: uint
  }
)

;; Service delivery records
(define-map service-records
  { service-id: uint }
  {
    property-id: uint,
    service-provider: principal,
    service-type: (string-ascii 64),
    description: (string-ascii 256),
    scheduled-date: uint,
    completion-date: (optional uint),
    quality-score: (optional uint),
    status: uint,
    cost: uint,
    created-by: principal,
    created-at: uint
  }
)

;; Quality metrics aggregation
(define-map quality-metrics
  { property-id: uint, period: uint }
  {
    total-services: uint,
    average-score: uint,
    excellent-count: uint,
    good-count: uint,
    below-good-count: uint,
    last-updated: uint
  }
)

;; Service provider performance tracking
(define-map provider-performance
  { provider: principal }
  {
    total-services: uint,
    completed-services: uint,
    average-rating: uint,
    excellent-services: uint,
    last-service-date: uint
  }
)

;; ====================
;; DATA VARIABLES
;; ====================

;; Contract state
(define-data-var contract-owner principal tx-sender)
(define-data-var next-property-id uint u1)
(define-data-var next-service-id uint u1)
(define-data-var total-properties uint u0)
(define-data-var total-services uint u0)

;; ====================
;; PRIVATE FUNCTIONS
;; ====================

;; Validate quality score range
(define-private (is-valid-score (score uint))
  (and (>= score MIN-QUALITY-SCORE) (<= score MAX-QUALITY-SCORE))
)

;; Check if property exists
(define-private (property-exists (property-id uint))
  (is-some (map-get? properties { property-id: property-id }))
)

;; Check if service exists
(define-private (service-exists (service-id uint))
  (is-some (map-get? service-records { service-id: service-id }))
)

;; Calculate quality category
(define-private (get-quality-category (score uint))
  (if (>= score EXCELLENT-THRESHOLD) u3
    (if (>= score GOOD-THRESHOLD) u2
      (if (> score u0) u1 u0)
    )
  )
)

;; Update provider performance metrics
(define-private (update-provider-performance (provider principal) (quality-score uint))
  (let (
    (current-performance (default-to
      { total-services: u0, completed-services: u0, average-rating: u0, excellent-services: u0, last-service-date: u0 }
      (map-get? provider-performance { provider: provider })
    ))
    (new-total (+ (get total-services current-performance) u1))
    (new-completed (+ (get completed-services current-performance) u1))
    (current-avg (get average-rating current-performance))
    (new-average (/ (+ (* current-avg (get completed-services current-performance)) quality-score) new-completed))
    (new-excellent (if (>= quality-score EXCELLENT-THRESHOLD)
                     (+ (get excellent-services current-performance) u1)
                     (get excellent-services current-performance)
                   ))
  )
    (map-set provider-performance
      { provider: provider }
      {
        total-services: new-total,
        completed-services: new-completed,
        average-rating: new-average,
        excellent-services: new-excellent,
        last-service-date: block-height
      }
    )
  )
)

;; ====================
;; PUBLIC FUNCTIONS
;; ====================

;; Register a new property
(define-public (register-property (owner principal) (address (string-ascii 128)) (property-type (string-ascii 32)))
  (let (
    (property-id (var-get next-property-id))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (map-set properties
      { property-id: property-id }
      {
        owner: owner,
        address: address,
        property-type: property-type,
        created-at: block-height,
        is-active: true,
        total-services: u0,
        average-quality: u0
      }
    )
    
    (var-set next-property-id (+ property-id u1))
    (var-set total-properties (+ (var-get total-properties) u1))
    
    (ok property-id)
  )
)

;; Create a new service delivery record
(define-public (create-service-record 
                (property-id uint) 
                (service-type (string-ascii 64)) 
                (description (string-ascii 256))
                (scheduled-date uint)
                (cost uint))
  (let (
    (service-id (var-get next-service-id))
  )
    (asserts! (property-exists property-id) ERR-INVALID-PROPERTY)
    
    (map-set service-records
      { service-id: service-id }
      {
        property-id: property-id,
        service-provider: tx-sender,
        service-type: service-type,
        description: description,
        scheduled-date: scheduled-date,
        completion-date: none,
        quality-score: none,
        status: STATUS-PENDING,
        cost: cost,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    
    (var-set next-service-id (+ service-id u1))
    (var-set total-services (+ (var-get total-services) u1))
    
    (ok service-id)
  )
)

;; Complete service and add quality score
(define-public (complete-service (service-id uint) (quality-score uint))
  (let (
    (service-record (unwrap! (map-get? service-records { service-id: service-id }) ERR-SERVICE-NOT-FOUND))
    (property-id (get property-id service-record))
    (provider (get service-provider service-record))
  )
    (asserts! (is-valid-score quality-score) ERR-INVALID-SCORE)
    (asserts! (or (is-eq tx-sender provider) (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status service-record) STATUS-IN-PROGRESS) ERR-INVALID-STATUS)
    
    ;; Update service record
    (map-set service-records
      { service-id: service-id }
      (merge service-record {
        completion-date: (some block-height),
        quality-score: (some quality-score),
        status: STATUS-COMPLETED
      })
    )
    
    ;; Update provider performance
    (update-provider-performance provider quality-score)
    
    ;; Update property quality metrics
    (update-property-quality property-id quality-score)
    
    (ok true)
  )
)

;; Update service status
(define-public (update-service-status (service-id uint) (new-status uint))
  (let (
    (service-record (unwrap! (map-get? service-records { service-id: service-id }) ERR-SERVICE-NOT-FOUND))
    (provider (get service-provider service-record))
  )
    (asserts! (or (is-eq tx-sender provider) (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (asserts! (< new-status u4) ERR-INVALID-STATUS)
    
    (map-set service-records
      { service-id: service-id }
      (merge service-record { status: new-status })
    )
    
    (ok true)
  )
)

;; Private function to update property quality metrics
(define-private (update-property-quality (property-id uint) (quality-score uint))
  (let (
    (property-data (unwrap-panic (map-get? properties { property-id: property-id })))
    (current-total (get total-services property-data))
    (current-avg (get average-quality property-data))
    (new-total (+ current-total u1))
    (new-average (/ (+ (* current-avg current-total) quality-score) new-total))
  )
    (map-set properties
      { property-id: property-id }
      (merge property-data {
        total-services: new-total,
        average-quality: new-average
      })
    )
    true
  )
)

;; ====================
;; READ-ONLY FUNCTIONS
;; ====================

;; Get property information
(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

;; Get service record
(define-read-only (get-service-record (service-id uint))
  (map-get? service-records { service-id: service-id })
)

;; Get property quality score
(define-read-only (get-property-quality-score (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property-data (ok (get average-quality property-data))
    (err ERR-INVALID-PROPERTY)
  )
)

;; Get provider performance
(define-read-only (get-provider-performance (provider principal))
  (map-get? provider-performance { provider: provider })
)

;; Get quality metrics for a property and period
(define-read-only (get-quality-metrics (property-id uint) (period uint))
  (map-get? quality-metrics { property-id: property-id, period: period })
)

;; Get contract stats
(define-read-only (get-contract-stats)
  {
    total-properties: (var-get total-properties),
    total-services: (var-get total-services),
    next-property-id: (var-get next-property-id),
    next-service-id: (var-get next-service-id),
    contract-owner: (var-get contract-owner)
  }
)


;; title: service-delivery-qa
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

