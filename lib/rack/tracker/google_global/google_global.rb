class Rack::Tracker::GoogleGlobal < Rack::Tracker::Handler
  self.allowed_tracker_options = [:cookie_domain, :user_id,
    :link_attribution, :allow_display_features, :anonymize_ip,
    :custom_map, :optimize_id]

  class Page < OpenStruct
    def params
      Hash[to_h.slice(:title, :location, :path).map { |key, value| ["page_#{key}", value] }]
    end
  end

  class Event < OpenStruct
    PREFIXED_PARAMS = %i[category label]
    SKIP_PARAMS  = %i[action]

    def params
      Hash[to_h.except(*SKIP_PARAMS).map { |key, value| [param_key(key), value] }]
    end

    private

    def param_key(key)
      PREFIXED_PARAMS.include?(key) ? "event_#{key}" : key.to_s
    end
  end

  def pages
    select_handler_events(Page)
  end

  alias handler_events events

  def events
    select_handler_events(Event)
  end

  def trackers
    @_trackers ||= build_trackers
  end

  def set_options
    @_set_options ||= build_set_options
  end

  private

  def build_trackers
    options[:trackers].map(&method(:call_tracker)).reject(&method(:invalid_tracker?))
  end

  def call_tracker(tracker)
    if tracker[:id].respond_to?(:call)
      tracker.merge(id: tracker[:id].call(env))
    else
      tracker
    end
  end

  def invalid_tracker?(tracker)
    if tracker[:id].to_s.strip == ''
      $stdout.puts <<~WARN
      WARNING: One of the trackers specified for Rack::Tracker handler 'google_global' is empty.
               Trackers: #{options[:trackers]}
      WARN

      true
    else
      false
    end
  end

  def build_set_options
    value = options[:set]
    value.respond_to?(:call) ? value.call(env) : value
  end

  def select_handler_events(klass)
    handler_events.select { |event| event.is_a?(klass) }
  end
end
