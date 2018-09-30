# frozen_string_literal: true

module Lita
  module Handlers
    module Lunch
      class Office
        module Schedule
          module Mixin
            def self.included(base)
              base.send :include, InstanceMethods
              base.extend ClassMethods
            end

            module ClassMethods
              def run_schedule(robot)
                # TODO: Allow Offices to have their own schedules
                all(robot).map do |office|
                  time = office.timezone.now # The TZ field is always UTC, but everything else appears correct
                  err = { time: time.strftime('%F %T'), zone: office.timezone, office: office.name }
                  next err.merge(err: 'No schedule') unless PrivateMethods.check_wday(time, office)
                  next err.merge(notice: 'Sent reminders') unless PrivateMethods.check_reminder(time, office, robot)
                  next err.merge(notice: 'Sent groups') unless PrivateMethods.check_groups(time, office, robot)
                  err.merge(noop: 'noop')
                end
              end
            end

            module InstanceMethods
              def send_reminder(robot)
                robot.send_message(Lita::Source.new(room: @room),
                                   t('office.reminder', participate_command: t('participate.help.self.command')))
              end

              def send_groups(robot)
                today = participants(robot).select(&:include_in_next).shuffle

                groups = PrivateMethods.make_groups(today)

                groups.each do |group|
                  users = group.map(&:user)
                  users.each do |user|
                    list = (users - [user]).map { |u| "@#{u.mention_name}" }.join(' ')
                    robot.send_message(Lita::Source.new(user: user), t('participate.list', list: list))
                  end
                end
              end
            end
          end

          module PrivateMethods
            module_function

            def check_wday(time, _office)
              time.wday == 4 # Only runs Thursdays
            end

            def check_reminder(time, office, robot)
              if time.hour == 10
                return false unless time.min < 5
                office.send_reminder(robot)
                return false
              end
              true
            end

            def check_groups(time, office, robot)
              return true unless time.hour == 11 && time.min > 20 && time.min < 25
              office.send_groups(robot)
              false
            end

            def make_groups(items)
              # For now just brute-force the selection process
              slice_size = slice_size(items.size)
              groups = items.each_slice(slice_size).to_a

              if groups.last.size < slice_size - 1
                i = groups.size - 1
                until groups.last.size == slice_size - 1 || i == - 1
                  groups.last.push(groups[i].pop)
                  i -= 1
                end
              end

              groups
            end

            def slice_size(count)
              return 3 if (count % 3).zero? && !(count % 4).zero?
              4
            end
          end
        end
      end
    end
  end
end
