module Onebox
  module Engine
    class GitlabBlobOnebox < GithubBlobOnebox
      include Engine
      include LayoutSupport

      matches_regexp(/^https?:\/\/(www\.)?gitlab\.com.*\/blob\//)

      def layout
        @layout ||= Layout.new('githubblob', record, @cache)
      end

      def initialize(link, cache = nil, timeout = nil)
        super link, cache, timeout

        # Define constant after merging options set in Onebox.options
        # We can define constant automatically.
        options.each_pair do |constant_name, value|
          constant_name_u = constant_name.to_s.upcase
          if constant_name_u == constant_name.to_s
            #define a constant if not already defined
            self.class.superclass.const_set constant_name_u.to_sym , options[constant_name_u.to_sym]  unless self.class.superclass.const_defined? constant_name_u.to_sym
          end
        end
      end

      private
      def raw
        return @raw if @raw

        m = @url.match(/gitlab\.com\/(?<user>[^\/]+)\/(?<repo>[^\/]+)\/blob\/(?<sha1>[^\/]+)\/(?<file>[^#]+)(#(L(?<from>[^-]*)(-L(?<to>.*))?))?/mi)

        if m
          from = /\d+/.match(m[:from])   #get numeric should only match a positive interger
          to   = /\d+/.match(m[:to])     #get numeric should only match a positive interger

          @file = m[:file]
          @lang = Onebox::FileTypeFinder.from_file_name(m[:file])
          contents = open("https://gitlab.com/#{m[:user]}/#{m[:repo]}/raw/#{m[:sha1]}/#{m[:file]}", read_timeout: timeout).read

          contents_lines = contents.lines           #get contents lines
          contents_lines_size = contents_lines.size #get number of lines

          cr = calc_range(m, contents_lines_size)    #calculate the range of lines for output
          selected_one_liner = cr[:selected_one_liner] #if url is a one-liner calc_range will return it
          from           = cr[:from]
          to             = cr[:to]
          @truncated     = cr[:truncated]
          range_provided = cr[:range_provided]
          @cr_results = cr

          if range_provided       #if a range provided (single line or more)
            if SHOW_LINE_NUMBER
              lines_result = line_number_helper(contents_lines[(from - 1)..(to - 1)], from, selected_one_liner)  #print code with prefix line numbers in case range provided
              contents = lines_result[:output]
              @selected_lines_array = lines_result[:array]
            else
              contents = contents_lines[(from - 1)..(to - 1)].join()
            end

          else
            contents = contents_lines[(from - 1)..(to - 1)].join()
          end

          if contents.length > MAX_CHARS    #truncate content chars to limits
            contents = contents[0..MAX_CHARS]
            @truncated = true
          end

          @raw = contents
        end
      end

      def data
        @data ||= {
          title: Sanitize.fragment(URI.unescape(link).sub(/^https?\:\/\/gitlab\.com\//, '')),
          link: link,
          # IMPORTANT NOTE: All of the other class variables are populated
          #     as *side effects* of the `raw` method! They must all appear
          #     AFTER the call to `raw`! Don't get bitten by this like I did!
          content: raw,
          lang: "lang-#{@lang}",
          lines:  @selected_lines_array ,
          has_lines: !@selected_lines_array.nil?,
          selected_one_liner: @selected_one_liner,
          cr_results: @cr_results,
          truncated: @truncated
        }
      end
    end
  end
end
