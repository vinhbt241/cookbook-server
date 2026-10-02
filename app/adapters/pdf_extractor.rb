# Reads the text layer of a PDF and falls back to OCR for scanned pages.
#
# This is the adapter seam for PDF text extraction in the parse pipeline. The
# rest of the system only talks to this class, so specs can stub it without
# touching pdf-reader, pdftoppm, or tesseract.
require "base64"
require "fileutils"
require "open3"
require "pdf/reader"
require "tmpdir"

class PdfExtractor
  OCR_DPI = 300

  class Error < StandardError
    attr_reader :error_code

    def initialize(error_code:, message: nil)
      @error_code = error_code
      super(message || error_code)
    end
  end

  class TextExtractionError < Error
    def initialize(message = nil)
      super(error_code: "pdf_text_extraction_error", message: message)
    end
  end

  class OcrError < Error
    def initialize(message = nil)
      super(error_code: "pdf_ocr_error", message: message)
    end
  end

  def self.extract_text(data_uri)
    new.extract_text(data_uri)
  end

  def self.ocr(data_uri)
    new.ocr(data_uri)
  end

  # Extracts the PDF's embedded text layer. Returns an empty string when the
  # PDF has no text layer (for example a scan).
  def extract_text(data_uri)
    pdf_path = write_pdf(data_uri)
    PDF::Reader.new(pdf_path).pages.map(&:text).join("\n").strip
  rescue PDF::Reader::Error => e
    raise TextExtractionError, "failed to read PDF text layer: #{e.message}"
  ensure
    FileUtils.rm_f(pdf_path) if pdf_path
  end

  # Renders each page and OCRs it. Returns the concatenated page text.
  def ocr(data_uri)
    pdf_path = nil
    work_dir = nil

    pdf_path = write_pdf(data_uri)
    work_dir = Dir.mktmpdir("pdf-ocr")
    page_paths = render_pages(pdf_path, work_dir)

    return "" if page_paths.empty?

    page_paths.map { |page_path| run_tesseract(page_path) }.join("\n").strip
  rescue Error
    raise
  rescue => e
    raise OcrError, "failed to OCR PDF: #{e.message}"
  ensure
    FileUtils.rm_f(pdf_path) if pdf_path
    FileUtils.rm_rf(work_dir) if work_dir
  end

  private

  def write_pdf(data_uri)
    header, payload = data_uri.to_s.split(",", 2)
    media_type = header.to_s.split(";", 2).first
    unless media_type.to_s.start_with?("data:application/pdf") && payload.present?
      raise TextExtractionError, "source must be a PDF data URI"
    end

    file = Tempfile.new([ "recipe", ".pdf" ])
    file.binmode
    file.write(Base64.decode64(payload))
    file.flush
    file.path
  end

  def render_pages(pdf_path, work_dir)
    prefix = File.join(work_dir, "page")
    _stdout, stderr, status = Open3.capture3("pdftoppm", "-png", "-r", OCR_DPI.to_s, pdf_path, prefix)
    raise OcrError, "pdftoppm failed: #{stderr.strip}" unless status.success?

    Dir[File.join(work_dir, "page-*.png")].sort_by { |path| path[/page-(\d+)\.png\z/, 1].to_i }
  end

  def run_tesseract(page_path)
    stdout, stderr, status = Open3.capture3("tesseract", page_path, "stdout")
    raise OcrError, "tesseract failed: #{stderr.strip}" unless status.success?

    stdout.to_s.strip
  end
end
