;; Learning Material Marketplace Smart Contract
;; This contract enables creators to publish and sell learning materials
;; and allows users to purchase access to these materials.

;; Define contract constants and error codes
(define-constant contract-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-UNAUTHORIZED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-INVALID-PRICE (err u105))
(define-constant ERR-INACTIVE (err u106))
(define-constant ERR-INVALID-INPUT (err u107))

;; Data structures

;; Represents a learning material
(define-map learning-materials
  { material-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-utf8 500),
    price: uint,
    category: (string-ascii 50),
    created-at: uint,
    is-active: bool
  }
)

;; Tracks materials created by each creator
(define-map creator-materials
  { creator: principal }
  { material-ids: (list 100 uint) }
)

;; Tracks purchases of materials
(define-map purchases
  { buyer: principal, material-id: uint }
  { purchased-at: uint, access-expires: uint }
)

;; Tracks buyer's purchased materials
(define-map buyer-materials
  { buyer: principal }
  { material-ids: (list 100 uint) }
)

;; Platform fees percentage (in basis points: 250 = 2.5%)
(define-data-var platform-fee-basis-points uint u250)

;; Counter for material IDs
(define-data-var next-material-id uint u1)

;; Contract initialization functions

;; Generate a new material ID
(define-private (get-next-material-id)
  (let
    ((current-id (var-get next-material-id)))
    (begin
      (var-set next-material-id (+ current-id u1))
      current-id
    )
  )
)

;; Helper functions

;; Calculate platform fee
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-basis-points)) u10000)
)

;; Add material ID to a list
(define-private (add-material-to-list (material-id uint) (current-list (list 100 uint)))
  (if (>= (len current-list) u99)
    ;; If list is full, return the original list
    current-list
    ;; Otherwise, append to list
    (unwrap! (as-max-len? (append current-list material-id) u100) current-list)
  )
)

;; Validate title input
(define-private (validate-title (title (string-ascii 100)))
  (and
    (> (len title) u0)
    (<= (len title) u100)
  )
)

;; Validate description input
(define-private (validate-description (description (string-utf8 500)))
  (and
    (> (len description) u0)
    (<= (len description) u500)
  )
)

;; Validate category input
(define-private (validate-category (category (string-ascii 50)))
  (and
    (> (len category) u0)
    (<= (len category) u50)
  )
)

;; Validate material ID input
(define-private (validate-material-id (material-id uint))
  (and
    (> material-id u0)
    (< material-id (var-get next-material-id))
  )
)

;; Check if user has purchased a material
(define-read-only (has-purchased (buyer principal) (material-id uint))
  (is-some (map-get? purchases { buyer: buyer, material-id: material-id }))
)

;; Check if a material exists and is active
(define-read-only (is-valid-material (material-id uint))
  (match (map-get? learning-materials { material-id: material-id })
    material (get is-active material)
    false
  )
)

;; Public functions

;; Create a new learning material
(define-public (create-material (title (string-ascii 100)) (description (string-utf8 500)) (price uint) (category (string-ascii 50)))
  (let
    (
      (new-id (get-next-material-id))
      (current-time (get-block-info? time (- block-height u1)))
    )
    ;; Validate inputs
    (asserts! (validate-title title) ERR-INVALID-INPUT)
    (asserts! (validate-description description) ERR-INVALID-INPUT)
    (asserts! (validate-category category) ERR-INVALID-INPUT)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (is-some current-time) ERR-NOT-FOUND)
    
    ;; Create the material entry
    (map-set learning-materials
      { material-id: new-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        price: price,
        category: category,
        created-at: (default-to u0 current-time),
        is-active: true
      }
    )
    
    ;; Add to creator's materials list
    (match (map-get? creator-materials { creator: tx-sender })
      existing-entry (map-set creator-materials 
                      { creator: tx-sender }
                      { material-ids: (add-material-to-list new-id (get material-ids existing-entry)) })
      ;; No existing materials, create a new list
      (map-set creator-materials
        { creator: tx-sender }
        { material-ids: (list new-id) })
    )
    
    (ok new-id)
  )
)

