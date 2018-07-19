# rubocop:disable Style/FrozenStringLiteralComment
# Lita has a bug (fixed in master) that causes frozen strings to blow up tests
# rubocop:enable Style/FrozenStringLiteralComment

RSpec.describe Lita::Handlers::Lunch, lita_handler: true do
  it { is_expected.to route_command('lunch list offices').to(:list_offices) }
  it do
    is_expected.to route_command(
      'lunch create office office tz'
    ).with_authorization_for(:lunch_admins).to(:create_office)
  end

  describe '#create_office' do
    shared_examples 'does not create an office' do
      it 'does not create an office' do
        send_command(command)
        send_command('lunch list offices')
        expect(replies.last).to include 'empty'
      end
    end

    context 'with a non-admin user' do
      let(:command) { 'lunch create office Mordor UTC' }
      it 'prevents the user from adding an office' do
        send_command(command)
        expect(replies).to be_empty
      end

      include_examples 'does not create an office'
    end

    context 'with an admin user' do
      before do
        robot.auth.add_user_to_group!(user, :lunch_admins)
      end

      context 'when the timezone is not valid' do
        let(:command) { 'lunch create office Milliways End-of-the-Universe' }

        it 'informs the user' do
          send_command(command)
          expect(replies.last).to include 'timezone'
        end

        include_examples 'does not create an office'
      end

      context 'when the office already exists' do
        let(:command) { 'lunch create office Magrathea UTC' }

        before do
          send_command(command.sub(/UTC/, 'PST8PDT'))
        end

        it 'informs the user' do
          send_command(command)
          expect(replies.last).to include 'exist'
        end

        it 'does not overwrite the existing office' do
          send_command(command)
          expect(described_class::Office.find(robot, 'Magrathea').timezone.canonical_identifier).to eq 'PST8PDT'
        end
      end

      it 'creates the office' do
        send_command('lunch create office Mordor UTC')
        send_command('lunch list offices')
        expect(replies.last).to include 'Mordor'
      end
    end
  end

  describe '#list_offices' do
    before do
      robot.auth.add_user_to_group!(user, :lunch_admins)
      send_command('lunch create office Magrathea UTC')
      send_command('lunch create office Betelgeuse UTC')
    end

    it 'lists offices alphabetically' do
      send_command('lunch list offices')
      expect(replies.last).to match(/Betelgeuse\nMagrathea/)
    end
  end
end
