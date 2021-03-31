require 'ro_crate'
require 'seek/download_handling/http_streamer'

# A kind of "form object" to instantiate a workflow from a given git repository, target ref, and several paths in that
# repository that indicate where to find the main workflow, diagram etc..
# Alternatively, these paths can be inferred from RO-Crate metadata, if present.
#
class GitWorkflowWizard
  include ActiveModel::Model

  attr_reader :next_step, :workflow, :workflow_class, :git_repository

  attr_accessor :git_repository_id,
                :git_commit,
                :ref,
                :main_workflow_path,
                :abstract_cwl_path,
                :diagram_path,
                :workflow_class_id,
                :workflow_params

  validates :git_repository_id, presence: true
  validates :main_workflow_path, presence: true
  validates :workflow_class_id, presence: true

  def setup_repository
    # If remote
    #   Queue fetch job
    #   Render "waiting" page
    # If local files
    #   Create local repo
    #   Add local files
    #   Go to next
    # If local RO-Crate
    #   Create local repo
    #   Extract crate
    #   Add files to repo
    #   Go to next
  end

  def select_paths
    # If ro-crate-metadata present
    #   Pick paths from file
    #   If main workflow path not present
    #     Render "select paths" page
    #   Otherwise
    #     Go to next
    # If not
    #   Render "select paths" page
  end

  def extract_metadata
    # If abstract CWL present
    #   Extract metadata from that
    # If ro-crate-metadata present
    #   Extract metadata from that
    # Otherwise
    #   Extract metadata from main workflow

  end

  def create_workflow
    # Put everything into the workflow
  end

  def run
    @next_step = nil
    workflow = Workflow.new(git_version_attributes: { git_repository_id: git_repository_id, commit: git_commit, ref: ref })
    workflow_class = WorkflowClass.find_by_id(workflow_class_id)
    if workflow.file_exists?('ro-crate-metadata.json') ||  workflow.file_exists?('ro-crate-metadata.jsonld')
      workflow.in_temp_dir do |dir|
        crate = ROCrate::WorkflowCrateReader.read(dir)
        self.main_workflow_path = crate.main_workflow&.id if crate.main_workflow&.id
        self.diagram_path = crate.main_workflow&.diagram&.id if crate.main_workflow&.diagram&.id
        self.abstract_cwl_path = crate.main_workflow&.cwl_description&.id if crate.main_workflow&.cwl_description&.id

        workflow_class ||= WorkflowClass.match_from_metadata(crate&.main_workflow&.programming_language&.properties || {})
      end
    end

    unless main_workflow_path
      @next_step = :select_paths
      return workflow
    end

    workflow.workflow_class = workflow_class
    annotations_attributes = {}
    annotations_attributes['1'] = { key: 'main_workflow', path: main_workflow_path } unless main_workflow_path.blank?
    annotations_attributes['2'] = { key: 'diagram', path: diagram_path } unless diagram_path.blank?
    annotations_attributes['3'] = { key: 'abstract_cwl', path: abstract_cwl_path } unless abstract_cwl_path.blank?
    workflow.git_version.git_annotations_attributes = annotations_attributes

    extractor = workflow.extractor
    workflow.provide_metadata(extractor.metadata)

    @next_step = :provide_metadata

    workflow
  end
end