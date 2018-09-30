# frozen_string_literal: true

require 'tzinfo'
require 'json'

require 'lita/handlers/lunch/office/schedule'

module Lita
  module Handlers
    module Lunch
      class Office
        include Lita::Handler::Common
        include Lita::Handlers::Lunch::Office::Schedule::Mixin

        namespace 'lunch'

        REDIS_PREFIX = 'offices'
        REDIS_KEY = "#{REDIS_PREFIX}:instances"

        attr_reader :name, :room, :timezone

        def self.find(robot, name)
          handler = new(robot, name, nil, 'UTC')
          json = handler.redis.hget(REDIS_KEY, normalize_name(name))
          from_json(robot, json)
        end

        def initialize(robot, name, room, timezone)
          super(robot)
          @name = name

          if room
            @room = room.respond_to?(:id) ? room : (Lita::Room.find_by_name(room) || Lita::Room.find_by_id(room))
            raise "cannot find room #{room}" unless @room
          end

          @timezone = timezone.respond_to?(:canonical_identifier) ? timezone : TZInfo::Timezone.get(timezone.to_s)
        end

        def save
          redis.hset(REDIS_KEY, self.class.normalize_name(@name),
                     { name: @name, room: room&.id, timezone: @timezone.canonical_identifier }.to_json)
        end

        def add_participant(participant)
          redis.sadd("#{REDIS_PREFIX}:#{@room.id}", participant.id)
        end

        def remove_participant(participant)
          redis.srem("#{REDIS_PREFIX}:#{@room.id}", participant.id)
        end

        def participants(robot)
          redis.smembers("#{REDIS_PREFIX}:#{@room.id}").map { |id| Participant.find(robot, id) }
        end

        def as_json
          self.class.normalize_name(@name)
        end

        def self.all(robot)
          new(robot, '_handler', nil, 'UTC').redis.hgetall(REDIS_KEY).values.map { |j| from_json(robot, j) }.compact
        end

        def self.from_json(robot, json)
          return nil unless json
          begin
            data = JSON.parse(json)
            return new(robot, data['name'], data['room'], data['timezone'])
          rescue JSON::ParserError
            return nil
          rescue TZInfo::InvalidTimezoneIdentifier
            return nil
          end
        end

        def self.normalize_name(name)
          name.downcase.gsub(/\W+/, '_')
        end
      end
    end
  end
end
