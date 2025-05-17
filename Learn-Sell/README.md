# Learning Material Marketplace Smart Contract

## Overview

This Clarity smart contract enables a decentralized marketplace for learning materials on the Stacks blockchain. It allows creators to publish and sell educational content while enabling users to purchase access to these materials. The contract handles the financial transactions between creators and buyers, maintains access rights, and manages a small platform fee.

## Features

- **Content Creation**: Creators can publish learning materials with title, description, price, and category
- **Content Management**: Creators can update or deactivate their materials
- **Purchasing System**: Users can buy access to learning materials with STX tokens
- **Access Control**: The contract tracks and validates user access rights
- **Access Extension**: Users can extend their access for an additional period
- **Platform Fee**: A configurable fee is collected on each transaction

## Data Structures

### Learning Materials

Stores information about each learning material:
- Creator's address
- Title (up to 100 ASCII characters)
- Description (up to 500 UTF-8 characters)
- Price (in microSTX)
- Category (up to 50 ASCII characters)
- Creation timestamp
- Active status

### Creator Materials

Tracks all materials created by each creator:
- List of material IDs (up to 100 entries)

### Purchases

Records purchase information:
- Buyer's address
- Material ID
- Purchase timestamp
- Access expiration timestamp

### Buyer Materials

Tracks all materials purchased by each buyer:
- List of material IDs (up to 100 entries)

## Constants & Error Codes

- `ERR-OWNER-ONLY (u100)`: Operation restricted to contract owner
- `ERR-NOT-FOUND (u101)`: The requested resource doesn't exist
- `ERR-ALREADY-EXISTS (u102)`: Resource already exists
- `ERR-UNAUTHORIZED (u103)`: Caller not authorized for this action
- `ERR-INSUFFICIENT-BALANCE (u104)`: Insufficient funds for transaction
- `ERR-INVALID-PRICE (u105)`: Invalid price specified
- `ERR-INACTIVE (u106)`: Material is inactive/deactivated

## Public Functions

### For Creators

#### `create-material`
```clarity
(create-material title description price category)
```
Publishes a new learning material. Returns the created material ID.

Parameters:
- `title`: String (ASCII, max 100 chars)
- `description`: String (UTF-8, max 500 chars)
- `price`: Integer (microSTX)
- `category`: String (ASCII, max 50 chars)

#### `update-material`
```clarity
(update-material material-id title description price category)
```
Updates an existing material's details. Only the original creator can update.

Parameters:
- `material-id`: Integer (material ID)
- `title`: String (ASCII, max 100 chars)
- `description`: String (UTF-8, max 500 chars)
- `price`: Integer (microSTX)
- `category`: String (ASCII, max 50 chars)

#### `deactivate-material`
```clarity
(deactivate-material material-id)
```
Deactivates a material (making it unavailable for purchase). Can be called by the creator or contract owner.

Parameters:
- `material-id`: Integer (material ID)

### For Buyers

#### `purchase-material`
```clarity
(purchase-material material-id)
```
Purchases access to a specific learning material for 6 months.

Parameters:
- `material-id`: Integer (material ID)

#### `extend-access`
```clarity
(extend-access material-id)
```
Extends access to a previously purchased material for an additional 6 months.

Parameters:
- `material-id`: Integer (material ID)

### For Admin

#### `set-platform-fee`
```clarity
(set-platform-fee new-fee-basis-points)
```
Updates the platform fee percentage (in basis points, where 100 = 1%). Only contract owner can call.

Parameters:
- `new-fee-basis-points`: Integer (max 2500 = 25%)

#### `withdraw-stx`
```clarity
(withdraw-stx amount)
```
Emergency function to withdraw STX from the contract. Only contract owner can call.

Parameters:
- `amount`: Integer (microSTX)

## Read-Only Functions

#### `get-material`
```clarity
(get-material material-id)
```
Returns details about a specific material.

#### `get-creator-materials`
```clarity
(get-creator-materials creator)
```
Returns a list of material IDs created by a specific address.

#### `get-buyer-materials`
```clarity
(get-buyer-materials buyer)
```
Returns a list of material IDs purchased by a specific address.

#### `get-purchase-details`
```clarity
(get-purchase-details buyer material-id)
```
Returns purchase details for a specific buyer and material.

#### `is-access-valid`
```clarity
(is-access-valid buyer material-id)
```
Checks if a buyer's access to a material is still valid (not expired).

#### `has-purchased`
```clarity
(has-purchased buyer material-id)
```
Checks if a buyer has purchased a specific material.

#### `is-valid-material`
```clarity
(is-valid-material material-id)
```
Checks if a material exists and is active.

## Implementation Details

- Access duration is set to 6 months (15,768,000 seconds)
- Platform fee is set to 2.5% by default (250 basis points)
- Maximum platform fee is capped at 25% (2500 basis points)
- Each creator and buyer can have up to 100 materials in their lists

## Transaction Flow

1. When a buyer purchases a material:
   - The platform fee is calculated and subtracted from the price
   - The majority of the payment is transferred to the creator
   - The platform fee is transferred to the contract owner
   - The purchase is recorded with an expiration timestamp
   - The material ID is added to the buyer's list of purchased materials

2. When a buyer extends access:
   - The same payment split occurs between creator and platform
   - The expiration timestamp is extended by another 6 months

## Security Considerations

- Only the material creator can update their materials
- Only the creator or contract owner can deactivate materials
- Only the contract owner can change the platform fee or withdraw funds
- Material prices must be greater than zero
- Platform fee is capped at 25% to prevent abuse

## Limitations

- Each creator can publish up to 100 materials
- Each buyer can purchase up to 100 materials
- Material titles are limited to 100 ASCII characters
- Material descriptions are limited to 500 UTF-8 characters
- Categories are limited to 50 ASCII characters

## Usage Examples

### For Creators

```clarity
;; Create a new programming course
(contract-call? .learning-material-marketplace create-material "Introduction to Blockchain" "Learn the fundamentals of blockchain technology" u50000000 "Programming")

;; Update course details
(contract-call? .learning-material-marketplace update-material u1 "Blockchain Fundamentals" "Comprehensive introduction to blockchain technology and its applications" u55000000 "Technology")

;; Deactivate a course
(contract-call? .learning-material-marketplace deactivate-material u1)
```

### For Buyers

```clarity
;; Purchase access to a course
(contract-call? .learning-material-marketplace purchase-material u1)

;; Extend access to a course
(contract-call? .learning-material-marketplace extend-access u1)

;; Check if access is still valid
(contract-call? .learning-material-marketplace is-access-valid tx-sender u1)
```

### For Admin

```clarity
;; Update platform fee to 3%
(contract-call? .learning-material-marketplace set-platform-fee u300)
```