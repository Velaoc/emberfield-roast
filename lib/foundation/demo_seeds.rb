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
        image_url: "https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=900&q=80"
      },
      {
        slug: "emberfield-espresso", sku: "EMB-ESPRESSO", name: "Emberfield Espresso",
        description: "Our signature shot: dark cocoa, toasted hazelnut, and brown sugar. Medium-dark roast pulled for milk drinks or straight.",
        price_cents: 1_800, position: 1, inventory_quantity: 100,
        roast_level: "Medium-dark", origin: "Brazil · Minas Gerais",
        image_url: "https://images.unsplash.com/photo-1447933601403-0c6688de566e?auto=format&fit=crop&w=900&q=80"
      },
      {
        slug: "highland-bourbon", sku: "EMB-HIGHLAND", name: "Highland Bourbon",
        description: "A balanced single origin with red apple, caramel, and a silky body. Medium roast from the Huila highlands.",
        price_cents: 1_750, position: 2, inventory_quantity: 100,
        roast_level: "Medium", origin: "Colombia · Huila",
        image_url: "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80"
      },
      {
        slug: "midnight-city", sku: "EMB-MIDNIGHT", name: "Midnight City",
        description: "A heavy, low-acid dark roast. Molasses, cedar, and dark chocolate — made for cold brew and long mornings.",
        price_cents: 1_550, position: 3, inventory_quantity: 100,
        roast_level: "Dark", origin: "Sumatra · Aceh",
        image_url: "https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?auto=format&fit=crop&w=900&q=80"
      },
      {
        slug: "golden-hour-decaf", sku: "EMB-GOLDEN", name: "Golden Hour Decaf",
        description: "Swiss-water decaf that still tastes like coffee: toasted grain, milk chocolate, and a round, gentle finish.",
        price_cents: 1_650, position: 4, inventory_quantity: 100,
        roast_level: "Medium", origin: "Colombia · SWP Decaf",
        image_url: "https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=900&q=80"
      },
      {
        slug: "windward-geisha", sku: "EMB-WINDWARD", name: "Windward Geisha",
        description: "Our small-lot showpiece: jasmine, bergamot, and peach tea. A delicate light roast, roasted in 5 kg batches every Friday.",
        price_cents: 2_800, position: 5, inventory_quantity: 30,
        roast_level: "Light", origin: "Panama · Boquete",
        image_url: "https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=900&q=80"
      }
    ].freeze

    DEMO_CUSTOMER = {
      email: "demo@emberfield.roast",
      password: "emberfield-demo-1"
    }.freeze

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
      customer = seed_customer!(io: io)
      seed_orders!(customer, io: io)
      io.puts("Demo catalog ready: #{PRODUCTS.length} products (#{created} created).")
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

    # A demo customer with a known password makes order history walkable on
    # first visit to the preview. Legal assent is recorded on the account the
    # same way the signup flow records it.
    def self.seed_customer!(io:)
      user = User.find_or_initialize_by(email: DEMO_CUSTOMER.fetch(:email))
      if user.new_record?
        user.password = DEMO_CUSTOMER.fetch(:password)
        user.password_confirmation = DEMO_CUSTOMER.fetch(:password)
        user.legal_assent = true
        user.skip_personal_organization = true
        user.confirmed_at ||= Time.current
        user.save!
        io.puts("Demo customer created: #{DEMO_CUSTOMER.fetch(:email)}")
      end
      user
    end

    # Two past orders in different states so order history has something real
    # to show on first visit: one fulfilled, one paid.
    def self.seed_orders!(user, io:)
      return if user.storefront_orders.exists?

      catalog = Foundation::Storefront::Product.order(:position).index_by(&:slug)
      seed_order!(user, catalog, "fulfilled", 21.days.ago,
        [ [ "sunrise-blend", 1 ], [ "highland-bourbon", 2 ] ])
      seed_order!(user, catalog, "paid", 3.days.ago,
        [ [ "emberfield-espresso", 1 ], [ "windward-geisha", 1 ] ])
      io.puts("Demo orders created for #{user.email}.")
    end

    def self.seed_order!(user, catalog, state, created_at, items)
      order = user.storefront_orders.build(
        checkout_key_digest: Digest::SHA256.hexdigest("demo-#{user.id}-#{state}-#{created_at.to_i}"),
        email: user.email,
        state: state,
        currency: "USD",
        subtotal_cents: 0,
        total_cents: 0,
        terms_version: Foundation::Legal::TERMS_VERSION,
        privacy_version: Foundation::Legal::PRIVACY_VERSION,
        legal_accepted_at: created_at,
        reservation_expires_at: created_at + 45.minutes,
        acceptance_ip: "127.0.0.1",
        acceptance_user_agent: "demo-seed",
        simulated: true
      )
      items.each do |slug, quantity|
        product = catalog.fetch(slug)
        line_total = product.price_cents * quantity
        order.line_items.build(
          product: product,
          name: product.name,
          sku: product.sku,
          unit_price_cents: product.price_cents,
          currency: product.currency,
          quantity: quantity,
          line_total_cents: line_total
        )
        order.subtotal_cents += line_total
        order.total_cents += line_total
      end
      order.save!
      order.update_columns(
        created_at: created_at,
        updated_at: created_at,
        paid_at: state == "paid" ? created_at : nil,
        fulfilled_at: state == "fulfilled" ? created_at : nil,
        checkout_started_at: created_at
      )
      order
    end
    private_class_method :seed_order!
  end
end
