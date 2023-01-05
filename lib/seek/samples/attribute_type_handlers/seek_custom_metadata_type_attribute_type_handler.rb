module Seek
  module Samples
    module AttributeTypeHandlers
      class SeekCustomMetadataTypeAttributeTypeHandler < BaseAttributeHandler
        def test_value(array_value)
          Rails.logger.info("SeekCustomMetadataTypeAttributeTypeHandler")
          Rails.logger.info("array_value:"+array_value.inspect)
        end
      end
    end
  end
end


