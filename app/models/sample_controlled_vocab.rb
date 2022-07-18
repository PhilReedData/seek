class SampleControlledVocab < ApplicationRecord
  # attr_accessible :title, :description, :sample_controlled_vocab_terms_attributes

  has_many :sample_controlled_vocab_terms, inverse_of: :sample_controlled_vocab,
                                           after_add: :update_sample_type_templates,
                                           after_remove: :update_sample_type_templates,
                                           dependent: :destroy
  has_many :sample_attributes, inverse_of: :sample_controlled_vocab
  has_many :custom_metadata_attributes, inverse_of: :sample_controlled_vocab

  has_many :sample_types, through: :sample_attributes
  has_many :samples, through: :sample_types
  belongs_to :repository_standard, inverse_of: :sample_controlled_vocabs

  auto_strip_attributes :ols_root_term_uri

  validates :title, presence: true, uniqueness: true
  validates :ols_root_term_uri, url: { allow_blank: true }
  validates :key, uniqueness: { allow_blank: true }

  accepts_nested_attributes_for :sample_controlled_vocab_terms, allow_destroy: true
  accepts_nested_attributes_for :repository_standard, :reject_if => :check_repository_standard

  grouped_pagination

  def labels
    sample_controlled_vocab_terms.collect(&:label)
  end

  def includes_term?(value)
    labels.include?(value)
  end

  def can_delete?(user = User.current_user)
    sample_types.empty? && can_edit?(user)
  end

  def can_edit?(user = User.current_user)
    return false unless Seek::Config.samples_enabled
    return false unless user
    return true if user.is_admin?

    !system_vocab? && samples.empty? && (!Seek::Config.project_admin_sample_type_restriction || user.is_admin_or_project_administrator?)
  end

  # a vocabulary that is built in and seeded, and that other parts are dependent upon
  def system_vocab?
    # currently determined by whether it has a special key, which cannot be set by user defined CV's
    key.present? && SystemVocabs.key_known?(key)
  end

  def self.can_create?
    # criteria is the same, and likely to always be
    SampleType.can_create?
  end

  # whether the controlled vocab is linked to an ontology
  def ontology_based?
    source_ontology.present? && ols_root_term_uri.present?
  end

  private

  def update_sample_type_templates(_term)
    sample_types.each(&:queue_template_generation) unless new_record?
  end

  class SystemVocabs

    KEYS = {
      topics: 'edam_topics',
      operations: 'edam_operations',
      formats: 'edam_formats',
      data: 'edam_data'
    }

    def self.key_known?(key)
      KEYS.values.include?(key)
    end

    KEYS.each do |k, v|
      define_singleton_method "#{k}_controlled_vocab" do
        SampleControlledVocab.find_by_key(v)
      end
    end

  end
  
end
