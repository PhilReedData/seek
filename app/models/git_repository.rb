require 'git'

class GitRepository < ApplicationRecord
  belongs_to :resource, polymorphic: true
  after_create :initialize_local_repository
  after_create :setup_remote, if: -> { remote.present? }

  acts_as_uniquely_identifiable

  def local_path
    File.join(Seek::Config.git_filestore_path, uuid)
  end

  def git_base
    return unless persisted?
    @git_base ||= Git.open(local_path)
  end

  def fetch
    git_base.fetch
  end

  private

  def initialize_local_repository
    Git.init(local_path)
  end

  def setup_remote
    git_base.add_remote('origin', remote)
    RemoteGitCheckoutJob.new(self).queue_job
  end
end