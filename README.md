<!-- foundation:identity -->
# Emberfield Roast

Online storefront for a small coffee roaster: a catalog of coffees with photos and prices, a cart, checkout, and order history for signed-in customers.

- Site: https://emberfield-roast.api.holode.xyz
- Support: support@emberfield-roast.api.holode.xyz
<!-- /foundation:identity -->

## What this is

Online storefront for a small coffee roaster: a catalog of coffees with photos and prices, a cart, checkout, and order history for signed-in customers.

## Who it is for

- Guest shopper (browses, carts, checks out with email)
- Signed-in customer (sees past orders and order details)
- Owner/admin (manages products and orders)

## Main features

- **Browse catalog** — Visitor sees the product grid with photos, roast level, origin, and price
- **Cart** — Add items, adjust quantities, see running total
- **Checkout** — Guest enters email or signs in; order completes through the local test payment simulator in preview; signed-in customers get the receipt in their account
- **Order history** — Signed-in customer views past orders and their items and totals
- **Admin manage catalog and orders** — Owner adds/edits products (photo, price, roast, origin) and views orders

## Core entities

- Product
- Order
- OrderItem
- Customer (User)

## Included foundation modules

- storefront

## Run locally

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Requires Ruby, PostgreSQL, and the usual Rails toolchain. See `bin/setup` if present.

## Demo

Six coffees with Unsplash photos, USD prices, roast levels (light/medium/dark) and origins; one demo signed-in customer with a past order so order history is visible.

## Deploy notes

Production `config.hosts` is derived from `domain` in `config/foundation.yml`. Keep that value aligned with the real host or every request will 403.
