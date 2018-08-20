# frozen_string_literal: true

require 'tzinfo'
require 'json'

require 'byebug'

module Lita
  module Handlers
    module Lunch
      class Chat < Handler
        namespace 'lunch'

        route(/^lunch today\s*(?:for\s+)?(@.*?)?\s*$/, :participate, command: true, help: {
                t('office.participate.help.self.command') => t('office.participate.help.self.description'),
                t('office.participate.help.other.command') => t('office.participate.help.other.description')
              })

        route(/^lunch list offices?$/, :list_offices, command: true, help: {
                t('office.list.help.command') => t('office.list.help.description')
              })

        route(/^lunch office\s*$/, :show_office, command: true, help: {
                t('office.show.help.command') => t('office.show.help.description')
              })

        route(/^lunch office\s+(@.+)?\s*(\p{Word}+)/, :select_office, command: true, help: {
                t('office.select.help.self.command') => t('office.select.help.self.description'),
                t('office.select.help.other.command') => t('office.select.help.other.description')
              })

        route(/^lunch create office\s(.+)\s+(.+)\s+(\S+)$/, :create_office, command: true, restrict_to: :lunch_admins,
                                                                            help: {
                                                                              t('office.create.help.command') =>
                                                                              t('office.create.help.description')
                                                                            })

        def participate(response)
          participant = pick_recipient(response)
          participant.include_in_next = true
          participant.save

          type = participant.id == response.user.id ? 'self' : 'other'

          if participant.office
            response.reply(t("participate.added.with_office.#{type}"))
          else
            response.reply(t("participate.added.no_office.#{type}",
                             select_command: t("office.select.help.#{type}.command")))
          end
        end

        def create_office(response)
          (name, channel, tz) = response.matches.first
          begin
            office = Office.find(robot, name)

            if office
              response.reply(t('office.create.error.exists', name: office.name))
              return
            end

            office = Office.new(robot, name, channel, tz)
          rescue TZInfo::InvalidTimezoneIdentifier
            response.reply(t('office.create.error.timezone', timezone: tz))
            return
          end

          office.save
          response.reply(t('office.create.success', name: name, timezone: office.timezone.name))
        end

        def list_offices(response)
          offices = Office.all(robot).map(&:name)

          return response.reply(t('office.list.empty')) if offices.empty?

          offices.sort_by!(&:downcase)

          response.reply(t('office.list.response', office_names_separated_by_newlines: offices.join("\n")))
        end

        def show_office(response)
          participant = Participant.from_user(robot, response.user)
          office = participant&.office
          return response.reply(t('participant.no_office')) unless office
          response.reply(office.name)
        end

        def select_office(response)
          participant = pick_recipient(response)
          office = Office.find(robot, response.matches.first.last)

          unless office
            response.reply(t('office.select.unknown_office', list_command: t('office.list.help.command')))
            return
          end

          response.reply(swap_office(participant, office))
        end

        private

        def swap_office(participant, office)
          response_key = 'office.select.success_with_include'

          if participant.office
            participant.office.remove_participant(user)
            response_key = 'office.select.move_with_include'
          end

          participant.office = office

          office.add_participant(participant)

          # Do this for them.
          participant.include_in_next = true
          participant.save

          t(response_key, office: office.name)
        end

        def pick_recipient(response, position = 0)
          matches = response.matches.first
          user = response.user

          user = Lita::User.find_by_mention_name(matches[position].tr('@', '')) if matches[position]

          unless user
            response.reply(t('participant.user_not_found'))
            return
          end

          Participant.find_or_build(robot, id: user.id)
        end

        Lita.register_handler(self)
      end
    end
  end
end
