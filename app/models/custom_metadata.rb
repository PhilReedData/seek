class CustomMetadata < ApplicationRecord
  include Seek::JSONMetadata::Serialization

  belongs_to :item, polymorphic: true
  belongs_to :custom_metadata_type, validate: true
  belongs_to :custom_metadata_attribute

  has_many :custom_metadata_resource_links, inverse_of: :custom_metadata, dependent: :destroy
  has_many :linked_custom_metadatas, through: :custom_metadata_resource_links, source: :resource, source_type: 'CustomMetadata'
  accepts_nested_attributes_for :linked_custom_metadatas, allow_destroy: true

  has_one :linked_resource, class_name: 'CustomMetadataResourceLink', foreign_key: 'resource_id'

  validates_with CustomMetadataValidator
  validates_associated :linked_custom_metadatas

  delegate :custom_metadata_attributes, to: :custom_metadata_type

  after_save :update_ids_for_the_type_linked_custom_metadata, if: :has_attr_type_linked_custom_metadata?
  after_save :update_ids_with_attribute_type_linked_custom_metadata_multi, if: :has_attr_type_linked_custom_metadata_multi?

  # for polymorphic behaviour with sample
  alias_method :metadata_type, :custom_metadata_type


  def update_ids_for_the_type_linked_custom_metadata
    linked_custom_metadatas.each do |cm|
      attr_name = cm.custom_metadata_attribute.title
      if cm.custom_metadata_attribute.linked_custom_metadata?
        data.mass_assign(data.to_hash.update({attr_name => cm.id}), pre_process: false)
      end
      update_column(:json_metadata, data.to_json)
    end
  end

  def update_ids_with_attribute_type_linked_custom_metadata_multi

    custom_metadata_attributes.select(&:linked_custom_metadata_multi?).each do |attr|
      ids = linked_custom_metadatas.select{|cm| cm.custom_metadata_attribute == attr }.pluck(:id)
      data.mass_assign(data.to_hash.update({attr.title => ids}), pre_process: false)
    end
    update_column(:json_metadata, data.to_json)
  end

  def has_linked_custom_metadatas?
    linked_custom_metadatas.any?
  end

  def has_attr_type_linked_custom_metadata?
    custom_metadata_attributes.select(&:linked_custom_metadata?).any?
  end


  def has_attr_type_linked_custom_metadata_multi?
    custom_metadata_attributes.select(&:linked_custom_metadata_multi?).any?
  end

  def get_linked_custom_metadatas_multi_by_attr(attr_id,cm)
    cm.select { |cm| cm.custom_metadata_attribute_id == attr_id }
  end


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
        cm.update_linked_custom_metadata(cma_params) unless cma_params.nil?
      end

    end
  end

  def set_linked_custom_metadatas(cma, cm_params)

    if cma.linked_custom_metadata_multi?

      # mark the element to delete
      previous_linked_cm_ids = CustomMetadata.find(id).data[cma.title] unless id.nil?
      unless self.new_record? || previous_linked_cm_ids.blank?
        current_linked_cm_ids = cm_params.values.pluck(:id).map(&:to_i)
        # current_linked_cm_ids = data[cma.title].values.pluck(:id).map(&:to_i)
        ids_to_delete = previous_linked_cm_ids - current_linked_cm_ids
        self.linked_custom_metadatas.load_target.select{|cm| ids_to_delete.include? cm.id}.each(&:mark_for_destruction)
      end

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
      self.linked_custom_metadatas.select { |linked_cm| linked_cm.id == cm_params[:id].to_i }.first.update(cm_params.permit!) unless cm_params[:data].values.all?(&:empty?)
    end
  end

end
