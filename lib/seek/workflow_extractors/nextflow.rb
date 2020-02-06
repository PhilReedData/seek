module Seek
  module WorkflowExtractors
    class Nextflow < Base
      def metadata
        metadata = super
        config_string = @io.read
        manifest = manifest_block(config_string)
        manifest = manifest.merge(manifest_values(config_string))

        if manifest.has_key?('name')
          metadata[:title] = manifest['name']
        else
          metadata[:warnings] << 'Unable to determine title of workflow'
        end

        metadata[:description] = manifest['description'] if manifest.has_key?('description')
        metadata[:other_creators] = manifest['author'] if manifest.has_key?('author')
        #metadata[:url] = manifest['homePage'] if manifest.has_key?('homePage')

        metadata
      end

      def manifest_block(config)
        hash = {}
        lines = config.split("\n")
        open_line = lines.index { |a| a.match?(/\s*manifest\s*\{/) }
        return {} unless open_line
        line_index = open_line
        line = lines[line_index]
        until line.match?(/\s*\}\s*/) do
          matches = line.match(/\s*(.+)\s*=\s*(.+)\s*/)
          if matches
            hash[matches[1].strip] = matches[2].strip.gsub(/\A['"]+|['"]+\Z/, '')
          end
          line = lines[line_index += 1]
        end

        hash
      end

      def manifest_values(config)
        hash = {}
        config.split("\n").each do |line|
          matches = line.match(/\s*manifest\.(.+)\s*=\s*(.+)\s*/)
          next unless matches
          hash[matches[1].strip] = matches[2].strip.gsub(/\A['"]+|['"]+\Z/, '')
        end

        hash
      end
    end
  end
end
