;; Property Operations Support Contract
;; Property Management Excellence - Comprehensive property management operations
;; Handles property registration, manager assignments, maintenance operations, and reporting

;; ====================
;; CONSTANTS
;; ====================

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PROPERTY-NOT-FOUND (err u201))
(define-constant ERR-MANAGER-NOT-FOUND (err u202))
(define-constant ERR-INVALID-ROLE (err u203))
(define-constant ERR-ALREADY-ASSIGNED (err u204))
(define-constant ERR-MAINTENANCE-NOT-FOUND (err u205))
(define-constant ERR-INVALID-PRIORITY (err u206))
(define-constant ERR-INVALID-STATUS (err u207))
(define-constant ERR-INSUFFICIENT-FUNDS (err u208))

;; Role constants
(define-constant ROLE-OWNER u1)
(define-constant ROLE-PROPERTY-MANAGER u2)
(define-constant ROLE-MAINTENANCE-STAFF u3)
(define-constant ROLE-TENANT u4)

;; Maintenance priority levels
(define-constant PRIORITY-LOW u1)
(define-constant PRIORITY-MEDIUM u2)
(define-constant PRIORITY-HIGH u3)
(define-constant PRIORITY-URGENT u4)

;; Maintenance status
(define-constant MAINTENANCE-PENDING u0)
(define-constant MAINTENANCE-ASSIGNED u1)
(define-constant MAINTENANCE-IN-PROGRESS u2)
(define-constant MAINTENANCE-COMPLETED u3)
(define-constant MAINTENANCE-CANCELLED u4)

;; Property status
(define-constant PROPERTY-ACTIVE u1)
(define-constant PROPERTY-INACTIVE u0)
(define-constant PROPERTY-MAINTENANCE u2)

;; ====================
;; DATA STRUCTURES
;; ====================

;; Property registry with comprehensive details
(define-map property-registry
  { property-id: uint }
  {
    owner: principal,
    address: (string-ascii 128),
    property-type: (string-ascii 32),
    square-footage: uint,
    bedrooms: uint,
    bathrooms: uint,
    year-built: uint,
    estimated-value: uint,
    current-manager: (optional principal),
    status: uint,
    created-at: uint,
    last-updated: uint,
    total-maintenance-requests: uint,
    monthly-rent: uint,
    is-occupied: bool
  }
)

;; Property manager assignments and roles
(define-map property-managers
  { manager-id: principal }
  {
    name: (string-ascii 64),
    contact-info: (string-ascii 128),
    role: uint,
    properties-managed: (list 10 uint),
    experience-years: uint,
    rating: uint,
    is-active: bool,
    hire-date: uint,
    total-properties: uint
  }
)

;; Property-Manager assignment mapping
(define-map property-assignments
  { property-id: uint }
  {
    manager: principal,
    assigned-date: uint,
    assignment-type: (string-ascii 32),
    monthly-fee: uint,
    performance-score: uint
  }
)

;; Maintenance request and work order system
(define-map maintenance-requests
  { request-id: uint }
  {
    property-id: uint,
    requestor: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    category: (string-ascii 32),
    priority: uint,
    status: uint,
    estimated-cost: uint,
    actual-cost: (optional uint),
    assigned-to: (optional principal),
    created-at: uint,
    scheduled-date: (optional uint),
    completed-date: (optional uint),
    images: (optional (string-ascii 256)),
    tenant-accessible: bool
  }
)

;; Asset tracking for property components
(define-map property-assets
  { asset-id: uint }
  {
    property-id: uint,
    asset-name: (string-ascii 64),
    category: (string-ascii 32),
    manufacturer: (string-ascii 64),
    model: (string-ascii 64),
    installation-date: uint,
    warranty-expiry: uint,
    last-maintenance: (optional uint),
    maintenance-interval: uint,
    replacement-cost: uint,
    condition-score: uint
  }
)

;; Operational insights and reporting data
(define-map operational-reports
  { property-id: uint, report-period: uint }
  {
    total-maintenance-cost: uint,
    maintenance-requests-count: uint,
    average-resolution-time: uint,
    tenant-satisfaction-score: uint,
    occupancy-rate: uint,
    revenue-generated: uint,
    expenses-incurred: uint,
    profit-margin: uint
  }
)

;; ====================
;; DATA VARIABLES
;; ====================

;; Contract management variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-property-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var next-asset-id uint u1)
(define-data-var total-properties uint u0)
(define-data-var total-managers uint u0)
(define-data-var total-maintenance-requests uint u0)

;; ====================
;; PRIVATE FUNCTIONS
;; ====================

