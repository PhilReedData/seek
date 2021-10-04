class SinglePagesController < ApplicationController
  include Seek::AssetsCommon
  before_action :set_up_instance_variable
  before_action :single_page_enabled
  before_action :project_membership_required, only: [:render_item_detail]
  respond_to :html, :js
  
  def show
    @project = Project.find(params[:id])
    @folders = project_folders
    @investigation = Investigation.new
    @study = Study.new
    @assay = Assay.new

    @is_folders = params.has_key?(:is_folders) ? params[:is_folders] : false

    respond_to do |format|
      format.html
    end
  end
  
  def index
  end

  def single_page_enabled
    unless Seek::Config.project_single_page_enabled
      flash[:error]="Not available"
      redirect_to Project.find(params[:id])
    end
  end

  def project_folders
    project_folders =  ProjectFolder.root_folders(@project)
    if project_folders.empty?
      project_folders = ProjectFolder.initialize_default_folders(@project)
      ProjectFolderAsset.assign_existing_assets @project
    end
    project_folders
  end

  def set_up_instance_variable
    @single_page = true
  end

end