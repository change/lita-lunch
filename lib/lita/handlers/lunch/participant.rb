# frozen_string_literal: true

require 'tzinfo'
require 'json'

module Lita
  module Handlers
    class Lunch
      class Participant
        include Lita::Handler::Common
        namespace 'lunch'

        REDIS_KEY = 'participants'

        attr_reader :id
        attr_accessor :office
        attr_accessor :include_in_next

        PERSIST_DATA = %w[id office include_in_next].freeze

        def self.from_user(robot, user)
          find(robot, user.id)
        end

        def self.find(robot, id)
          handler = new(robot, id: id)
          json = handler.redis.hget(REDIS_KEY, id)
          from_json(robot, json)
        end

        def self.find_or_build(robot, **keywords)
          found = find(robot, keywords[:id])
          return found if found
          new(robot, **keywords)
        end

        def initialize(robot, **keywords)
          super(robot)

          # Initialize all attributes to avoid warnings
          PERSIST_DATA.each { |d| instance_variable_set("@#{d}", nil) }

          keywords.each do |k, v|
            raise ArgumentError, "Invalid instance member: #{k}" unless PERSIST_DATA.include?(k.to_s)
            instance_variable_set("@#{k}", v)
          end

          @office = Office.find(robot, @office) if @office && !@office.respond_to?(:as_json)
        end

        def save
          data = Hash[
            PERSIST_DATA.map do |d|
              value = instance_variable_get("@#{d}")
              [d, value.respond_to?(:as_json) ? value.as_json : value]
            end
          ]

          redis.hset(REDIS_KEY, @id, data.to_json)
        end

        def self.from_json(robot, json)
          return nil unless json
          begin
            return new(robot, **Hash[JSON.parse(json).map { |k, v| [k.to_sym, v] }])
          rescue JSON::ParserError
            return nil
          rescue ArgumentError
            return nil
          end
        end
      end
    end
  end
end
