module RecipeImport
  # Reads width and height from the headers of the image formats DeepSeek
  # vision accepts (JPEG, PNG, GIF, WebP). Used to enforce the vendor's
  # per-side dimension limit before an image is submitted.
  #
  # Returns [width, height] in pixels, or nil when the bytes are not a
  # recognised image header.
  module ImageDimensions
    module_function

    def of(bytes)
      width, height = png_dimensions(bytes) ||
        gif_dimensions(bytes) ||
        jpeg_dimensions(bytes) ||
        webp_dimensions(bytes)

      width && height ? [ width, height ] : nil
    end

    def png_dimensions(bytes)
      return unless bytes.bytesize >= 24
      return unless bytes.start_with?("\x89PNG\r\n\x1a\n".b)

      [ bytes.byteslice(16, 4).unpack1("N"), bytes.byteslice(20, 4).unpack1("N") ]
    end
    private_class_method :png_dimensions

    def gif_dimensions(bytes)
      return unless bytes.bytesize >= 10
      return unless bytes.start_with?("GIF87a".b) || bytes.start_with?("GIF89a".b)

      [ bytes.byteslice(6, 2).unpack1("v"), bytes.byteslice(8, 2).unpack1("v") ]
    end
    private_class_method :gif_dimensions

    def jpeg_dimensions(bytes)
      return unless bytes.start_with?("\xFF\xD8".b)

      pos = 2
      while pos + 4 <= bytes.bytesize
        return unless bytes.getbyte(pos) == 0xFF

        marker = bytes.getbyte(pos + 1)
        if sof_marker?(marker)
          return nil if pos + 9 > bytes.bytesize

          return [ bytes.byteslice(pos + 7, 2).unpack1("n"),
                   bytes.byteslice(pos + 5, 2).unpack1("n") ]
        end

        length = bytes.byteslice(pos + 2, 2).unpack1("n")
        pos += 2 + length
      end

      nil
    end
    private_class_method :jpeg_dimensions

    def sof_marker?(marker)
      marker && (0xC0..0xCF).cover?(marker) && ![ 0xC4, 0xC8, 0xCC ].include?(marker)
    end
    private_class_method :sof_marker?

    def webp_dimensions(bytes)
      return unless bytes.start_with?("RIFF".b) && bytes.byteslice(8, 4) == "WEBP".b

      case bytes.byteslice(12, 4)
      when "VP8 ".b
        vp8_dimensions(bytes)
      when "VP8L".b
        vp8l_dimensions(bytes)
      when "VP8X".b
        vp8x_dimensions(bytes)
      end
    end
    private_class_method :webp_dimensions

    def vp8_dimensions(bytes)
      return unless bytes.bytesize >= 30

      [ bytes.byteslice(26, 2).unpack1("v") & 0x3FFF,
        bytes.byteslice(28, 2).unpack1("v") & 0x3FFF ]
    end
    private_class_method :vp8_dimensions

    def vp8l_dimensions(bytes)
      return unless bytes.bytesize >= 25

      bits = bytes.byteslice(21, 4).unpack1("V")

      [ (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1 ]
    end
    private_class_method :vp8l_dimensions

    def vp8x_dimensions(bytes)
      return unless bytes.bytesize >= 30

      width = bytes.getbyte(24) | (bytes.getbyte(25) << 8) | (bytes.getbyte(26) << 16)
      height = bytes.getbyte(27) | (bytes.getbyte(28) << 8) | (bytes.getbyte(29) << 16)

      [ width + 1, height + 1 ]
    end
    private_class_method :vp8x_dimensions
  end
end
