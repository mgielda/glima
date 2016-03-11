module Glima
  class QueryParameter
    class FormatError < StandardError; end

    def initialize(folder, query_string, context = nil)
      @params = {}
      @folder, @query_string = folder, query_string

      if /^\+(\S+)/ =~ folder
        @params[:q] = "in:\"#{$1}\""
      else
        fail "Unknown folder: #{folder}."
      end

      if query_string == "next"
        @params[:page_token] = context&.load_page_token
        raise FormatError.new("No more page") if @params[:page_token].to_s == ""
      else
        @params[:q] += " #{query_string}"
      end
    end

    def to_hash
      @params
    end

  end # class QueryParameter
end # module Glima
