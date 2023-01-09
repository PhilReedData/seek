module Seek
  module Samples
    module AttributeTypeHandlers
      class SeekCustomMetadataTypeAttributeTypeHandler < BaseAttributeHandler

        def test_value(array_value)


        end

        def convert(value)
          linked_custom_metadata_id = value['linked_custom_metadata_id']
          linked_custom_metadata_type_id = value['linked_custom_metadata_type_id']
          if linked_custom_metadata_id.blank?
            #todo if the CustomMetadata is wrong, will the validation work?
            value = CustomMetadata.create!(custom_metadata_type_id: linked_custom_metadata_type_id, data: value['value']).id
          else
            CustomMetadata.find(linked_custom_metadata_id).update!(data: value['value'])
            value = linked_custom_metadata_id
          end
          value
        end
      end
    end
  end
end


