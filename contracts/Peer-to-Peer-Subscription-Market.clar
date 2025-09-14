(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u104))
(define-constant ERR_INVALID_DURATION (err u105))
(define-constant ERR_CANNOT_SUBSCRIBE_OWN_CONTENT (err u106))

(define-constant ERR_GIFT_NOT_FOUND (err u107))
(define-constant ERR_GIFT_ALREADY_CLAIMED (err u108))
(define-constant ERR_CANNOT_GIFT_TO_SELF (err u109))

(define-constant ERR_TRANSFER_NOT_FOUND (err u110))
(define-constant ERR_INVALID_TRANSFER_OFFER (err u111))
(define-constant ERR_CANNOT_TRANSFER_TO_SELF (err u112))
(define-constant ERR_INSUFFICIENT_TIME_REMAINING (err u113))

(define-data-var next-offer-id uint u1)
(define-data-var transfer-fee-percentage uint u2)

(define-map content-items
  { content-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    price: uint,
    content-hash: (string-ascii 64),
    created-at: uint,
    is-active: bool
  }
)

(define-map subscriptions
  { subscriber: principal, content-id: uint }
  {
    expires-at: uint,
    purchased-at: uint,
    amount-paid: uint
  }
)

(define-map creator-earnings
  { creator: principal }
  { total-earned: uint }
)

(define-data-var next-content-id uint u1)
(define-data-var platform-fee-percentage uint u5)

(define-public (create-content (title (string-ascii 100)) (description (string-ascii 500)) (price uint) (content-hash (string-ascii 64)))
  (let
    (
      (content-id (var-get next-content-id))
      (current-block stacks-block-height)
    )
    (asserts! (> price u0) ERR_INSUFFICIENT_PAYMENT)
    (asserts! (> (len title) u0) ERR_NOT_FOUND)
    (asserts! (> (len content-hash) u0) ERR_NOT_FOUND)
    
    (map-set content-items
      { content-id: content-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        price: price,
        content-hash: content-hash,
        created-at: current-block,
        is-active: true
      }
    )
    
    (var-set next-content-id (+ content-id u1))
    (ok content-id)
  )
)
(define-public (purchase-subscription (content-id uint) (duration-blocks uint))
  (let
    (
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (expires-at (+ current-block duration-blocks))
      (total-cost (* (get price content-info) (/ duration-blocks u144)))
      (platform-fee (/ (* total-cost (var-get platform-fee-percentage)) u100))
      (creator-payment (- total-cost platform-fee))
      (creator (get creator content-info))
    )
    (asserts! (get is-active content-info) ERR_NOT_FOUND)
    (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)
    (asserts! (not (is-eq tx-sender creator)) ERR_CANNOT_SUBSCRIBE_OWN_CONTENT)
    
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
    
    (map-set subscriptions
      { subscriber: tx-sender, content-id: content-id }
      {
        expires-at: expires-at,
        purchased-at: current-block,
        amount-paid: total-cost
      }
    )
    
    (map-set creator-earnings
      { creator: creator }
      {
        total-earned: (+ creator-payment 
          (default-to u0 (get total-earned (map-get? creator-earnings { creator: creator }))))
      }
    )
    
    (ok expires-at)
  )
)
(define-public (toggle-content-status (content-id uint))
  (let
    (
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator content-info)) ERR_NOT_AUTHORIZED)
    
    (map-set content-items
      { content-id: content-id }
      (merge content-info { is-active: (not (get is-active content-info)) })
    )
    (ok (not (get is-active content-info)))
  )
)

(define-public (update-content-price (content-id uint) (new-price uint))
  (let
    (
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator content-info)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-price u0) ERR_INSUFFICIENT_PAYMENT)
    
    (map-set content-items
      { content-id: content-id }
      (merge content-info { price: new-price })
    )
    (ok new-price)
  )
)

