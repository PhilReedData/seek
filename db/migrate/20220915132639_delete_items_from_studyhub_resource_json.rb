class DeleteItemsFromStudyhubResourceJson < ActiveRecord::Migration[5.2]
  def change
    study_resources = StudyhubResource.all.select(&:is_studytype?)

    study_resources.each do |sr|

      json = sr.resource_json

      unless json['study_design']['study_type_description'].blank?
        json['study_design']['study_design_comment'] += "Additional information about the study type: #{json['study_design']['study_type_description']}.\n"
      end


      unless json['study_design']['study_eligibility_age_min_description'].blank?
        json['study_design']['study_design_comment'] += "Additional information about minimum age of potential study participants: #{json['study_design']['study_eligibility_age_min_description']}.\n"
      end

      unless json['study_design']['study_eligibility_age_max_description'].blank?
        json['study_design']['study_design_comment'] += "Additional information about maximum age of potential study participants: #{json['study_design']['study_eligibility_age_max_description']}.\n"
      end

      unless json['study_design']['study_age_min_examined_description'].blank?
        json['study_design']['study_design_comment'] += "Additional information about minimum age of study participants at time of examination: #{json['study_design']['study_age_min_examined_description']}.\n"
      end

      unless json['study_design']['study_age_max_examined_description'].blank?
        json['study_design']['study_design_comment'] += "Additional information about maximum age of study participants at time of examination: #{json['study_design']['study_age_max_examined_description']}.\n"
      end

      json['study_design'].delete('study_type_description')
      json['study_design'].delete('study_eligibility_age_min_description')
      json['study_design'].delete('study_eligibility_age_max_description')
      json['study_design'].delete('study_age_min_examined_description')
      json['study_design'].delete('study_age_max_examined_description')

      sr.update_column(:resource_json, json)
    end
  end
end

