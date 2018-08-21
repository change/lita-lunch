# frozen_string_literal: true

require 'lita/handlers/lunch/office'
require 'lita/handlers/lunch/participant'
require 'timecop'

RSpec.describe Lita::Handlers::Lunch::Office::Schedule do
  let(:office_london) { Lita::Handlers::Lunch::Office.new(robot, 'London', room, 'GMT') }
  let(:office_nyc) { Lita::Handlers::Lunch::Office.new(robot, 'New York', room, 'EST5EDT') }
  let(:office_sf) { Lita::Handlers::Lunch::Office.new(robot, 'San Francisco', room, 'PST8PDT') }

  let(:robot) { instance_double 'Lita::Robot' }
  # let(:robot) { Robot.new(registry) }
  let(:room) { instance_double 'Lita::Room' }

  let(:offices) { [office_london, office_nyc, office_sf] }

  describe '.run_schedule' do
    it 'calls .all' do
      expect(Lita::Handlers::Lunch::Office).to receive(:all).with(robot).and_return([])
      Lita::Handlers::Lunch::Office.run_schedule(robot)
    end

    after do
      Timecop.return
    end

    # rubocop:disable RSpec/ContextWording, RSpec/ExpectInHook
    shared_context 'does not call send_reminder' do
      before do
        reminder_targets.each do |t|
          expect(t).not_to receive(:send_reminder).with(any_args)
        end
      end
    end

    shared_context 'does not call send_groups' do
      before do
        groups_targets.each do |t|
          expect(t).not_to receive(:send_groups).with(any_args)
        end
      end
    end
    # rubocop:enable RSpec/ContextWording, RSpec/ExpectInHook

    context 'when it is not Thursday anywhere' do
      before do
        Timecop.freeze(Time.utc(2018, 8, 21, 10, 1))
      end

      include_context 'does not call send_reminder' do
        let(:reminder_targets) { offices }
      end

      include_context 'does not call send_groups' do
        let(:groups_targets) { offices }
      end

      it 'does not call either method on any Office' do
        Lita::Handlers::Lunch::Office.run_schedule(robot)
      end
    end

    shared_examples 'time-based examples per office' do |office_name|
      before do
        offices.each(&:save)
        allow(Lita::Handlers::Lunch::Office).to receive(:all).and_return(offices)
      end

      context "when it is time to send reminders in #{office_name}" do
        include_context 'does not call send_reminder' do
          let(:reminder_targets) { offices - [target_office] }
        end

        include_context 'does not call send_groups' do
          let(:groups_targets) { offices }
        end

        before do
          # This returns a DateTime object, which is not easily converted to local time.
          dt = target_office.timezone.local_to_utc(DateTime.new(2018, 8, 23, 10, 1)) # rubocop:disable Style/DateTime
          time = Time.utc(dt.year, dt.month, dt.day, dt.hour, dt.min).localtime
          Timecop.freeze(time)
        end

        it "sends reminders only in #{office_name}" do
          expect(target_office).to receive(:send_reminder).with(any_args)
          Lita::Handlers::Lunch::Office.run_schedule(robot)
        end
      end

      context "when it is time to send groups in #{office_name}" do
        include_context 'does not call send_reminder' do
          let(:reminder_targets) { offices }
        end

        include_context 'does not call send_groups' do
          let(:groups_targets) { offices  - [target_office] }
        end

        before do
          # This returns a DateTime object, which is not easily converted to local time.
          dt = target_office.timezone.local_to_utc(DateTime.new(2018, 8, 23, 11, 23)) # rubocop:disable Style/DateTime
          time = Time.utc(dt.year, dt.month, dt.day, dt.hour, dt.min).localtime
          Timecop.freeze(time)
        end

        it "sends groups only in #{office_name}" do
          expect(target_office).to receive(:send_groups).with(any_args)
          Lita::Handlers::Lunch::Office.run_schedule(robot)
        end
      end
    end

    include_examples 'time-based examples per office', 'London' do
      let(:target_office) { office_london }
    end
    include_examples 'time-based examples per office', 'NYC' do
      let(:target_office) { office_nyc }
    end
    include_examples 'time-based examples per office', 'SF' do
      let(:target_office) { office_sf }
    end
  end

  describe '#send_reminder' do
    let(:room) { Lita::Room.create_or_update('magrathea') }

    it 'notifies the room' do
      expect(robot).to receive(:send_message).with(having_attributes(room: room.name), /^@here.*today.*use/i)
      office_sf.send_reminder(robot)
    end
  end

  describe 'send_groups' do
    subject { office_sf }

    let(:trillian) { Lita::User.create(23, name: 'Tricia MacMillian', mention_name: 'trillian') }
    let(:zaphod) { Lita::User.create(23, name: 'Zaphod Beeblebrox', mention_name: 'zaphod') }
    let(:participants) do
      [trillian, zaphod].each_with_index.map do |u, i|
        Lita::Handlers::Lunch::Participant.new(robot, id: u.id, include_in_next: i > 0).tap(&:save)
      end
    end

    before do
      participants.each { |p| subject.add_participant(p.user) }
      allow(robot).to receive(:send_message).with(any_args)
    end

    it 'includes current participants' do
      expect(robot).to receive(:send_message).with(having_attributes(user: zaphod), anything)
      subject.send_groups(robot)
    end

    it 'does not include other participants' do
      expect(robot).not_to receive(:send_message).with(having_attributes(user: trillian), anything)
      subject.send_groups(robot)
    end
  end
end
