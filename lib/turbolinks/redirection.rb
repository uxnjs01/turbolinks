module Turbolinks
  module Redirection
    extend ActiveSupport::Concern

    included do
      before_action :set_xhr_redirected_to_header_from_session
    end

    def redirect_to(url = {}, options = {})
      turbolinks = options.delete(:turbolinks)
      
      super(url, options).tap do
        if turbolinks != false && request.xhr? && !request.get?
          visit_options = {
            action: turbolinks.to_s == "advance" ? turbolinks : "replace"
          }

          script = []
          script << "Turbolinks.clearCache()"
          script << "Turbolinks.visit(#{location.to_json}, #{visit_options.to_json})"

          self.status = 200
          self.response_body = script.join("\n")
          response.content_type = Mime::JS
        end
      end
    end

    def _compute_redirect_to_location(*args)
      super.tap { |url| store_xhr_redirected_to_in_session(url) }
    end

    private
      def store_xhr_redirected_to_in_session(url)
        if session && request.headers["X-XHR-Referer"]
          session[:_xhr_redirected_to] = url
        end
      end

      def set_xhr_redirected_to_header_from_session
        if session && xhr_redirected_to = session.delete(:_xhr_redirected_to)
          response.headers['X-XHR-Redirected-To'] = xhr_redirected_to
        end
      end
  end
end
