# frozen_string_literal: true

require 'spec_helper'

# class FakeModel < ActiveRecord::Base
#   include PanStuff::ActiveRecordPagination
# end

describe PanStuff::ActiveRecordPagination do
  include InMemoryDatabaseHelpers

  # switch_to_SQLite do
  #   create_table :fake_model do |t|
  #     t.timestamps
  #     t.name :string
  #   end
  # end

  # describe FakeReviewable, type: :model do
  #   include_examples 'reviewable' do
  #     let(:reviewed)   { FakeReviewable.create! reviewed_at: DateTime.current }
  #     let(:unreviewed) { FakeReviewable.create! reviewed_at: nil }
  #   end
  # end
end