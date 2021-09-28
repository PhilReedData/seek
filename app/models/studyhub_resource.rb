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
  has_one :content_blob,:as => :asset, :foreign_key => :asset_id


  has_extended_custom_metadata
  acts_as_asset

  validate :studyhub_resource_type_id_not_changed, on: :update
  validate :check_title_presence, on:  [:create, :update]
  validate :check_role_presence, on: [:create, :update], if: :request_to_submit?
  validate :check_acronym_presence, on:  [:create, :update], if: :request_to_submit?
  validate :check_description_presence, on:  [:create, :update], if: :request_to_submit?
  validate :full_validations_before_submit, on:  [:create, :update], if: :request_to_submit?

  attr_readonly :studyhub_resource_type_id
  attr_accessor :commit_button
  before_save :update_working_stage, on:  [:create, :update]

  # *****************************************************************************
  #  This section defines constants for "mandatory fields" values
  #
  REQUIRED_FIELDS_RESOURCE = ['resource_type_general','resource_use_rights_label']
  REQUIRED_FIELDS_STUDY_DESIGN_GENERAL = ['study_primary_design','study_status', 'study_population','study_data_sharing_plan_generally']
  REQUIRED_FIELDS_INTERVENTIONAL = ['study_type_interventional','study_primary_outcome_title']
  REQUIRED_FIELDS_NON_INTERVENTIONAL =['study_type_non_interventional']
  INTERVENTIONAL = 'Interventional'
  NON_INTERVENTIONAL = 'Non-interventional'

  # *****************************************************************************
  #  This section defines constants for "working stages" values

  SAVED = 0
  SUBMITTED  = 1
  WAITING_FOR_APPROVEL = 2
  PUBLISHED = 3

  def description
    if resource_json.nil? || resource_json['resource_descriptions'].blank?
      'Studyhub Resources'
    else
      "#{resource_json['resource_descriptions'].first['description']}"
    end
  end

  def check_title_presence
    errors.add(:base, "Please add at least one title for the #{studyhub_resource_type_title}.") if title.blank?
  end

  def check_role_presence

    if resource_json['roles'].blank?
      errors.add(:base, "Please add at least one resource role for the #{studyhub_resource_type_title}.")
    else
      resource_json['roles'].each_with_index do |role,index|
        errors.add("roles[#{index}]['role_type']".to_sym, "can't be blank")  if role['role_type'].blank?
        errors.add("roles[#{index}]['role_name_type']".to_sym, "can't be blank")  if role['role_name_type'].blank?
        if role['role_name_type'] == 'Personal'
          errors.add("roles[#{index}]['role_name_personal_title']".to_sym, "can't be blank")  if role['role_name_personal_title'].blank?
          errors.add("roles[#{index}]['role_name_personal_given_name']".to_sym, "can't be blank")  if role['role_name_personal_given_name'].blank?
          errors.add("roles[#{index}]['role_name_personal_family_name']".to_sym, "can't be blank")  if role['role_name_personal_family_name'].blank?
          errors.add("roles[#{index}]['role_name_identifier_scheme']".to_sym, "Please select the identifier scheme.") if  !role['role_name_identifier'].blank? && role['role_name_identifier_scheme'].blank?
        end

        if role['role_name_type'] == 'Organisational'
          errors.add("roles[#{index}]['role_name_organisational']".to_sym, "can't be blank")  if role['role_name_organisational'].blank?
          errors.add("roles[#{index}]['role_affiliation_identifier_scheme']".to_sym, "Please select the affiliation identifier scheme.")  if !role['role_affiliation_identifier'].blank? && role['role_affiliation_identifier_scheme'].blank?
        end
      end
      errors.add(:base, "Please add the required fields for resource roles.") if errors.messages.keys.select {|x| x.to_s.include? "roles" }.size  > 0
    end
  end

  def check_acronym_presence
    errors.add(:acronym, "can't be blank") if resource_json['resource_acronyms'].blank?
  end

  def check_description_presence
    errors.add(:description, "can't be blank") if resource_json['resource_descriptions'].blank?
  end

  def full_validations_before_submit
    required_fields ={}
    required_fields['resource'] = REQUIRED_FIELDS_RESOURCE
    if is_studytype?
      required_fields['study_design'] =  REQUIRED_FIELDS_STUDY_DESIGN_GENERAL
      required_fields['study_design'] += REQUIRED_FIELDS_INTERVENTIONAL if get_study_primary_design_type == INTERVENTIONAL
      required_fields['study_design'] += REQUIRED_FIELDS_NON_INTERVENTIONAL if get_study_primary_design_type == NON_INTERVENTIONAL
    end

    required_fields.each do |type, fields|
      fields.each do |name|
        errors.add(name.to_sym, "Please enter the #{name.humanize.downcase}") if resource_json[type][name].blank?
      end
    end

    errors.add(:base, 'Please make sure all required fields are filled in correctly.') unless errors.messages.empty?

  end

  def check_content_blob_presence
    unless is_studytype?
      errors.add(:base, "Please save the #{studyhub_resource_type_title} at first and then upload a file  ") if content_blob.blank?
    end
  end


  def request_to_submit?
    (commit_button == 'Submit') ? true : false
  end

  def is_submitted?
    stage == StudyhubResource::SUBMITTED
  end

  #@todo: check this validation, it is not working now
  def studyhub_resource_type_id_not_changed
    if studyhub_resource_type_id_changed? && self.persisted?
      errors.add(:base, 'Change of studyhub resource type is not allowed!')
    end
  end

  def studyhub_resource_type_title
    StudyhubResourceType.find(studyhub_resource_type_id).title.downcase
  end

  def update_working_stage
    self.stage = if request_to_submit?
                   StudyhubResource::SUBMITTED
                 else
                   StudyhubResource::SAVED
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

  # if the resource type is study or substudy
  def get_study_primary_design_type
    resource_json['study_design']['study_primary_design']
  end

  # translates stage codes into human-readable form
  def self.get_stage_wording(stage)
    case stage
    when StudyhubResource::SAVED
      'saved'
    when StudyhubResource::SUBMITTED
      'submitted'
    when StudyhubResource::WAITING_FOR_APPROVEL
      'waiting for approval'
    when StudyhubResource::PUBLISHED
      'published'
    else
      'unknown'
    end
  end

end
