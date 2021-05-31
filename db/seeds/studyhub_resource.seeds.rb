puts "Seeded Studyhub Resource Types"
ActiveRecord::FixtureSet.create_fixtures(File.join(Rails.root, "config/default_data"), "studyhub_resource_types")


puts "Seeded NFDI4Health Studyhub Resource Metadata"
int_type = SampleAttributeType.find_or_initialize_by(title:'Integer')
int_type.update_attributes(base_type: Seek::Samples::BaseType::INTEGER, placeholder: '1')

date_type = SampleAttributeType.find_or_initialize_by(title:'Date')
date_type.update_attributes(base_type: Seek::Samples::BaseType::DATE, placeholder: 'January 1, 2015')

string_type = SampleAttributeType.find_or_initialize_by(title:'String')
string_type.update_attributes(base_type: Seek::Samples::BaseType::STRING)

cv_type = SampleAttributeType.find_or_initialize_by(title:'Controlled Vocabulary')
cv_type.update_attributes(base_type: Seek::Samples::BaseType::CV)

attributes = []
StudyhubResourceType.all.each do |type|
  attributes << { label: type.title }
end

disable_authorization_checks do
  # Studyhub resource type controlled vocabs
  resource_type_cv = SampleControlledVocab.where(title: 'NFDI4Health Resource Type').first_or_create!(
    sample_controlled_vocab_terms_attributes: attributes
  )

  # NFDI4Health Studyhub Study Metadata (resource_type: study and substudy)
  CustomMetadataType.where(title: 'NFDI4Health Studyhub Resource Metadata', supported_type: 'Study').first_or_create!(
    title: 'NFDI4Health Studyhub Resource Metadata', supported_type: 'Study',
    custom_metadata_attributes: [

      CustomMetadataAttribute.where(title: 'resource_web_studyhub').create!(
        title: 'resource_web_studyhub', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'resource_web_page').create!(
        title: 'resource_web_page', required: false, sample_attribute_type: string_type
      ),
      CustomMetadataAttribute.where(title: 'resource_type').create!(
        title: 'resource_type', required: true, sample_attribute_type: cv_type, sample_controlled_vocab: resource_type_cv
      ),

      CustomMetadataAttribute.where(title: 'resource_web_mica').create!(
        title: 'resource_web_mica', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'acronym').create!(
        title: 'acronym', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'study_type').create!(
        title: 'study_type', required: false, sample_attribute_type: string_type
      ),


      CustomMetadataAttribute.where(title: 'study_start_date').create!(
        title: 'study_start_date', required: false, sample_attribute_type: date_type
      ),

      CustomMetadataAttribute.where(title: 'study_end_date').create!(
        title: 'study_end_date', required: false, sample_attribute_type: date_type
      ),


      CustomMetadataAttribute.where(title: 'study_status').create!(
        title: 'study_status', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'study_country').create!(
        title: 'study_country', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'study_eligibility').create!(
        title: 'study_eligibility', required: false, sample_attribute_type: string_type
      )

    ]
  )

  # NFDI4Health Studyhub Resource Metadata (resource_type: except study and substudy)
  CustomMetadataType.where(title: 'NFDI4Health Studyhub Resource Metadata',supported_type: 'Assay').first_or_create!(
    title: 'NFDI4Health Studyhub Resource Metadata', supported_type: 'Assay',
    custom_metadata_attributes: [

      CustomMetadataAttribute.where(title: 'resource_web_studyhub').create!(
        title: 'resource_web_studyhub', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'resource_web_page').create!(
        title: 'resource_web_page', required: false, sample_attribute_type: string_type
      ),
      CustomMetadataAttribute.where(title: 'resource_type').create!(
        title: 'resource_type', required: true, sample_attribute_type: cv_type, sample_controlled_vocab: resource_type_cv
      ),

      CustomMetadataAttribute.where(title: 'resource_web_mica').create!(
        title: 'resource_web_mica', required: false, sample_attribute_type: string_type
      ),

      CustomMetadataAttribute.where(title: 'acronym').create!(
        title: 'acronym', required: false, sample_attribute_type: string_type
      )
    ]
  )
end