;; Validate property existence
(define-private (property-exists (property-id uint))
  (is-some (map-get? property-registry { property-id: property-id }))
)

;; Check if user is authorized for property operations
(define-private (is-authorized-for-property (property-id uint) (user principal))
  (let (
    (property (unwrap! (map-get? property-registry { property-id: property-id }) false))
    (assignment (map-get? property-assignments { property-id: property-id }))
  )
    (or 
      (is-eq user (var-get contract-owner))
      (is-eq user (get owner property))
      (match assignment
        assign-data (is-eq user (get manager assign-data))
        false
      )
    )
  )
)

;; Validate maintenance priority
(define-private (is-valid-priority (priority uint))
  (and (>= priority PRIORITY-LOW) (<= priority PRIORITY-URGENT))
)

;; Calculate property performance score
(define-private (calculate-property-performance (property-id uint))
  (let (
    (property (unwrap! (map-get? property-registry { property-id: property-id }) u0))
    (maintenance-count (get total-maintenance-requests property))
    ;; Simple scoring: fewer maintenance requests = higher score
    (base-score u100)
    (deduction (* maintenance-count u5))
  )
    (if (> deduction base-score) u0 (- base-score deduction))
  )
)

;; ====================
;; PUBLIC FUNCTIONS
;; ====================

;; Register a comprehensive property with detailed information
(define-public (register-property 
                (owner principal)
                (address (string-ascii 128))
                (property-type (string-ascii 32))
                (square-footage uint)
                (bedrooms uint)
                (bathrooms uint)
                (year-built uint)
                (estimated-value uint)
                (monthly-rent uint))
  (let (
    (property-id (var-get next-property-id))
  )
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-eq tx-sender owner)) ERR-NOT-AUTHORIZED)
    
    (map-set property-registry
      { property-id: property-id }
      {
        owner: owner,
        address: address,
        property-type: property-type,
        square-footage: square-footage,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        year-built: year-built,
        estimated-value: estimated-value,
        current-manager: none,
        status: PROPERTY-ACTIVE,
        created-at: block-height,
        last-updated: block-height,
        total-maintenance-requests: u0,
        monthly-rent: monthly-rent,
        is-occupied: false
      }
    )
    
    (var-set next-property-id (+ property-id u1))
    (var-set total-properties (+ (var-get total-properties) u1))
    
    (ok property-id)
  )
)

