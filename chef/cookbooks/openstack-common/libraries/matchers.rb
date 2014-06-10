# encoding: UTF-8
if defined?(ChefSpec)
  module ChefSpec::Matchers
    class RenderFileMatcher
      def with_line(content)
        self.with_content(/^Regexp.escape(content)$/)
      end
    end
  end
end
