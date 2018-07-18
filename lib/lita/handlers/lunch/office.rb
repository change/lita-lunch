# frozen_string_literal: true

require 'tzinfo'
require 'json'

module Lita
  module Handlers
    class Lunch
      class Office
        include Lita::Handler::Common
        namespace 'lunch'

        REDIS_KEY = 'offices'

        attr_reader :name, :timezone

        def self.find(robot, name)
          handler = new(robot, name, 'UTC')
          json = handler.redis.hget(REDIS_KEY, normalize_name(name))
          return nil unless json
          begin
            data = JSON.parse(json)
            return new(robot, data['name'], data['timezone'])
          rescue JSON::ParserError
            return nil
          rescue TZInfo::InvalidTimezoneIdentifier
            return nil
          end
        end

        def initialize(robot, name, timezone)
          super(robot)
          @name = name
          @timezone = timezone.respond_to?(:canonical_identifier) ? timezone : TZInfo::Timezone.get(timezone.to_s)
        end

        def save
          redis.hset(REDIS_KEY, self.class.normalize_name(@name),
                     { name: @name, timezone: @timezone.canonical_identifier }.to_json)
        end


        def self.normalize_name(name)
          name.downcase
        end
      end
    end
  end
end
