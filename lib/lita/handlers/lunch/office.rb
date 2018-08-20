# frozen_string_literal: true

require 'tzinfo'
require 'json'

module Lita
  module Handlers
    module Lunch
      class Office
        include Lita::Handler::Common
        namespace 'lunch'

        REDIS_PREFIX = 'offices'
        REDIS_KEY = "#{REDIS_PREFIX}:instances"

        attr_reader :name, :timezone

        def self.find(robot, name)
          handler = new(robot, name, 'UTC')
          json = handler.redis.hget(REDIS_KEY, normalize_name(name))
          from_json(robot, json)
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

        def add_participant(participant)
          redis.sadd("#{REDIS_PREFIX}:#{self.class.normalize_name(name)}", participant.id)
        end

        def remove_participant(participant)
          redis.srem("#{REDIS_PREFIX}:#{self.class.normalize_name(name)}", participant.id)
        end

        def as_json
          self.class.normalize_name(@name)
        end

        def self.all(robot)
          new(robot, '_handler', 'UTC').redis.hgetall(REDIS_KEY).values.map { |j| from_json(robot, j) }.compact
        end

        def self.from_json(robot, json)
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

        def self.normalize_name(name)
          name.downcase
        end
      end
    end
  end
end
