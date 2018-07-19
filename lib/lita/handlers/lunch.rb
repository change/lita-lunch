# frozen_string_literal: true

require 'tzinfo'
require 'json'

require 'byebug'

module Lita
  module Handlers
    class Lunch < Handler
      route(/^lunch list offices?$/, :list_offices, command: true, help: {
              t('office.list.help.command') => t('office.list.help.description')
            })

      route(/^lunch create office\s(.+)\s(\S+)$/, :create_office, command: true, restrict_to: :lunch_admins, help: {
              t('office.create.help.command') => t('office.create.help.description')
            })

      def create_office(response)
        (name, tz) = response.matches.first
        begin
          office = Office.find(robot, name)

          if office
            response.reply(t('office.create.error.exists', name: office.name))
            return
          end

          office = Office.new(robot, name, tz)
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

      private

      def normalize_office_name(name)
        name.downcase
      end

      Lita.register_handler(self)
    end
  end
end