;; Register and assign property manager
(define-public (assign-property-manager 
                (property-id uint)
                (manager principal)
                (name (string-ascii 64))
                (contact-info (string-ascii 128))
                (experience-years uint)
                (monthly-fee uint))
  (let (
    (property (unwrap! (map-get? property-registry { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
  )
    (asserts! (is-authorized-for-property property-id tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Update manager information
    (map-set property-managers
      { manager-id: manager }
      {
        name: name,
        contact-info: contact-info,
        role: ROLE-PROPERTY-MANAGER,
        properties-managed: (list property-id),
        experience-years: experience-years,
        rating: u75, ;; Default starting rating
        is-active: true,
        hire-date: block-height,
        total-properties: u1
      }
    )
    
    ;; Create assignment record
    (map-set property-assignments
      { property-id: property-id }
      {
        manager: manager,
        assigned-date: block-height,
        assignment-type: "Full Management",
        monthly-fee: monthly-fee,
        performance-score: u75
      }
    )
    
    ;; Update property with manager
    (map-set property-registry
      { property-id: property-id }
      (merge property {
        current-manager: (some manager),
        last-updated: block-height
      })
    )
    
    (var-set total-managers (+ (var-get total-managers) u1))
    
    (ok true)
  )
)

;; Create maintenance request with comprehensive details
(define-public (create-maintenance-request
                (property-id uint)
                (title (string-ascii 64))
                (description (string-ascii 256))
                (category (string-ascii 32))
                (priority uint)
                (estimated-cost uint)
                (tenant-accessible bool))
  (let (
    (request-id (var-get next-request-id))
    (property (unwrap! (map-get? property-registry { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
  )
    (asserts! (property-exists property-id) ERR-PROPERTY-NOT-FOUND)
    (asserts! (is-valid-priority priority) ERR-INVALID-PRIORITY)
    
    (map-set maintenance-requests
      { request-id: request-id }
      {
        property-id: property-id,
        requestor: tx-sender,
        title: title,
        description: description,
        category: category,
        priority: priority,
        status: MAINTENANCE-PENDING,
        estimated-cost: estimated-cost,
        actual-cost: none,
        assigned-to: none,
        created-at: block-height,
        scheduled-date: none,
        completed-date: none,
        images: none,
        tenant-accessible: tenant-accessible
      }
    )
    
    ;; Update property maintenance counter
    (map-set property-registry
      { property-id: property-id }
      (merge property {
        total-maintenance-requests: (+ (get total-maintenance-requests property) u1),
        last-updated: block-height
      })
    )
    
    (var-set next-request-id (+ request-id u1))
    (var-set total-maintenance-requests (+ (var-get total-maintenance-requests) u1))
    
    (ok request-id)
  )
)

;; Assign maintenance request to staff
(define-public (assign-maintenance-request (request-id uint) (assigned-to principal) (scheduled-date uint))
  (let (
    (request (unwrap! (map-get? maintenance-requests { request-id: request-id }) ERR-MAINTENANCE-NOT-FOUND))
    (property-id (get property-id request))
  )
    (asserts! (is-authorized-for-property property-id tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set maintenance-requests
      { request-id: request-id }
      (merge request {
        assigned-to: (some assigned-to),
        scheduled-date: (some scheduled-date),
        status: MAINTENANCE-ASSIGNED
      })
    )
    
    (ok true)
  )
)

;; Complete maintenance request with actual cost
(define-public (complete-maintenance-request (request-id uint) (actual-cost uint))
  (let (
    (request (unwrap! (map-get? maintenance-requests { request-id: request-id }) ERR-MAINTENANCE-NOT-FOUND))
    (property-id (get property-id request))
  )
    (asserts! (or 
                (is-authorized-for-property property-id tx-sender)
                (match (get assigned-to request)
                  assigned-staff (is-eq tx-sender assigned-staff)
                  false
                )
              ) ERR-NOT-AUTHORIZED)
    
    (map-set maintenance-requests
      { request-id: request-id }
      (merge request {
        actual-cost: (some actual-cost),
        completed-date: (some block-height),
        status: MAINTENANCE-COMPLETED
      })
    )
    
    (ok true)
  )
)

;; Add property asset for tracking
(define-public (add-property-asset
                (property-id uint)
                (asset-name (string-ascii 64))
                (category (string-ascii 32))
                (manufacturer (string-ascii 64))
                (model (string-ascii 64))
                (installation-date uint)
                (warranty-expiry uint)
                (replacement-cost uint))
  (let (
    (asset-id (var-get next-asset-id))
  )
    (asserts! (property-exists property-id) ERR-PROPERTY-NOT-FOUND)
    (asserts! (is-authorized-for-property property-id tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set property-assets
      { asset-id: asset-id }
      {
        property-id: property-id,
        asset-name: asset-name,
        category: category,
        manufacturer: manufacturer,
        model: model,
        installation-date: installation-date,
        warranty-expiry: warranty-expiry,
        last-maintenance: none,
        maintenance-interval: u365, ;; Default yearly maintenance
        replacement-cost: replacement-cost,
        condition-score: u100 ;; New asset starts with perfect condition
      }
    )
    
    (var-set next-asset-id (+ asset-id u1))
    
    (ok asset-id)
  )
)

;; ====================
;; READ-ONLY FUNCTIONS
;; ====================

;; Get comprehensive property information
(define-read-only (get-property-details (property-id uint))
  (map-get? property-registry { property-id: property-id })
)

;; Get property manager information
(define-read-only (get-manager-info (manager principal))
  (map-get? property-managers { manager-id: manager })
)

;; Get property assignment details
(define-read-only (get-property-assignment (property-id uint))
  (map-get? property-assignments { property-id: property-id })
)

;; Get maintenance request details
(define-read-only (get-maintenance-request (request-id uint))
  (map-get? maintenance-requests { request-id: request-id })
)

;; Get property asset information
(define-read-only (get-property-asset (asset-id uint))
  (map-get? property-assets { asset-id: asset-id })
)

;; Get operational report for property
(define-read-only (get-operational-report (property-id uint) (period uint))
  (map-get? operational-reports { property-id: property-id, report-period: period })
)

;; Get property performance score
(define-read-only (get-property-performance-score (property-id uint))
  (ok (calculate-property-performance property-id))
)

;; Get contract statistics
(define-read-only (get-contract-statistics)
  {
    total-properties: (var-get total-properties),
    total-managers: (var-get total-managers),
    total-maintenance-requests: (var-get total-maintenance-requests),
    next-property-id: (var-get next-property-id),
    next-request-id: (var-get next-request-id),
    contract-owner: (var-get contract-owner)
  }
)


;; title: property-ops-support
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

