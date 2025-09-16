# ReviewChain: Decentralized Product Review Platform

A blockchain-powered review ecosystem that enables transparent product cataloging, authentic customer feedback collection, and tamper-proof review aggregation. Features include immutable review storage, real-time analytics, paginated browsing, and decentralized governance with community-driven moderation capabilities.

## Overview

ReviewChain is a smart contract built for the Stacks blockchain that provides a decentralized platform for product reviews. The system ensures data integrity, prevents tampering, and offers transparent review management while maintaining user privacy and platform governance.

## Features

- **Immutable Review Storage**: All reviews are permanently stored on the blockchain
- **Product Management**: Complete product lifecycle management with metadata
- **Real-time Analytics**: Automatic calculation of ratings and review statistics
- **Paginated Browsing**: Efficient pagination system for large review datasets
- **Access Control**: Role-based permissions for different platform operations
- **Data Validation**: Comprehensive input validation and error handling

## Architecture

### Data Structures

#### Products
- **Product Registry**: Core product information including name, description, creator, and status
- **Product Statistics**: Real-time metrics including review count and total rating points
- **Pagination Index**: Organized review storage for efficient browsing

#### Reviews
- **Customer Reviews**: Complete review data with ratings, content, and metadata
- **Product-Review Mapping**: Relationship tracking between products and their reviews

### Constants and Limits

```clarity
- Rating Range: 1-5 stars
- Reviews per Page: 20 reviews
- Product Name Limit: 50 characters
- Description Limit: 500 characters
```

## Functions

### Product Management

#### `register-new-product`
```clarity
(register-new-product (product-name (string-ascii 50)) (product-description (string-ascii 500)))
```
- **Access**: Platform Administrator only
- **Purpose**: Register a new product in the system
- **Returns**: Success confirmation or error code

#### `modify-product-details`
```clarity
(modify-product-details (product-identifier uint) (new-name (string-ascii 50)) (new-description (string-ascii 500)) (active-status bool))
```
- **Access**: Platform Administrator or Product Creator
- **Purpose**: Update existing product information
- **Returns**: Success confirmation or error code

### Review Management

#### `submit-product-review`
```clarity
(submit-product-review (product-identifier uint) (user-rating uint) (review-text (string-ascii 500)) (is-verified-purchase bool))
```
- **Access**: Any user
- **Purpose**: Submit a new review for a product
- **Returns**: New review ID or error code

#### `modify-submitted-review`
```clarity
(modify-submitted-review (review-identifier uint) (updated-rating uint) (updated-content (string-ascii 500)))
```
- **Access**: Review Author only
- **Purpose**: Update an existing review
- **Returns**: Success confirmation or error code

#### `delete-customer-review`
```clarity
(delete-customer-review (review-identifier uint))
```
- **Access**: Platform Administrator or Review Author
- **Purpose**: Remove a review from the system
- **Returns**: Success confirmation or error code

### Data Retrieval (Read-Only)

#### `get-product-information`
```clarity
(get-product-information (product-identifier uint))
```
Returns complete product details including name, description, creator, creation block, and active status.

#### `get-review-information`
```clarity
(get-review-information (review-identifier uint))
```
Returns complete review details including target product, author, rating, content, submission block, and verification status.

#### `get-product-performance-data`
```clarity
(get-product-performance-data (product-identifier uint))
```
Returns analytics data including total review count and cumulative rating points.

#### `calculate-average-product-rating`
```clarity
(calculate-average-product-rating (product-identifier uint))
```
Calculates and returns the average rating for a specific product.

#### `get-reviews-for-page`
```clarity
(get-reviews-for-page (product-identifier uint) (page-number uint))
```
Returns a list of review IDs for the specified page of a product's reviews.

#### `get-detailed-reviews-for-page`
```clarity
(get-detailed-reviews-for-page (product-identifier uint) (page-number uint))
```
Returns complete review details for all reviews on a specific page.

### Administration

#### `transfer-platform-ownership`
```clarity
(transfer-platform-ownership (new-administrator principal))
```
- **Access**: Current Platform Administrator only
- **Purpose**: Transfer administrative privileges to a new principal
- **Returns**: Success confirmation or error code

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| u2 | ERR-PRODUCT-NOT-FOUND | Referenced product does not exist |
| u3 | ERR-INSUFFICIENT-PERMISSIONS | Insufficient rights for operation |
| u4 | ERR-INVALID-RATING-SCORE | Rating outside valid range (1-5) |
| u5 | ERR-REVIEW-NOT-FOUND | Referenced review does not exist |
| u6 | ERR-PRODUCT-ALREADY-EXISTS | Product registration conflict |
| u7 | ERR-PRODUCT-INACTIVE | Operation on inactive product |
| u8 | ERR-OPERATION-FAILED | General operation failure |
| u9 | ERR-INVALID-PAGE-NUMBER | Page number out of range |
| u10 | ERR-INVALID-INPUT-DATA | Invalid input parameters |
| u11 | ERR-PRODUCT-NAME-TOO-LONG | Product name exceeds limit |
| u12 | ERR-DESCRIPTION-TOO-LONG | Description exceeds limit |
| u13 | ERR-INVALID-PRODUCT-ID | Invalid product identifier |
| u14 | ERR-INVALID-REVIEW-ID | Invalid review identifier |

## Usage Examples

### Registering a Product
```clarity
(contract-call? .reviewchain register-new-product "Wireless Headphones" "High-quality bluetooth headphones with noise cancellation")
```

### Submitting a Review
```clarity
(contract-call? .reviewchain submit-product-review u1 u5 "Excellent sound quality and comfortable fit!" true)
```

### Retrieving Product Information
```clarity
(contract-call? .reviewchain get-product-information u1)
```

### Getting Reviews for a Product
```clarity
(contract-call? .reviewchain get-detailed-reviews-for-page u1 u0)
```

## Deployment

1. Deploy the contract to the Stacks blockchain
2. The deploying principal automatically becomes the platform administrator
3. Begin registering products using the `register-new-product` function
4. Users can immediately start submitting reviews for active products

## Security Considerations

- All critical operations include comprehensive input validation
- Access controls prevent unauthorized modifications
- Review authenticity is maintained through blockchain immutability
- Platform governance is centralized but transferable
- Data integrity is enforced at the contract level

## Gas Optimization

- Efficient data structures minimize storage costs
- Pagination reduces query complexity
- Batch operations where possible
- Optimized validation functions