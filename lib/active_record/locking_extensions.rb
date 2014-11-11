# encoding: utf-8
require "active_support/log_subscriber"
require "active_support/notifications"

module ActiveRecord

  # These methods are available as class methods on ActiveRecord::Base.
  module LockingExtensions

    # Execute the given block within a database transaction, and retry the
    # transaction from the beginning if a RestartTransaction exception is raised.
    def restartable_transaction(&block)
      begin
        transaction(&block)
      rescue ActiveRecord::RestartTransaction
        retry
      end
    end

    # Execute the given block, and retry the current restartable transaction if a
    # MySQL deadlock occurs.
    def with_restart_on_deadlock
      begin
        yield
      rescue ActiveRecord::StatementInvalid => exception
        if exception.message =~ /deadlock/i || exception.message =~ /database is locked/i
          ActiveSupport::Notifications.publish("deadlock_restart.active_record", :exception => exception)

          raise ActiveRecord::RestartTransaction
        else
          raise
        end
      end
    end

    # Create the record, but ignore the exception if there's a duplicate.
    # if there is a deadlock, retry
    def create_ignoring_duplicates!(*args)
      retry_deadlocks do
        ignoring_duplicates do
          create!(*args)
        end
      end
    end

    private

    def ignoring_duplicates
      # Error examples:
      #   PG::Error: ERROR:  duplicate key value violates unique constraint
      #   Mysql2::Error: Duplicate entry 'keith' for key 'index_users_on_username': INSERT INTO `users...
      #   ActiveRecord::RecordNotUnique  SQLite3::ConstraintException: column username is not unique: INSERT INTO "users"...
      begin
        yield
      rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotUnique => exception
        if  exception.message =~ /duplicate/i || exception.message =~ /ConstraintException/
          ActiveSupport::Notifications.publish("duplicate_ignore.active_record", :exception => exception)

          # Just ignore it...someone else has already created the record.
        else
          raise
        end
      end
    end

    def retry_deadlocks
      # Error examples:
      #   PG::Error: ERROR:  deadlock detected
      #   Mysql::Error: Deadlock found when trying to get lock
      begin
        yield
      rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotUnique => exception
        if exception.message =~ /deadlock/i || exception.message =~ /database is locked/i
          # Somebody else is in the midst of creating the record. We'd better
          # retry, so we ensure they're done before we move on.
          ActiveSupport::Notifications.publish("deadlock_retry.active_record", :exception => exception)

          retry
        else
          raise
        end
      end
    end

    class LogSubscriber < ActiveSupport::LogSubscriber
      def deadlock_restart(event)
        info "Deadlock causing restart"
        debug event[:exception]
      end

      def deadlock_retry(event)
        info "Deadlock causing retry"
        debug event[:exception]
      end

      def duplicate_ignore(event)
        info "Duplicate ignored"
        debug event[:exception]
      end
    end
  end

  # Raise this inside a restartable_transaction to retry the transaction from the beginning.
  class RestartTransaction < RuntimeError
  end

end


ActiveRecord::Base.extend(ActiveRecord::LockingExtensions)
ActiveRecord::LockingExtensions::LogSubscriber.attach_to :active_record
