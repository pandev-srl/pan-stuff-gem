# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PanStuff::Serializer::ValidationResponse do
  subject { described_class.new({ id: 'myId', status: 422, message: 'Example message' }) }

  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :status }
  it { is_expected.to respond_to :message }
end
