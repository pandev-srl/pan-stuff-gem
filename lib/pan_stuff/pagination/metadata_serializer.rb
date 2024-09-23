# frozen_string_literal: true

module PanStuff
  module Pagination
    class MetadataSerializer
      include ::PanStuff::Serializer::ObjectSerializer

      attribute :total_count
      attribute :total_pages
      attribute :current_page
      attribute :items_per_page
    end
  end
end
