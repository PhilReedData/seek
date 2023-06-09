class CustomMetadata < ApplicationRecord
  include Seek::JSONMetadata::Serialization

  belongs_to :item, polymorphic: true
  belongs_to :custom_metadata_type, validate: true
  belongs_to :custom_metadata_attribute

  has_many :custom_metadata_resource_links, inverse_of: :custom_metadata, dependent: :destroy
  has_many :linked_custom_metadatas, through: :custom_metadata_resource_links, source: :resource, source_type: 'CustomMetadata', dependent: :destroy
  accepts_nested_attributes_for :linked_custom_metadatas

  validates_with CustomMetadataValidator
  validates_associated :linked_custom_metadatas

  delegate :custom_metadata_attributes, to: :custom_metadata_type


  after_save :update_linked_custom_metadata_id, if: :has_linked_custom_metadatas?

  def update_linked_custom_metadata_id
    linked_custom_metadatas.each do |cm|
      attr_name = cm.custom_metadata_attribute.title
      if cm.custom_metadata_attribute.linked_custom_metadata?
        data.mass_assign(data.to_hash.update({attr_name => cm.id}), pre_process: false)
      elsif cm.custom_metadata_attribute.linked_custom_metadata_multi?
        ids = data[attr_name].nil? ? [] : data[attr_name]
        ids = ids.append(cm.id)
        data.mass_assign(data.to_hash.update({attr_name => ids}), pre_process: false)
      end
      update_column(:json_metadata, data.to_json)
      self.item.reload
    end
  end

  def has_linked_custom_metadatas?
    linked_custom_metadatas.any?
  end


  # for polymorphic behaviour with sample
  alias_method :metadata_type, :custom_metadata_type

  def custom_metadata_type=(type)
    super
    @data = Seek::JSONMetadata::Data.new(type)
    update_json_metadata
    type
  end

  def attribute_class
    CustomMetadataAttribute
  end

  def update_linked_custom_metadata(parameters)
    cmt_id = parameters[:custom_metadata_type_id]

    # return no custom metdata is filled
    seek_linked_cm_attrs = CustomMetadataType.find(cmt_id).custom_metadata_attributes.select {|attr|attr.linked_custom_metadata? || attr.linked_custom_metadata_multi? }
    return if seek_linked_cm_attrs.blank?


    seek_linked_cm_attrs&.each  do |cma|
      cma_params = parameters[:data][cma.title.to_sym]
      set_linked_custom_metadatas(cma, cma_params) unless cma_params.nil?
      cma_linked_cmt =  cma.linked_custom_metadata_type.attributes_with_linked_custom_metadata_type

      unless cma_linked_cmt.blank?
        cm = self.linked_custom_metadatas.select{|cm| cm.custom_metadata_type.id == cma[:linked_custom_metadata_type_id]}.first
        cm.update_linked_custom_metadata(cma_params)
      end

    end
  end

  def set_linked_custom_metadatas(cma, cm_params)

    if cma.linked_custom_metadata_multi?
      keys = cm_params.keys
      keys.delete("row-template")
      keys.each do |index|
        update_a_custom_metadata(cma,cm_params[index])
      end
    else
      update_a_custom_metadata(cma,cm_params)
    end
  end

  def update_a_custom_metadata(cma,cm_params)

    if self.new_record? || cm_params[:id].blank?
      self.linked_custom_metadatas.build(custom_metadata_type: cma.linked_custom_metadata_type, data: cm_params[:data], custom_metadata_attribute_id: cm_params[:custom_metadata_attribute_id])
    else
      linked_cm = CustomMetadata.find(cm_params[:id])
      #todo find right linked_cm when multi linked cm
      linked_cm.update(cm_params.permit!)
    end
  end

end
