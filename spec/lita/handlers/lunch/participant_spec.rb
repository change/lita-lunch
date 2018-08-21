# frozen_string_literal: true

require 'lita/handlers/lunch/participant'
require 'lita/handlers/lunch/office'

RSpec.describe Lita::Handlers::Lunch::Participant do
  let(:robot) { instance_double 'Lita::Robot' }
  # let(:room) { instance_double 'Lita::Room', id: 42 }
  let(:room) { Lita::Room.create_or_update('magrathea') }
  let(:office_object) { Lita::Handlers::Lunch::Office.new(robot, 'SF', room, 'UTC') }

  describe '#new' do
    it 'sets id when passed' do
      expect(described_class.new(robot, id: 123).id).to eq 123
    end

    it 'sets include_in_next when passed' do
      expect(described_class.new(robot, include_in_next: true).include_in_next).to eq true
    end

    context 'with an office' do
      context 'when it is a string' do
        let(:office) { 'SF' }

        it 'sets the value to nil normally' do
          expect(described_class.new(robot, office: office).office).to be_nil
        end

        context 'when it exists' do
          before { office_object.save }

          it 'sets the office to the object' do
            expect(described_class.new(robot, office: office).office.as_json).to eq office_object.as_json
          end
        end
      end

      context 'when it is an Office object' do
        it 'sets the office to the object' do
          expect(described_class.new(robot, office: office_object).office).to eq office_object
        end
      end
    end
  end

  describe '#save' do
    subject { described_class.new(robot, id: id, office: office_object, include_in_next: true) }

    let(:id) { 42 }

    it 'persists data to Redis' do
      subject.save
      expect(
        JSON.parse(
          subject.redis.hget(described_class::REDIS_KEY, id)
        )
      ).to include('id' => id, 'office' => office_object.as_json, 'include_in_next' => true)
    end
  end

  describe '#find' do
    let(:id) { 42 }

    context 'when the user is present' do
      let(:user_options) { { id: id } }

      before do
        described_class.new(robot, user_options).save
      end

      it 'finds by id' do
        expect(described_class.find(robot, id).id).to eq id
      end

      context 'when the user has an office' do
        let(:user_options) { { id: id, office: 'SF' } }

        it 'removes the office when it does not exist' do
          expect(described_class.find(robot, id).office).to be_nil
        end

        context 'when the office exists' do
          before do
            office_object.save
            described_class.new(robot, user_options).save
          end

          it 'includes an office object' do
            expect(described_class.find(robot, id).office.as_json).to eq office_object.as_json
          end
        end
      end
    end

    context 'when the user is not present' do
      it 'retuns nil' do
        expect(described_class.find(robot, id)).to be_nil
      end
    end

    context 'when the user is ill-formed' do
      before { described_class.new(robot, id: id).redis.hset(described_class::REDIS_KEY, id, 'fnord') }

      it 'retuns nil' do
        expect(described_class.find(robot, id)).to be_nil
      end
    end
  end
end
