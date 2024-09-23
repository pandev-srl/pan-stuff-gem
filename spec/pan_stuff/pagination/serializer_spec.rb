# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Pagination::MetadataSerializer do
  let(:model) do
    PanStuff::Pagination::Metadata.new(
      total_count: 100,
      total_pages: 10,
      current_page: 5,
      items_per_page: 10,
    )
  end

  let(:result) do
    JSON.generate(
      {
        totalCount: 100,
        totalPages: 10,
        currentPage: 5,
        itemsPerPage: 10,
      }
    )
  end

  describe '#as_json' do
    let(:serializer) { described_class.new(model, root: false) }

    it { expect(serializer.as_json).to eq(result) }
  end
end
