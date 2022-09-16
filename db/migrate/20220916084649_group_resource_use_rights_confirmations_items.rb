class GroupResourceUseRightsConfirmationsItems < ActiveRecord::Migration[5.2]
  def change
    study_resources = StudyhubResource.all

    study_resources.each do |sr|
      json = sr.resource_json
      json['resource_use_rights_support_by_licencing'].nil?


      if json.key?('resource_use_rights_support_by_licencing')

        resource_use_rights_confirmations = {}
        resource_use_rights_confirmations['resource_use_rights_authors_confirmation_1'] = json['resource_use_rights_authors_confirmation_1']
        resource_use_rights_confirmations['resource_use_rights_authors_confirmation_2'] = json['resource_use_rights_authors_confirmation_2']
        resource_use_rights_confirmations['resource_use_rights_authors_confirmation_3'] = json['resource_use_rights_authors_confirmation_3']
        resource_use_rights_confirmations['resource_use_rights_support_by_licencing'] = json['resource_use_rights_support_by_licencing']
        json['resource_use_rights_confirmations'] = resource_use_rights_confirmations

        json.delete('resource_use_rights_authors_confirmation_1')
        json.delete('resource_use_rights_authors_confirmation_2')
        json.delete('resource_use_rights_authors_confirmation_3')
        json.delete('resource_use_rights_support_by_licencing')

        sr.update_column(:resource_json, json)

      end
    end
  end
end
