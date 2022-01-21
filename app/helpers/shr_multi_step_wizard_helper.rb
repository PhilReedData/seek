# helper methods to support a wizard like form with multiple steps (e.g. for data file uploads)
module ShrMultiStepWizardHelper

  def shr_cancel_comfirm_button
    cancel_button(new_studyhub_resource_path, button_text: 'Yes, I will continue to cancel', class: 'btn-secondary' )
  end

  def shr_cancel_button
    link_to 'Cancel', '#', class: 'shr_cancel_button btn btn-default', type: 'button',  data: { toggle: 'modal', target:'#leave-alert-modal'}
  end

  def shr_leave_alert_modal
    render partial: 'studyhub_resources/leave_alert'
  end

  def shr_multi_step_back_icons
    content_tag(:button, ' ', class: 'multi-step-start-icon') +
      content_tag(:button, ' ', class: 'multi-step-back-icon')
  end

  def shr_multi_step_forward_icons
    content_tag(:button, ' ', class: 'multi-step-next-icon') +
      content_tag(:button, ' ', class: 'multi-step-end-icon')
  end

  def shr_multi_step_start_button
    content_tag(:button, 'Start', class: 'multi-step-start-button btn btn-default')
  end

  def shr_multi_step_end_button
    content_tag(:button, 'End', class: 'multi-step-end-button btn btn-default')
  end

  def shr_multi_step_back_button
    content_tag(:button, 'Back', class: 'multi-step-back-button btn btn-default')
  end

  def shr_multi_step_forward_button
    content_tag(:button, 'Next', class: 'multi-step-next-button btn btn-primary')
  end


  def shr_wizard_footer_tips
    # help = content_tag(:span, id: 'help_link') { help_link(:data_file_wizard, link_text: 'Wizard guide', include_icon: true) }
    content_tag :div, id: 'wizard-footer-tips' do
      'Fields marked with a <label class="save-required"></label> are required before you can save the resource,
       fields marked with a <label class="submit-required"></label> are required before you can submit the resource,
       other fields are optional.'.html_safe
    end
  end

  def shr_forward_params(key)
    html = ''
    if params[key]
      params[key][:assay_assets_attributes]&.each do |p|
        html << hidden_field_tag('data_file[assay_assets_attributes[][assay_id]]', p[:assay_id])
      end
      if params[key][:event_ids]
        html << hidden_field_tag('data_file[event_ids][]', params[key][:event_ids])
      end
      if params[key][:publication_ids]
        html << hidden_field_tag('data_file[publication_ids][]', params[key][:publication_ids])
      end
    end
    html.html_safe
  end

  def shr_extraction_forward_payload_json(resource, key)
    {
      content_blob_id: resource.content_blob.id,
      key => {
        assay_assets_attributes: resource.assay_assets.collect(&:assay_id).collect { |id| { assay_id: id.to_s } },
        event_ids: resource.events.collect(&:id),
        publication_ids: resource.publications.collect(&:id)
      }
    }
  end
end