;; Update material details
(define-public (update-material (material-id uint) (title (string-ascii 100)) (description (string-utf8 500)) (price uint) (category (string-ascii 50)))
  (let
    ((material-option (map-get? learning-materials { material-id: material-id })))
    
    ;; Validate inputs
    (asserts! (validate-material-id material-id) ERR-INVALID-INPUT)
    (asserts! (validate-title title) ERR-INVALID-INPUT)
    (asserts! (validate-description description) ERR-INVALID-INPUT)
    (asserts! (validate-category category) ERR-INVALID-INPUT)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (is-some material-option) ERR-NOT-FOUND)
    
    (let ((material (unwrap-panic material-option)))
      (asserts! (is-eq (get creator material) tx-sender) ERR-UNAUTHORIZED)
      
      ;; Update the material
      (map-set learning-materials
        { material-id: material-id }
        {
          creator: (get creator material),
          title: title,
          description: description,
          price: price,
          category: category,
          created-at: (get created-at material),
          is-active: (get is-active material)
        })
      
      (ok true)
    )
  )
)

;; Deactivate a material (instead of deleting)
(define-public (deactivate-material (material-id uint))
  (let
    ((material-option (map-get? learning-materials { material-id: material-id })))
    
    ;; Validate material ID
    (asserts! (validate-material-id material-id) ERR-INVALID-INPUT)
    (asserts! (is-some material-option) ERR-NOT-FOUND)
    
    (let ((material (unwrap-panic material-option)))
      (asserts! (or 
                  (is-eq (get creator material) tx-sender)
                  (is-eq tx-sender contract-owner)
                ) 
                ERR-UNAUTHORIZED)
      
      ;; Update to set inactive
      (map-set learning-materials
        { material-id: material-id }
        {
          creator: (get creator material),
          title: (get title material),
          description: (get description material),
          price: (get price material),
          category: (get category material),
          created-at: (get created-at material),
          is-active: false
        })
      
      (ok true)
    )
  )
)

;; Purchase access to learning material
(define-public (purchase-material (material-id uint))
  (let
    (
      (current-time-option (get-block-info? time (- block-height u1)))
      (access-duration u15768000) ;; Access valid for 6 months (in seconds)
      (material-option (map-get? learning-materials { material-id: material-id }))
    )
    
    ;; Validate material ID
    (asserts! (validate-material-id material-id) ERR-INVALID-INPUT)
    
    ;; Ensure time is available and material exists
    (asserts! (is-some current-time-option) ERR-NOT-FOUND)
    (asserts! (is-some material-option) ERR-NOT-FOUND)
    
    (let 
      (
        (block-time (unwrap-panic current-time-option))
        (material (unwrap-panic material-option))
      )
      
      ;; Check if material is active
      (asserts! (get is-active material) ERR-INACTIVE)
      
      (let
        (
          (creator (get creator material))
          (price (get price material))
          (platform-fee (calculate-platform-fee price))
          (creator-amount (- price platform-fee))
          (expiry-time (+ block-time access-duration))
        )
        
        ;; Transfer funds from buyer to creator
        (let ((transfer-creator-result (stx-transfer? creator-amount tx-sender creator)))
          (asserts! (is-ok transfer-creator-result) ERR-INSUFFICIENT-BALANCE)
          
          ;; Transfer funds from buyer to platform
          (let ((transfer-platform-result (stx-transfer? platform-fee tx-sender contract-owner)))
            (asserts! (is-ok transfer-platform-result) ERR-INSUFFICIENT-BALANCE)
            
            ;; Record the purchase
            (map-set purchases
              { buyer: tx-sender, material-id: material-id }
              { purchased-at: block-time, access-expires: expiry-time }
            )
            
            ;; Add to buyer's materials list
            (match (map-get? buyer-materials { buyer: tx-sender })
              existing-entry (map-set buyer-materials 
                              { buyer: tx-sender }
                              { material-ids: (add-material-to-list material-id (get material-ids existing-entry)) })
              ;; No existing purchases, create a new list
              (map-set buyer-materials
                { buyer: tx-sender }
                { material-ids: (list material-id) })
            )
            
            (ok true)
          )
        )
      )
    )
  )
)

