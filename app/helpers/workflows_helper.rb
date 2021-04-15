module WorkflowsHelper
  def port_types(port)
    return content_tag(:span, 'n/a', class: 'none_text') if port.type.nil?

    if port.type.is_a?(Array) && port.type.length > 1
      type_tag = content_tag(:ul) do
        port.type.map do |type|
          content_tag(:li, type)
        end
      end
    else
      type = port.type.is_a?(Array) ? port.type.first : port.type
      type_tag = content_tag(:span, type)
    end

    if port.optional?
      type_tag + content_tag(:span, ' (Optional)', class: 'subtle')
    else
      type_tag
    end
  end

  def maturity_badge(level)
    content_tag(:span,
                t("maturity_level.#{level}"),
                class: "maturity-level label #{level == :released ? 'label-success' : 'label-warning'}")
  end

  def test_status_badge(status)
    case status
    when :all_passing
      label_class = 'label-success'
      label = t("test_status.#{status}")
    when :some_passing
      label_class = 'label-warning'
      label = t("test_status.#{status}")
    when :all_failing
      label_class = 'label-danger'
      label = t("test_status.#{status}")
    else
      label_class = 'label-default'
      label = t('test_status.not_available')
    end
    content_tag(:span, "Tests: #{label}", class: "test-status label #{label_class}")
  end

  def run_workflow_url(workflow_version)
    if workflow_version.workflow_class_title == 'Galaxy'
      "#{Seek::Config.galaxy_instance_trs_import_url}&trs_id=#{workflow_version.parent.id}&trs_version=#{workflow_version.version}"
    end
  end

  # the dropdown button for RO Crate
  def ro_crate_dropdown(workflow, version)
    if workflow.content_blob.file_exists?
      dropdown_button('RO-Crate', 'ro_crate_file', menu_options: { id: 'ro-crate-menu' }) do      
        content_tag(:li) do
          icon_link_to 'Download RO-Crate', :download, ro_crate_workflow_path(workflow, version: version, code: params[:code])
        end +
        content_tag(:li) do
          icon_link_to 'Preview RO-Crate', :search, ro_crate_preview_workflow_path(workflow, version: version, code: params[:code])
        end        
      end    
    else
      button_link_to('RO-Crate', :ro_crate_file, nil, disabled_reason: 'This workflow is still being processed, check back later.')
    end
  end
end
