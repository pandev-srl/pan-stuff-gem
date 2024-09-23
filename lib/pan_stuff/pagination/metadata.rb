# frozen_string_literal: true

module PanStuff
  module Pagination
    class Metadata
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :total_count
      attribute :total_pages
      attribute :current_page
      attribute :items_per_page
    end
  end
end
