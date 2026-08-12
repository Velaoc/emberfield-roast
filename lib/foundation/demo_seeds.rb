# frozen_string_literal: true

module Foundation
  # Optional demo catalog rows (SPEC M10.3).
  #
  # The application boots and serves every page with an empty database, so no
  # seed is ever required. These rows exist only to make the storefront and
  # checkout walkable on a developer machine or in a hosted preview, and they
  # are refused everywhere else — a production deployment must never find
  # invented products in its catalog.
  module DemoSeeds
    PRODUCTS = [
      {
        slug: "sunrise-blend", sku: "EMB-SUNRISE", name: "Sunrise Blend",
        description: "A bright, juicy morning cup. Stone fruit, honey, and a clean finish — our lightest everyday roast, built for pour-over.",
        price_cents: 1_600, position: 0, inventory_quantity: 100,
        roast_level: "Light", origin: "Ethiopia · Yirgacheffe",
        image_url: "https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=900&q=80"
      },
      {
        slug: "emberfield-espresso", sku: "EMB-ESPRESSO", name: "Emberfield Espresso",
        description: "Our signature shot: dark cocoa, toasted hazelnut, and brown sugar. Medium-dark roast pulled for milk drinks or straight.",
        price_cents: 1_800, position: 1, inventory_quantity: 100,
        roast_level: "Medium-dark", origin: "Brazil · Minas Gerais",
        image_url: "https://images.unsplash.com/photo-1447933601403-0c6688de566e?w=900&q=80"
      },
      {
        slug: "highland-bourbon", sku: "EMB-HIGHLAND", name: "Highland Bourbon",
        description: "A balanced single origin with red apple, caramel, and a silky body. Medium roast from the Huila highlands.",
        price_cents: 1_750, position: 2, inventory_quantity: 100,
        roast_level: "Medium", origin: "Colombia · Huila",
        image_url: "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=900&q=80"
      },
      {
        slug: "midnight-city", sku: "EMB-MIDNIGHT", name: "Midnight City",
        description: "A heavy, low-acid dark roast. Molasses, cedar, and dark chocolate — made for cold brew and long mornings.",
        price_cents: 1_550, position: 3, inventory_quantity: 100,
        roast_level: "Dark", origin: "Sumatra · Aceh",
        image_url: "https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=900&q=80"
      },
      {
        slug: "golden-hour-decaf", sku: "EMB-GOLDEN", name: "Golden Hour Decaf",
        description: "Swiss-water decaf that still tastes like coffee: toasted grain, milk chocolate, and a round, gentle finish.",
        price_cents: 1_650, position: 4, inventory_quantity: 100,
        roast_level: "Medium", origin: "Colombia · SWP Decaf",
        image_url: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=900&q=80"
      },
      {
        slug: "windward-geisha", sku: "EMB-WINDWARD", name: "Windward Geisha",
        description: "Our small-lot showpiece: jasmine, bergamot, and peach tea. A delicate light roast, roasted in 5 kg batches every Friday.",
        price_cents: 2_800, position: 5, inventory_quantity: 30,
        roast_level: "Light", origin: "Panama · Boquete",
        image_url: "https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=900&q=80"
      }
    ].freeze

    DEMO_CUSTOMER_EMAIL = "demo@emberfield.roast"
    DEMO_CUSTOMER_PASSWORD = "password123"

    # Development or a hosted preview only. Preview runs in the production
    # Rails environment, so the preview flag — not RAILS_ENV alone — is what
    # separates a disposable demo from a real deployment.
    def self.permitted?(rails_env: Rails.env, preview: Foundation.preview?)
      rails_env.development? || preview
    end

    def self.run!(io: $stdout)
      unless permitted?
        io.puts("Skipping demo seeds: they are limited to development and hosted previews.")
        return 0
      end

      unless Foundation.storefront_enabled?
        io.puts("Skipping demo seeds: the storefront is disabled in config/foundation.yml.")
        return 0
      end

      created = seed_products!
      customer = seed_demo_customer!
      io.puts("Demo catalog ready: #{PRODUCTS.length} products (#{created} created). Demo customer: #{customer}.")
      created
    end

    # Upserts by slug so repeated runs converge on the same catalog instead of
    # duplicating rows.
    def self.seed_products!
      created = 0

      PRODUCTS.each do |attributes|
        product = Foundation::Storefront::Product.find_or_initialize_by(slug: attributes[:slug])
        created += 1 if product.new_record?
        product.update!(**attributes, currency: "USD", active: true)
      end

      created
    end

    # One confirmed demo customer with a past paid order so "your orders" is
    # visible the moment someone signs in with the demo credentials.
    def self.seed_demo_customer!
      user = User.find_or_initialize_by(email: DEMO_CUSTOMER_EMAIL)
      user.password = DEMO_CUSTOMER_PASSWORD
      user.password_confirmation = DEMO_CUSTOMER_PASSWORD
      user.confirmed_at ||= Time.current
      user.save!

      return "existing order kept" if user.storefront_orders.exists?

      sunrise = Foundation::Storefront::Product.find_by!(slug: "sunrise-blend")
      espresso = Foundation::Storefront::Product.find_by!(slug: "emberfield-espresso")

      order = user.storefront_orders.create!(
        email: DEMO_CUSTOMER_EMAIL,
        state: "paid",
        currency: "USD",
        subtotal_cents: 5_200,
        total_cents: 5_200,
        terms_version: Foundation::Legal.terms_label,
        privacy_version: Foundation::Legal.privacy_label,
        legal_accepted_at: Time.current,
        reservation_expires_at: 1.hour.from_now,
        checkout_key_digest: Digest::SHA256.hexdigest("demo-seed-checkout-#{SecureRandom.hex(8)}"),
        simulated: true
      )

      [
        [sunrise, 1, 1_600],
        [espresso, 2, 1_800]
      ].each do |product, quantity, unit_price|
        order.line_items.create!(
          product: product,
          name: product.name,
          sku: product.sku,
          quantity: quantity,
          unit_price_cents: unit_price,
          line_total_cents: unit_price * quantity
        )
      end

      "order #{order.public_reference} created"
    end
  end
end
