;; Audit Trail Contract
;; Maintains immutable records of license approvals and violations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-ENTRY (err u401))
(define-constant ERR-ENTRY-NOT-FOUND (err u402))
(define-constant ERR-INVALID-SEARCH (err u403))

;; Data Variables
(define-data-var next-audit-id uint u1)

;; Data Maps
(define-map audit-entries
  { audit-id: uint }
  {
    license-id: uint,
    event-type: (string-ascii 50),
    event-description: (string-ascii 500),
    timestamp: uint,
    block-height: uint,
    actor-principal: principal,
    actor-role: (string-ascii 50),
    previous-state: (string-ascii 200),
    new-state: (string-ascii 200),
    metadata: (string-ascii 1000)
  }
)

(define-map license-audit-history
  { license-id: uint }
  {
    creation-audit-id: uint,
    last-audit-id: uint,
    total-entries: uint,
    last-updated: uint
  }
)

(define-map authorized-auditors principal bool)

;; Authorization Functions
(define-public (add-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-auditors auditor true))
  )
)

(define-public (remove-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-auditors auditor))
  )
)

;; Audit Entry Functions
(define-public (create-audit-entry
  (license-id uint)
  (event-type (string-ascii 50))
  (event-description (string-ascii 500))
  (actor-role (string-ascii 50))
  (previous-state (string-ascii 200))
  (new-state (string-ascii 200))
  (metadata (string-ascii 1000)))
  (let
    (
      (audit-id (var-get next-audit-id))
      (license-history (default-to
        { creation-audit-id: u0, last-audit-id: u0, total-entries: u0, last-updated: u0 }
        (map-get? license-audit-history { license-id: license-id })))
    )
    (asserts! (default-to false (map-get? authorized-auditors tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len event-type) u0) ERR-INVALID-ENTRY)
    (asserts! (> (len event-description) u0) ERR-INVALID-ENTRY)

    ;; Create the audit entry
    (map-set audit-entries
      { audit-id: audit-id }
      {
        license-id: license-id,
        event-type: event-type,
        event-description: event-description,
        timestamp: block-height,
        block-height: block-height,
        actor-principal: tx-sender,
        actor-role: actor-role,
        previous-state: previous-state,
        new-state: new-state,
        metadata: metadata
      }
    )

    ;; Update license audit history
    (map-set license-audit-history
      { license-id: license-id }
      {
        creation-audit-id: (if (is-eq (get total-entries license-history) u0) audit-id (get creation-audit-id license-history)),
        last-audit-id: audit-id,
        total-entries: (+ (get total-entries license-history) u1),
        last-updated: block-height
      }
    )

    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

;; Specialized Audit Functions
(define-public (audit-license-creation
  (license-id uint)
  (business-name (string-ascii 100))
  (license-type (string-ascii 50))
  (metadata (string-ascii 1000)))
  (create-audit-entry
    license-id
    "LICENSE_CREATED"
    "New business license created"
    "SYSTEM"
    "NONE"
    "ACTIVE"
    metadata
  )
)

(define-public (audit-license-approval
  (license-id uint)
  (approver-role (string-ascii 50))
  (metadata (string-ascii 1000)))
  (create-audit-entry
    license-id
    "LICENSE_APPROVED"
    "License application approved"
    approver-role
    "PENDING"
    "APPROVED"
    metadata
  )
)

(define-public (audit-license-renewal
  (license-id uint)
  (renewal-period (string-ascii 50))
  (metadata (string-ascii 1000)))
  (create-audit-entry
    license-id
    "LICENSE_RENEWED"
    "License renewed for new period"
    "RENEWAL_SYSTEM"
    "EXPIRING"
    "ACTIVE"
    metadata
  )
)

(define-public (audit-violation-recorded
  (license-id uint)
  (violation-type (string-ascii 100))
  (severity uint)
  (metadata (string-ascii 1000)))
  (create-audit-entry
    license-id
    "VIOLATION_RECORDED"
    "Compliance violation recorded"
    "COMPLIANCE_OFFICER"
    "COMPLIANT"
    "VIOLATION_PENDING"
    metadata
  )
)

(define-public (audit-compliance-check
  (license-id uint)
  (check-result (string-ascii 50))
  (score uint)
  (metadata (string-ascii 1000)))
  (create-audit-entry
    license-id
    "COMPLIANCE_CHECK"
    "Regular compliance check performed"
    "COMPLIANCE_OFFICER"
    "UNKNOWN"
    check-result
    metadata
  )
)

(define-public (audit-inter-agency-request
  (license-id uint)
  (requesting-agency (string-ascii 100))
  (request-type (string-ascii 50))
  (metadata (string-ascii 1000)))
  (create-audit-entry
    license-id
    "INTER_AGENCY_REQUEST"
    "Information requested by another agency"
    "AGENCY_COORDINATOR"
    "PRIVATE"
    "SHARED"
    metadata
  )
)

;; Read-only Functions
(define-read-only (get-audit-entry (audit-id uint))
  (map-get? audit-entries { audit-id: audit-id })
)

(define-read-only (get-license-audit-summary (license-id uint))
  (map-get? license-audit-history { license-id: license-id })
)

(define-read-only (is-auditor (principal-check principal))
  (default-to false (map-get? authorized-auditors principal-check))
)

(define-read-only (verify-audit-integrity (audit-id uint))
  (match (map-get? audit-entries { audit-id: audit-id })
    entry (ok {
      audit-id: audit-id,
      timestamp: (get timestamp entry),
      block-height: (get block-height entry),
      immutable: true
    })
    ERR-ENTRY-NOT-FOUND
  )
)

(define-read-only (get-audit-trail-for-license (license-id uint))
  (match (map-get? license-audit-history { license-id: license-id })
    history (ok {
      license-id: license-id,
      creation-audit-id: (get creation-audit-id history),
      last-audit-id: (get last-audit-id history),
      total-entries: (get total-entries history),
      last-updated: (get last-updated history)
    })
    ERR-ENTRY-NOT-FOUND
  )
)

(define-read-only (search-audit-by-event-type (event-type (string-ascii 50)))
  (ok "Audit entries by event type - implementation would filter by event type")
)

(define-read-only (search-audit-by-actor (actor-principal principal))
  (ok "Audit entries by actor - implementation would filter by actor")
)

(define-read-only (get-audit-statistics)
  (ok {
    total-audit-entries: (var-get next-audit-id),
    current-block: block-height
  })
)
