# frozen_string_literal: true

require 'lita/handlers/lunch/office'

RSpec.describe Lita::Handlers::Lunch::Office do
  let(:robot) { instance_double 'Lita::Robot' }

  let(:name) { 'Office Name' }
  let(:timezone) { 'PST8PDT' }

  describe '#new' do
    subject { described_class.new(robot, name, timezone) }

    it 'converts the timezone string to a TZInfo object' do
      expect(subject.timezone).to respond_to :canonical_identifier
    end
  end

  describe '#save' do
    subject { described_class.new(robot, name, timezone) }

    it 'persists data to Redis' do
      subject.save
      expect(
        JSON.parse(
          subject.redis.hget(described_class::REDIS_KEY, subject.class.normalize_name(name))
        )
      ).to include('name' => name, 'timezone' => timezone)
    end
  end

  describe '#find' do
    context 'when the office is present' do
      before do
        described_class.new(robot, name, timezone).save
      end

      it 'finds by name' do
        expect(described_class.find(robot, name).name).to eq name
      end

      it 'finds case-insensitively' do
        expect(described_class.find(robot, name.upcase).name).to eq name
      end
    end

    context 'when the office is not present' do
      it 'retuns nil' do
        expect(described_class.find(robot, name)).to be_nil
      end
    end

    context 'when the office is ill-formed' do
      before { described_class.new(robot, name, timezone).redis.hset(described_class::REDIS_KEY, name, 'fnord') }

      it 'retuns nil' do
        expect(described_class.find(robot, name)).to be_nil
      end
    end
  end

  describe '#all' do
    before do
      described_class.new(robot, name, timezone).save
      described_class.new(robot, 'Palmer Station', 'Antarctica/Palmer').save
    end

    it 'returns all existing offices' do
      expect(described_class.all(robot).map(&:name)).to eq [name, 'Palmer Station']
    end
  end
end
