require 'rubygems'
require 'rake'

namespace :seek do
  desc 'Fetch ontology terms from EBI API'
  task populate_templates: :environment do
    Seek::IsaTemplates::TemplateExtractor.extract_templates
  end
end
