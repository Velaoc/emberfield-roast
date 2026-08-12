# frozen_string_literal: true

class AddRoastAndOriginToStorefrontProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :storefront_products, :roast_level, :string
    add_column :storefront_products, :origin, :string
  end
end
