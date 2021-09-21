module Seek
  module BioSchema
    module ResourceDecorators
      # Decorator that provides extensions for a Event
      class CreativeWork < Thing
        associated_items producer: :projects,
                         part_of: :collections,
                         subject_of: :events

        schema_mappings version: :version,
                        sd_publisher: :sdPublisher,
                        license: :license,
                        all_creators: :creator,
                        producer: :producer,
                        created_at: :dateCreated,
                        updated_at: :dateModified,
                        content_type: :encodingFormat,
                        subject_of: :subjectOf,
                        part_of: :isPartOf,
			                  previous_version_url: :isBasedOn

        def content_type
          return unless resource.respond_to?(:content_blob) && resource.content_blob

          resource.content_blob.content_type
        end

        def license
          return unless resource.license
          Seek::License.find(resource.license)&.url
        end

        def all_creators
          # This should be greatly improved but would rely on SEEK being changed
          others = other_creators&.split(',')&.collect(&:strip)&.compact || []
          others = others.collect { |name| { "@type": 'Person',"@id": "##{ROCrate::Entity.format_id(name)}", "name": name } }
          all = (mini_definitions(creators) || []) + others
          return if all.empty?
          all
        end

	      def previous_version_url
          return unless respond_to?(:previous_version) && resource.previous_version
          resource_url(resource.previous_version)
        end

        def sd_publisher
          DataCatalogMockModel.new.provider
        end
      end
    end
  end
end
