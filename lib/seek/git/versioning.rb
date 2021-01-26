module Seek
  module Git
    module Versioning
      def self.included(mod)
        mod.extend(ClassMethods)
      end

      module ClassMethods
        def git_versioning(options = {}, &extension)
          # don't allow multiple calls
          return if reflect_on_association(:git_versions)

          cattr_accessor :proxy_class_name
          self.proxy_class_name = options[:proxy_class_name]  || 'ResourceProxy'

          class_eval do
            has_many :git_versions, as: :resource, dependent: :destroy
            has_one :local_git_repository, as: :resource, class_name: 'GitRepository'
            delegate :git_base, :file_contents, :object, :commit, :tree, :trees, :blobs, to: :latest_git_version

            attr_writer :git_version_attributes

            after_create :save_git_version_on_create

            def latest_git_version
              git_versions.last
            end

            def save_git_version_on_create
              version = self.git_versions.build(git_version_attributes)
              version.metadata = self.attributes
              version.save
            end

            def git_version_attributes
              (@git_version_attributes || {}).with_indifferent_access.slice(:name, :description, :ref, :root_path, :git_repository_id).reverse_merge(default_git_version_attributes)
            end

            def default_git_version_attributes
              { name: "Version #{git_versions.count + 1}", ref: 'refs/heads/master' }
            end

            # def state_allows_download?(*args)
            #   latest_git_version.commit.present?
            # end

            def self.proxy_class
              const_get(proxy_class_name)
            end
          end

          # The proxy object that will behave like the resource, but using attributes stored in the GitVersion.
          const_set(proxy_class_name, Class.new(::ResourceProxy))
          proxy_class.class_eval(&extension) if block_given?
        end
      end
    end
  end
end