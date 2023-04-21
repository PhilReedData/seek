require 'test_helper'
require 'minitest/mock'

class GitRepositoryTest < ActiveSupport::TestCase

  test 'init local repo' do
    repo = Factory(:local_repository)
    assert File.exist?(File.join(repo.local_path, '.git', 'config'))
  end

  test 'fetch remote' do
    repo = Factory(:remote_repository)
    RemoteGitFetchJob.perform_now(repo)
    remote = repo.git_base.remotes.first

    assert_equal 'origin', remote.name
    assert remote.url.end_with?('seek4science/workflow-test-fixture.git')
    assert File.exist?(File.join(repo.local_path, '.git', 'config'))
  ensure
    FileUtils.rm_rf(repo.remote) if repo
  end

  test "don't fetch if recently fetched" do
    repo = Factory(:remote_repository, last_fetch: 5.minutes.ago)
    assert_no_difference('Task.count') do
      assert_no_enqueued_jobs(only: RemoteGitFetchJob) do
        repo.queue_fetch
      end
    end
  end

  test "fetch even if recently fetched with force option set" do
    repo = Factory(:remote_repository, last_fetch: 5.minutes.ago)
    assert_difference('Task.count', 1) do
      assert_enqueued_jobs(1, only: RemoteGitFetchJob) do
        repo.queue_fetch(true)
      end
    end
  end

  test "fetch if not recently fetched" do
    repo = Factory(:remote_repository, last_fetch: 30.minutes.ago)
    assert_difference('Task.count', 1) do
      assert_enqueued_jobs(1, only: RemoteGitFetchJob) do
        repo.queue_fetch
      end
    end
  end

  test 'redundant repositories' do
    redundant = Git::Repository.create!
    not_redundant = Factory(:git_version).git_repository

    repositories = Git::Repository.redundant.to_a

    assert_includes repositories, redundant
    assert_not_includes repositories, not_redundant
  end

  test 'proxy_url' do
      https_repo = Git::Repository.new(remote: 'https://github.com/seek4science/workflow-test-fixture.git')
      http_repo = Git::Repository.new(remote: 'http://github.com/seek4science/workflow-test-fixture.git')
      local_repo = Git::Repository.new
      ssh_repo = Git::Repository.new(remote: 'git@github.com:seek4science/seek.git') # We don't support this

    Seek::Config.stub(:environment_vars, {
      'http_proxy' => 'http://myproxy:123',
      'HTTP_PROXY' => 'http://myproxy:456',
      'https_proxy' => 'http://myproxy:789',
      'HTTPS_PROXY' => 'http://myproxy:1337' }) do
      assert_equal 'http://myproxy:789', https_repo.send(:proxy_url)
      assert_equal 'http://myproxy:123', http_repo.send(:proxy_url)
      assert_nil local_repo.send(:proxy_url)
      assert_nil ssh_repo.send(:proxy_url)
    end

    Seek::Config.stub(:environment_vars, {
      'HTTP_PROXY' => 'http://myproxy:456',
      'HTTPS_PROXY' => 'http://myproxy:1337' }) do
      assert_equal 'http://myproxy:1337', https_repo.send(:proxy_url)
      assert_equal 'http://myproxy:456', http_repo.send(:proxy_url)
      assert_nil local_repo.send(:proxy_url)
      assert_nil ssh_repo.send(:proxy_url)
    end

    Seek::Config.stub(:environment_vars, {}) do
      assert_nil https_repo.send(:proxy_url)
      assert_nil http_repo.send(:proxy_url)
      assert_nil local_repo.send(:proxy_url)
      assert_nil ssh_repo.send(:proxy_url)
    end
  end
end
