module Turbolinks
  module Redirection
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
  end
end
