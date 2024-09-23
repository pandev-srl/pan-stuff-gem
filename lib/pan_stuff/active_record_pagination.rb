# frozen_string_literal: true

module PanStuff
  module ActiveRecordPagination
    extend ActiveSupport::Concern

    class_methods do
      def paginate(current_page:, items_per_page:)
        limit  = items_per_page
        offset = (current_page - 1) * items_per_page

        total_count = count
        total_pages = (total_count.to_d / items_per_page).ceil

        metadata = {
          total_count:    total_count,
          total_pages:    total_pages,
          current_page:   current_page,
          items_per_page: items_per_page,
        }
        [
          limit(limit).offset(offset),
          metadata,
        ]
      end
    end
  end
end
