class StudyhubResource < ApplicationRecord

  belongs_to :assay, optional: true, dependent: :destroy
  belongs_to :study, optional: true, dependent: :destroy
  belongs_to :studyhub_resource_type, inverse_of: :studyhub_resources

  has_many :children_relationships, class_name: 'StudyhubResourceRelationship',
                                    foreign_key: 'parent_id',
                                    dependent: :destroy

  has_many :children, through: :children_relationships

  has_many :parents_relationships, class_name: 'StudyhubResourceRelationship',
                                   foreign_key: 'child_id',
                                   dependent: :destroy

  has_many :parents, through: :parents_relationships
  # has_and_belongs_to_many :documents, -> { distinct }



  has_extended_custom_metadata
  acts_as_asset

  #validate :studyhub_resource_type_id_not_changed, on: :update

  store_accessor :resource_json, :studySecondaryOutcomes, :studyAnalysisUnit, :acronyms
  attr_readonly :studyhub_resource_type_id


  def title
    if resource_json.nil?
      ''
    else
      "#{resource_json['resource_titles'].first['title']}"
    end
  end

  def description
    if resource_json.nil?
      ''
    else
      "#{resource_json['resource_descriptions'].first['description_text']}"
    end
  end

  #@todo: check this validation, it is not working now
  def studyhub_resource_type_id_not_changed
    if studyhub_resource_type_id_changed? && self.persisted?
      errors.add(:base, "Change of studyhub resource type is not allowed!")
    end
  end

  def add_child(child)
    children_relationships.create(child_id: child.id)
  end

  def remove_child(child)
    children_relationships.find_by(child_id: child.id).destroy
  end

  def is_parent?(child)
    children.include?(child)
  end

  def add_parent(parent)
    parents_relationships.create(parent_id: parent.id)
  end

  def remove_parent(parent)
    parents_relationships.find_by(parent_id: parent.id).destroy
  end

  def is_child?(parent)
    parents.include?(parent)
  end

  # if the resource type is study or substudy
  def is_studytype?
    self.studyhub_resource_type.is_study? || self.studyhub_resource_type.is_substudy?
  end


end