;; Extend access to a purchased material
(define-public (extend-access (material-id uint))
  (let
    (
      (purchase-option (map-get? purchases { buyer: tx-sender, material-id: material-id }))
      (current-time-option (get-block-info? time (- block-height u1)))
      (material-option (map-get? learning-materials { material-id: material-id }))
      (extension-duration u15768000) ;; Extend for another 6 months
    )
    
    ;; Validate material ID
    (asserts! (validate-material-id material-id) ERR-INVALID-INPUT)
    
    ;; Check if purchase exists, time is available, and material exists
    (asserts! (is-some purchase-option) ERR-NOT-FOUND)
    (asserts! (is-some current-time-option) ERR-NOT-FOUND)
    (asserts! (is-some material-option) ERR-NOT-FOUND)
    
    (let 
      (
        (purchase (unwrap-panic purchase-option))
        (material (unwrap-panic material-option))
      )
      
      ;; Check if material is active
      (asserts! (get is-active material) ERR-INACTIVE)
      
      (let
        (
          (creator (get creator material))
          (price (get price material))
          (platform-fee (calculate-platform-fee price))
          (creator-amount (- price platform-fee))
          (current-expiry (get access-expires purchase))
          (new-expiry (+ current-expiry extension-duration))
        )
        
        ;; Transfer funds from buyer to creator
        (let ((transfer-creator-result (stx-transfer? creator-amount tx-sender creator)))
          (asserts! (is-ok transfer-creator-result) ERR-INSUFFICIENT-BALANCE)
          
          ;; Transfer funds from buyer to platform
          (let ((transfer-platform-result (stx-transfer? platform-fee tx-sender contract-owner)))
            (asserts! (is-ok transfer-platform-result) ERR-INSUFFICIENT-BALANCE)
            
            ;; Update the expiry
            (map-set purchases
              { buyer: tx-sender, material-id: material-id }
              { 
                purchased-at: (get purchased-at purchase),
                access-expires: new-expiry 
              }
            )
            
            (ok true)
          )
        )
      )
    )
  )
)

;; Read-only functions

;; Get material details
(define-read-only (get-material (material-id uint))
  (map-get? learning-materials { material-id: material-id })
)

;; Get materials by creator
(define-read-only (get-creator-materials (creator principal))
  (map-get? creator-materials { creator: creator })
)

;; Get purchased materials by buyer
(define-read-only (get-buyer-materials (buyer principal))
  (map-get? buyer-materials { buyer: buyer })
)

;; Get purchase details
(define-read-only (get-purchase-details (buyer principal) (material-id uint))
  (map-get? purchases { buyer: buyer, material-id: material-id })
)

;; Check if access to a material is still valid
(define-read-only (is-access-valid (buyer principal) (material-id uint))
  (let
    ((purchase (map-get? purchases { buyer: buyer, material-id: material-id }))
     (current-time (get-block-info? time (- block-height u1))))
    
    (match purchase
      existing-purchase (and 
                          (is-some current-time)
                          (>= (get access-expires existing-purchase)
                              (default-to u0 current-time)))
      false)
  )
)

;; Admin functions

;; Set platform fee
(define-public (set-platform-fee (new-fee-basis-points uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
    ;; Ensure fee isn't too high (max 25%)
    (asserts! (<= new-fee-basis-points u2500) ERR-INVALID-PRICE)
    (var-set platform-fee-basis-points new-fee-basis-points)
    (ok true)
  )
)

;; Withdraw STX from contract if needed (emergency function)
(define-public (withdraw-stx (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-BALANCE)
    (as-contract (stx-transfer? amount tx-sender contract-owner))
  )
)