(define-public (extend-subscription (content-id uint) (additional-blocks uint))
  (let
    (
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
      (subscription-info (unwrap! (map-get? subscriptions { subscriber: tx-sender, content-id: content-id }) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (current-expires-at (get expires-at subscription-info))
      (new-expires-at (+ current-expires-at additional-blocks))
      (extension-cost (* (get price content-info) (/ additional-blocks u144)))
      (platform-fee (/ (* extension-cost (var-get platform-fee-percentage)) u100))
      (creator-payment (- extension-cost platform-fee))
      (creator (get creator content-info))
    )
    (asserts! (get is-active content-info) ERR_NOT_FOUND)
    (asserts! (> additional-blocks u0) ERR_INVALID_DURATION)
    
    (try! (stx-transfer? extension-cost tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
    
    (map-set subscriptions
      { subscriber: tx-sender, content-id: content-id }
      (merge subscription-info { 
        expires-at: new-expires-at,
        amount-paid: (+ (get amount-paid subscription-info) extension-cost)
      })
    )
    
    (map-set creator-earnings
      { creator: creator }
      {
        total-earned: (+ creator-payment 
          (default-to u0 (get total-earned (map-get? creator-earnings { creator: creator }))))
      }
    )
    
    (ok new-expires-at)
  )
)
(define-public (set-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee-percentage u20) ERR_NOT_AUTHORIZED)
    (var-set platform-fee-percentage new-fee-percentage)
    (ok new-fee-percentage)
  )
)

(define-read-only (get-content-info (content-id uint))
  (map-get? content-items { content-id: content-id })
)

(define-read-only (get-subscription-info (subscriber principal) (content-id uint))
  (map-get? subscriptions { subscriber: subscriber, content-id: content-id })
)

(define-read-only (has-valid-subscription (subscriber principal) (content-id uint))
  (match (map-get? subscriptions { subscriber: subscriber, content-id: content-id })
    subscription-info (> (get expires-at subscription-info) stacks-block-height)
    false
  )
)

(define-read-only (get-creator-earnings (creator principal))
  (default-to { total-earned: u0 } (map-get? creator-earnings { creator: creator }))
)

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

(define-read-only (get-next-content-id)
  (var-get next-content-id)
)

(define-read-only (can-access-content (subscriber principal) (content-id uint))
  (let
    (
      (content-info (map-get? content-items { content-id: content-id }))
    )
    (match content-info
      content
      (if (is-eq subscriber (get creator content))
        true
        (has-valid-subscription subscriber content-id)
      )
      false
    )
  )
)

(define-read-only (get-subscription-time-remaining (subscriber principal) (content-id uint))
  (match (map-get? subscriptions { subscriber: subscriber, content-id: content-id })
    subscription-info 
    (let
      (
        (current-block stacks-block-height)
        (expires-at (get expires-at subscription-info))
      )
      (if (> expires-at current-block)
        (some (- expires-at current-block))
        (some u0)
      )
    )
    none
  )
)

(define-read-only (calculate-subscription-cost (content-id uint) (duration-blocks uint))
  (match (map-get? content-items { content-id: content-id })
    content-info
    (let
      (
        (base-cost (* (get price content-info) (/ duration-blocks u144)))
        (platform-fee (/ (* base-cost (var-get platform-fee-percentage)) u100))
      )
      (some { 
        total-cost: base-cost,
        creator-payment: (- base-cost platform-fee),
        platform-fee: platform-fee
      })
    )
    none
  )
)


(define-map gift-subscriptions
  { gift-id: uint }
  {
    gifter: principal,
    recipient: principal,
    content-id: uint,
    duration-blocks: uint,
    message: (string-ascii 200),
    created-at: uint,
    is-claimed: bool
  }
)

(define-data-var next-gift-id uint u1)

(define-public (gift-subscription (recipient principal) (content-id uint) (duration-blocks uint) (message (string-ascii 200)))
  (let
    (
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
      (gift-id (var-get next-gift-id))
      (current-block stacks-block-height)
      (total-cost (* (get price content-info) (/ duration-blocks u144)))
      (platform-fee (/ (* total-cost (var-get platform-fee-percentage)) u100))
      (creator-payment (- total-cost platform-fee))
      (creator (get creator content-info))
    )
    (asserts! (get is-active content-info) ERR_NOT_FOUND)
    (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)
    (asserts! (not (is-eq tx-sender recipient)) ERR_CANNOT_GIFT_TO_SELF)
    (asserts! (not (is-eq recipient creator)) ERR_CANNOT_SUBSCRIBE_OWN_CONTENT)
    
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
    
    (map-set gift-subscriptions
      { gift-id: gift-id }
      {
        gifter: tx-sender,
        recipient: recipient,
        content-id: content-id,
        duration-blocks: duration-blocks,
        message: message,
        created-at: current-block,
        is-claimed: false
      }
    )
    
    (map-set creator-earnings
      { creator: creator }
      {
        total-earned: (+ creator-payment 
          (default-to u0 (get total-earned (map-get? creator-earnings { creator: creator }))))
      }
    )
    
    (var-set next-gift-id (+ gift-id u1))
    (ok gift-id)
  )
)

(define-public (claim-gift (gift-id uint))
  (let
    (
      (gift-info (unwrap! (map-get? gift-subscriptions { gift-id: gift-id }) ERR_GIFT_NOT_FOUND))
      (current-block stacks-block-height)
      (expires-at (+ current-block (get duration-blocks gift-info)))
      (content-id (get content-id gift-info))
    )
    (asserts! (is-eq tx-sender (get recipient gift-info)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-claimed gift-info)) ERR_GIFT_ALREADY_CLAIMED)
    
    (map-set gift-subscriptions
      { gift-id: gift-id }
      (merge gift-info { is-claimed: true })
    )
    
    (map-set subscriptions
      { subscriber: tx-sender, content-id: content-id }
      {
        expires-at: expires-at,
        purchased-at: current-block,
        amount-paid: u0
      }
    )
    
    (ok expires-at)
  )
)

(define-read-only (get-gift-info (gift-id uint))
  (map-get? gift-subscriptions { gift-id: gift-id })
)

(define-read-only (get-pending-gifts (recipient principal))
  (filter is-unclaimed-gift (map get-gift-with-id (list-gifts)))
)

(define-private (is-unclaimed-gift (gift-entry {gift-id: uint, gift-info: (optional {gifter: principal, recipient: principal, content-id: uint, duration-blocks: uint, message: (string-ascii 200), created-at: uint, is-claimed: bool})}))
  (match (get gift-info gift-entry)
    gift-data (and (not (get is-claimed gift-data)) (is-eq (get recipient gift-data) tx-sender))
    false
  )
)

(define-private (get-gift-with-id (gift-id uint))
  { gift-id: gift-id, gift-info: (map-get? gift-subscriptions { gift-id: gift-id }) }
)

(define-private (list-gifts)
  (map uint-to-gift (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
)

(define-private (uint-to-gift (n uint))
  n
)


(define-map subscription-transfer-offers
  { offer-id: uint }
  {
    seller: principal,
    content-id: uint,
    blocks-for-sale: uint,
    asking-price: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-public (list-subscription-for-transfer (content-id uint) (blocks-for-sale uint) (asking-price uint))
  (let
    (
      (subscription-info (unwrap! (map-get? subscriptions { subscriber: tx-sender, content-id: content-id }) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (expires-at (get expires-at subscription-info))
      (remaining-blocks (- expires-at current-block))
      (offer-id (var-get next-offer-id))
    )
    (asserts! (> expires-at current-block) ERR_SUBSCRIPTION_EXPIRED)
    (asserts! (>= remaining-blocks blocks-for-sale) ERR_INSUFFICIENT_TIME_REMAINING)
    (asserts! (> blocks-for-sale u0) ERR_INVALID_DURATION)
    (asserts! (> asking-price u0) ERR_INSUFFICIENT_PAYMENT)
    
    (map-set subscription-transfer-offers
      { offer-id: offer-id }
      {
        seller: tx-sender,
        content-id: content-id,
        blocks-for-sale: blocks-for-sale,
        asking-price: asking-price,
        created-at: current-block,
        is-active: true
      }
    )
    
    (var-set next-offer-id (+ offer-id u1))
    (ok offer-id)
  )
)

(define-public (purchase-subscription-transfer (offer-id uint))
  (let
    (
      (offer-info (unwrap! (map-get? subscription-transfer-offers { offer-id: offer-id }) ERR_TRANSFER_NOT_FOUND))
      (content-id (get content-id offer-info))
      (seller (get seller offer-info))
      (blocks-for-sale (get blocks-for-sale offer-info))
      (asking-price (get asking-price offer-info))
      (seller-subscription (unwrap! (map-get? subscriptions { subscriber: seller, content-id: content-id }) ERR_NOT_FOUND))
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (seller-expires-at (get expires-at seller-subscription))
      (transfer-fee (/ (* asking-price (var-get transfer-fee-percentage)) u100))
      (seller-payment (- asking-price transfer-fee))
      (creator (get creator content-info))
      (buyer-current-subscription (map-get? subscriptions { subscriber: tx-sender, content-id: content-id }))
    )
    (asserts! (get is-active offer-info) ERR_TRANSFER_NOT_FOUND)
    (asserts! (not (is-eq tx-sender seller)) ERR_CANNOT_TRANSFER_TO_SELF)
    (asserts! (> seller-expires-at current-block) ERR_SUBSCRIPTION_EXPIRED)
    (asserts! (>= (- seller-expires-at current-block) blocks-for-sale) ERR_INSUFFICIENT_TIME_REMAINING)
    
    (try! (stx-transfer? seller-payment tx-sender seller))
    (try! (stx-transfer? transfer-fee tx-sender creator))
    
    (map-set subscription-transfer-offers
      { offer-id: offer-id }
      (merge offer-info { is-active: false })
    )
    
    (map-set subscriptions
      { subscriber: seller, content-id: content-id }
      (merge seller-subscription { expires-at: (- seller-expires-at blocks-for-sale) })
    )
    
    (match buyer-current-subscription
      existing-sub (map-set subscriptions
        { subscriber: tx-sender, content-id: content-id }
        (merge existing-sub { expires-at: (+ (get expires-at existing-sub) blocks-for-sale) })
      )
      (map-set subscriptions
        { subscriber: tx-sender, content-id: content-id }
        {
          expires-at: (+ current-block blocks-for-sale),
          purchased-at: current-block,
          amount-paid: asking-price
        }
      )
    )
    
    (map-set creator-earnings
      { creator: creator }
      {
        total-earned: (+ transfer-fee
          (default-to u0 (get total-earned (map-get? creator-earnings { creator: creator }))))
      }
    )
    
    (ok (+ current-block blocks-for-sale))
  )
)

(define-public (cancel-transfer-offer (offer-id uint))
  (let
    (
      (offer-info (unwrap! (map-get? subscription-transfer-offers { offer-id: offer-id }) ERR_TRANSFER_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get seller offer-info)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active offer-info) ERR_TRANSFER_NOT_FOUND)
    
    (map-set subscription-transfer-offers
      { offer-id: offer-id }
      (merge offer-info { is-active: false })
    )
    (ok true)
  )
)

(define-read-only (get-transfer-offer (offer-id uint))
  (map-get? subscription-transfer-offers { offer-id: offer-id })
)

(define-read-only (get-transfer-fee-percentage)
  (var-get transfer-fee-percentage)
)

(define-map content-analytics
  { content-id: uint }
  {
    total-subscribers: uint,
    active-subscribers: uint,
    total-revenue: uint,
    average-subscription-duration: uint,
    last-updated: uint
  }
)

(define-map monthly-metrics
  { year-month: uint, content-id: uint }
  {
    new-subscribers: uint,
    churned-subscribers: uint,
    revenue: uint,
    avg-price: uint
  }
)

(define-map creator-analytics
  { creator: principal }
  {
    total-content-items: uint,
    monthly-recurring-revenue: uint,
    subscriber-growth-rate: uint,
    top-performing-content: uint,
    last-calculated: uint
  }
)

(define-data-var analytics-enabled bool true)

(define-public (update-content-analytics (content-id uint))
  (let
    (
      (current-block stacks-block-height)
      (current-month (/ current-block u4320))
      (content-info (unwrap! (map-get? content-items { content-id: content-id }) ERR_NOT_FOUND))
      (creator (get creator content-info))
    )
    (asserts! (var-get analytics-enabled) ERR_NOT_AUTHORIZED)
    
    (let
      (
        (active-count (calculate-active-subscribers content-id))
        (total-revenue (calculate-total-revenue content-id))
        (avg-duration (calculate-avg-duration content-id))
      )
      (map-set content-analytics
        { content-id: content-id }
        {
          total-subscribers: (get-total-subscriber-count content-id),
          active-subscribers: active-count,
          total-revenue: total-revenue,
          average-subscription-duration: avg-duration,
          last-updated: current-block
        }
      )
      
      (update-creator-analytics creator)
      (ok true)
    )
  )
)

(define-private (calculate-active-subscribers (content-id uint))
  u0
)

(define-private (calculate-total-revenue (content-id uint))
  u0
)

(define-private (calculate-avg-duration (content-id uint))
  u144
)

(define-private (get-total-subscriber-count (content-id uint))
  u0
)

(define-private (calculate-creator-mrr (creator principal))
  u0
)

(define-private (calculate-growth-rate (creator principal))
  u0
)

(define-private (get-top-performing-content (creator principal))
  u0
)

(define-private (get-creator-content-count (creator principal))
  u0
)

(define-private (calculate-platform-avg-price)
  u0
)

(define-private (get-top-creators-list)
  (list)
)

(define-private (count-all-active (acc uint) (n uint))
  acc
)

(define-private (sum-all-revenue (acc uint) (n uint))
  acc
)

(define-private (update-creator-analytics (creator principal))
  (let
    (
      (current-mrr (calculate-creator-mrr creator))
      (growth-rate (calculate-growth-rate creator))
      (top-content (get-top-performing-content creator))
      (content-count (get-creator-content-count creator))
    )
    (map-set creator-analytics
      { creator: creator }
      {
        total-content-items: content-count,
        monthly-recurring-revenue: current-mrr,
        subscriber-growth-rate: growth-rate,
        top-performing-content: top-content,
        last-calculated: stacks-block-height
      }
    )
  )
)

(define-read-only (get-content-analytics (content-id uint))
  (map-get? content-analytics { content-id: content-id })
)

(define-read-only (get-creator-analytics (creator principal))
  (map-get? creator-analytics { creator: creator })
)

(define-read-only (get-platform-metrics)
  {
    total-active-subscriptions: u0,
    total-revenue: u0,
    average-subscription-price: (calculate-platform-avg-price),
    top-creators: (get-top-creators-list)
  }
)