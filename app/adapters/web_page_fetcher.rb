# Fetches a web page and returns its raw HTML plus cleaned plain text.
#
# This is the adapter seam for HTTP fetching in the parse pipeline. The rest
# of the system only talks to this class, so specs can stub it without touching
# Faraday or the network.
class WebPageFetcher
  TIMEOUT = 10

  Page = Data.define(:html, :text, :content_type)

  class Error < StandardError; end

  class HttpError < Error
    attr_reader :status

    def initialize(status, message = nil)
      @status = status
      super(message || "fetch failed with HTTP #{status}")
    end
  end

  class NetworkError < Error; end
  class TimeoutError < Error; end
  class NonHtmlError < Error; end

  def self.fetch(url)
    new.fetch(url)
  end

  def fetch(url)
    response = connection.get(url)

    if response.status >= 400 && response.status < 500
      raise HttpError.new(response.status)
    end
    raise HttpError.new(response.status) unless response.success?

    content_type = response.headers["content-type"].to_s.downcase
    if content_type.present? && !content_type.include?("html")
      raise NonHtmlError, "source returned non-HTML content type #{content_type.inspect}"
    end

    html = response.body.to_s
    Page.new(html: html, text: clean_text(html), content_type: content_type)
  rescue Faraday::TimeoutError => e
    raise TimeoutError, e.message
  rescue Faraday::ConnectionFailed, Faraday::SSLError => e
    raise NetworkError, e.message
  end

  private

  def connection
    @connection ||= Faraday.new do |conn|
      conn.options.timeout = TIMEOUT
      conn.options.open_timeout = TIMEOUT
      conn.headers["User-Agent"] = "CookbookRecipeImporter/1.0"
      conn.adapter Faraday.default_adapter
    end
  end

  def clean_text(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style, nav").remove
    doc.text.to_s.gsub(/\s+/, " ").strip
  end
end
