# frozen_string_literal: true

require 'tzinfo'
require 'json'

require 'byebug'

module Lita
  module Handlers
    module Lunch
      class HTTP < Handler
        namespace 'lunch'

        http.post('/lunch/scheduled', :scheduled)

        def scheduled(_request, response)
          data = Office.run_schedule(robot)
          response.headers['Content-Type'] = 'application/json'
          response.write(MultiJson.dump(time: Time.now.to_s, data: data))
        end

        Lita.register_handler(self)
      end
    end
  end
end
