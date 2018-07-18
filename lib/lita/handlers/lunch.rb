# frozen_string_literal: true

require 'tzinfo'
require 'json'

module Lita
  module Handlers
    class Lunch < Handler
      route(/^lunch create office\s(.+)\s(\S+)$/, :create_office, command: true, restrict_to: :lunch_admins, help: {
              t('office.create.help.command') => t('office.create.help.description')
            })

      def create_office(response)
        (name, tz) = response.matches.first
        begin
          if (office = redis.hget('offices', normalize_office_name(name))) # intentional assignment
            response.reply(t('office.create.error.exists', name: JSON.parse(office)['name']))
            return
          end

          tz = TZInfo::Timezone.get(tz)
        rescue TZInfo::InvalidTimezoneIdentifier
          response.reply(t('office.create.error.timezone', timezone: tz))
          return
        rescue JSON::ParserError # rubocop:diable Lint/HandleExceptions
          # NOOP: Let it overwrite it.
        end

        redis.hset('offices', normalize_office_name(name), { name: name, timezone: tz.name }.to_json)
        response.reply(t('office.create.success', name: name, timezone: tz.name))
      end

      def list_offices(response)
        offices = redis.hgetall('offices').values

        offices.map! do |o|
          JSON.parse(o)['name']
        rescue StandardError
          nil
        end

        offices.compact!

        if offices.empty?
          response.reply(t('office.list.empty'))
          return
        end

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
