require 'test_helper'

class SinglePagesControllerTest < ActionController::TestCase
  include AuthenticatedTestHelper

  def setup
    @instance_name = Seek::Config.instance_name
    @member = FactoryBot.create :user
    login_as @member
  end

  test 'should show' do
    with_config_value(:project_single_page_enabled, true) do
      project = FactoryBot.create(:project)
      get :show, params: { id: project.id }
      assert_response :success
    end
  end

  test 'should hide inaccessible items in treeview' do
    project = FactoryBot.create(:project)
    FactoryBot.create(:investigation, contributor: @member.person, policy: FactoryBot.create(:private_policy),
                                      projects: [project])

    login_as(FactoryBot.create(:user))
    inv_two = FactoryBot.create(:investigation, contributor: User.current_user.person, policy: FactoryBot.create(:private_policy),
                                                projects: [project])

    controller = TreeviewBuilder.new project, nil
    result = controller.send(:build_tree_data)

    json = JSON.parse(result)[0]

    assert_equal 'hidden item', json['children'][0]['text']
    assert_equal inv_two.title, json['children'][1]['text']
  end

  test 'Should not export an isa json with unauthorized studies and assays' do
    with_config_value(:project_single_page_enabled, true) do
      current_user = FactoryBot.create(:user)
      other_user = FactoryBot.create(:user)

      login_as(current_user)
      project = FactoryBot.create(:project)
      current_user.person.add_to_project_and_institution(project, current_user.person.institutions.first)
      other_user.person.add_to_project_and_institution(project, current_user.person.institutions.first)
      investigation = FactoryBot.create(:investigation, projects: [project], contributor: current_user.person)

      source_sample_type = FactoryBot.create(:isa_source_sample_type, template_id: FactoryBot.create(:isa_source_template).id)
      sample_collection_sample_type = FactoryBot.create(:isa_sample_collection_sample_type, linked_sample_type: source_sample_type, template_id: FactoryBot.create(:isa_sample_collection_template).id)
      accessible_study = FactoryBot.create(:study,
                                            investigation: investigation,
                                            sample_types:[source_sample_type, sample_collection_sample_type],
                                            contributor: current_user.person)


      source_sample = FactoryBot.create(:sample,
      title: 'source 1',
      sample_type: source_sample_type,
      project_ids: [project.id],
      data: {
        'Source Name': 'Source Name',
        'Source Characteristic 1': 'Source Characteristic 1',
        'Source Characteristic 2':
        source_sample_type
            .sample_attributes
            .find_by_title('Source Characteristic 2')
            .sample_controlled_vocab
            .sample_controlled_vocab_terms
            .first
            .label
      },
      contributor: current_user.person)

      study_sample =
      FactoryBot.create(:sample,
              title: 'study sample 1',
              sample_type: sample_collection_sample_type,
              project_ids: [project.id],
              data: {
                Input: [source_sample.id],
                'sample collection': 'sample collection',
                'sample collection parameter value 1': 'sample collection parameter value 1',
                'Sample Name': 'sample name',
                'sample characteristic 1': 'sample characteristic 1'
              },
              contributor: current_user.person)

      hidden_study_sample =
      FactoryBot.create(:sample,
              title: 'study sample 2',
              sample_type: sample_collection_sample_type,
              project_ids: [project.id],
              data: {
                Input: [source_sample.id],
                'sample collection': 'sample collection',
                'sample collection parameter value 1': 'sample collection parameter value 2',
                'Sample Name': 'sample name 2',
                'sample characteristic 1': 'sample characteristic 2'
              },
              contributor: other_user.person)

      # Create a 'private' assay in an assay stream
      assay_1_stream_1_sample_type = FactoryBot.create(:isa_assay_material_sample_type, linked_sample_type: sample_collection_sample_type, template_id: FactoryBot.create(:isa_assay_material_template).id)
      assay_1_stream_1 = FactoryBot.create(:assay, position: 0, sample_type: assay_1_stream_1_sample_type, study: accessible_study, contributor: current_user.person)
      assay_2_stream_1_sample_type = FactoryBot.create(:isa_assay_data_file_sample_type, linked_sample_type: assay_1_stream_1_sample_type, template_id: FactoryBot.create(:isa_assay_data_file_template).id)
      assay_2_stream_1 = FactoryBot.create(:assay, position:1, sample_type: assay_2_stream_1_sample_type, study: accessible_study, contributor: other_user.person)

      # Create an assay stream with all assays visible
      assay_1_stream_2_sample_type = FactoryBot.create(:isa_assay_material_sample_type, linked_sample_type: sample_collection_sample_type, template_id: FactoryBot.create(:isa_assay_material_template).id)
      assay_1_stream_2 = FactoryBot.create(:assay, position: 0, sample_type: assay_1_stream_2_sample_type, study: accessible_study, contributor: current_user.person)
      assay_2_stream_2_sample_type = FactoryBot.create(:isa_assay_data_file_sample_type, linked_sample_type: assay_1_stream_2_sample_type, template_id: FactoryBot.create(:isa_assay_data_file_template).id)
      assay_2_stream_2 = FactoryBot.create(:assay, position:1, sample_type: assay_2_stream_2_sample_type, study: accessible_study, contributor: current_user.person)

      # create samples in second assay stream with viewing permission

      assay_1_stream_2_sample =
      FactoryBot.create(:sample,
              title: 'Assay 1 - stream 2 - sample 1',
              sample_type: assay_1_stream_2_sample_type,
              project_ids: [project.id],
              data: {
                Input: [study_sample.id],
                'Protocol Assay 1': 'Protocol Assay 1',
                'Assay 1 parameter value 1': 'Assay 1 parameter value 1',
                'Assay 1 parameter value 2': assay_1_stream_2_sample_type
                                            .sample_attributes
                                            .find_by(title: 'Assay 1 parameter value 2')
                                            .sample_controlled_vocab
                                            .sample_controlled_vocab_terms
                                            .first
                                            .label,
                'Assay 1 parameter value 3': assay_1_stream_2_sample_type
                                            .sample_attributes
                                            .find_by(title: 'Assay 1 parameter value 3')
                                            .sample_controlled_vocab
                                            .sample_controlled_vocab_terms
                                            .first
                                            .label,
                'Extract Name': 'Extract 1 stream 2',
                'other material characteristic 1': 'other material characteristic 1',
                'other material characteristic 2': assay_1_stream_2_sample_type
                                                  .sample_attributes
                                                  .find_by(title: 'other material characteristic 2')
                                                  .sample_controlled_vocab
                                                  .sample_controlled_vocab_terms
                                                  .first
                                                  .label,
                'other material characteristic 3': assay_1_stream_2_sample_type
                                                  .sample_attributes
                                                  .find_by(title: 'other material characteristic 3')
                                                  .sample_controlled_vocab
                                                  .sample_controlled_vocab_terms
                                                  .first
                                                  .label},
              contributor: current_user.person)

              assay_1_stream_2_hidden_sample =
              FactoryBot.create(:sample,
                      title: 'Assay 1 - stream 2 - sample 2',
                      sample_type: assay_1_stream_2_sample_type,
                      project_ids: [project.id],
                      data: {
                        Input: [study_sample.id],
                        'Protocol Assay 1': 'Protocol Assay 1',
                        'Assay 1 parameter value 1': 'Assay 1 parameter value 1',
                        'Assay 1 parameter value 2': assay_1_stream_2_sample_type
                                                    .sample_attributes
                                                    .find_by(title: 'Assay 1 parameter value 2')
                                                    .sample_controlled_vocab
                                                    .sample_controlled_vocab_terms
                                                    .second
                                                    .label,
                        'Assay 1 parameter value 3': assay_1_stream_2_sample_type
                                                    .sample_attributes
                                                    .find_by(title: 'Assay 1 parameter value 3')
                                                    .sample_controlled_vocab
                                                    .sample_controlled_vocab_terms
                                                    .second
                                                    .label,
                        'Extract Name': 'Extract 1 stream 2',
                        'other material characteristic 1': 'other material characteristic 1',
                        'other material characteristic 2': assay_1_stream_2_sample_type
                                                          .sample_attributes
                                                          .find_by(title: 'other material characteristic 2')
                                                          .sample_controlled_vocab
                                                          .sample_controlled_vocab_terms
                                                          .second
                                                          .label,
                        'other material characteristic 3': assay_1_stream_2_sample_type
                                                          .sample_attributes
                                                          .find_by(title: 'other material characteristic 3')
                                                          .sample_controlled_vocab
                                                          .sample_controlled_vocab_terms
                                                          .second
                                                          .label},
                      contributor: other_user.person)

      assay_2_stream_2_sample =
      FactoryBot.create(:sample,
              title: 'Assay 2 - stream 2 - sample 1',
              sample_type: assay_2_stream_2_sample_type,
              project_ids: [project.id],
              data: {
                Input: [assay_1_stream_2_sample.id],
                'Protocol Assay 2': 'Protocol Assay 2',
                'Assay 2 parameter value 1': 'Assay 2 parameter value 1',
                'Assay 2 parameter value 2': assay_2_stream_2_sample_type
                                            .sample_attributes
                                            .find_by(title: 'Assay 2 parameter value 2')
                                            .sample_controlled_vocab
                                            .sample_controlled_vocab_terms
                                            .first
                                            .label,
                'Assay 2 parameter value 3': assay_2_stream_2_sample_type
                                            .sample_attributes
                                            .find_by(title: 'Assay 2 parameter value 3')
                                            .sample_controlled_vocab
                                            .sample_controlled_vocab_terms
                                            .first
                                            .label,
                'File Name': 'file 1 stream 2',
                'Data file comment 1': 'Data file comment 1',
                'Data file comment 2': assay_2_stream_2_sample_type
                                      .sample_attributes
                                      .find_by(title: 'Data file comment 2')
                                      .sample_controlled_vocab
                                      .sample_controlled_vocab_terms
                                      .first
                                      .label,
                'Data file comment 3': assay_2_stream_2_sample_type
                                      .sample_attributes
                                      .find_by(title: 'Data file comment 3')
                                      .sample_controlled_vocab
                                      .sample_controlled_vocab_terms
                                      .first
                                      .label},
              contributor: current_user.person)

      assay_2_stream_2_hidden_sample =
      FactoryBot.create(:sample,
              title: 'Assay 2 - stream 2 - sample 2',
              sample_type: assay_2_stream_2_sample_type,
              project_ids: [project.id],
              data: {
                Input: [assay_1_stream_2_sample.id],
                'Protocol Assay 2': 'Protocol Assay 2',
                'Assay 2 parameter value 1': 'Assay 2 parameter value 1',
                'Assay 2 parameter value 2': assay_2_stream_2_sample_type
                                            .sample_attributes
                                            .find_by(title: 'Assay 2 parameter value 2')
                                            .sample_controlled_vocab
                                            .sample_controlled_vocab_terms
                                            .second
                                            .label,
                'Assay 2 parameter value 3': assay_2_stream_2_sample_type
                                            .sample_attributes
                                            .find_by(title: 'Assay 2 parameter value 3')
                                            .sample_controlled_vocab
                                            .sample_controlled_vocab_terms
                                            .second
                                            .label,
                'File Name': 'file 1 stream 2',
                'Data file comment 1': 'Data file comment 1',
                'Data file comment 2': assay_2_stream_2_sample_type
                                      .sample_attributes
                                      .find_by(title: 'Data file comment 2')
                                      .sample_controlled_vocab
                                      .sample_controlled_vocab_terms
                                      .second
                                      .label,
                'Data file comment 3': assay_2_stream_2_sample_type
                                      .sample_attributes
                                      .find_by(title: 'Data file comment 3')
                                      .sample_controlled_vocab
                                      .sample_controlled_vocab_terms
                                      .second
                                      .label},
              contributor: other_user.person)


      get :export_isa, params: { id: project.id, investigation_id: investigation.id }

      assert_response :success
      json_investigation = JSON.parse(response.body)
      assert json_investigation['studies'].map { |s| s['title'] }.include? accessible_study.title
      study_json = json_investigation['studies'].first

      # Only one assay should end up in 1 assay stream in the ISA JSON
      assert_equal accessible_study.assays.count, 4
      assert_equal study_json['assays'].count, 1

      sample_ids = study_json['materials']['samples'].map { |sample| sample['@id'] }

      # Check whether permitted samples end up in the materials
      assert sample_ids.include?("#sample/#{study_sample.id}")
      refute sample_ids.include?("#sample/#{hidden_study_sample.id}")

      # Check whether permitted study samples end up in the study's processSequence
      study_output_ids = []
      study_json['processSequence'].map do |process|
        process['outputs'].map { |output| study_output_ids.push(output['@id']) }
      end

      assert study_output_ids.include? "#sample/#{study_sample.id}"
      refute study_output_ids.include? "#sample/#{hidden_study_sample.id}"

      assay_json = study_json['assays'].first

      # Check otherMaterials
      other_material_ids = assay_json['materials']['otherMaterials'].map { |om| om['@id'] }
      assert other_material_ids.include? "#other_material/#{assay_1_stream_2_sample.id}"
      refute other_material_ids.include? "#other_material/#{assay_1_stream_2_hidden_sample.id}"

      # Check dataFiles
      data_file_ids = assay_json['dataFiles'].map { |df| df['@id'] }
      assert data_file_ids.include? "#data_file/#{assay_2_stream_2_sample.id}"
      refute data_file_ids.include? "#data_file/#{assay_2_stream_2_hidden_sample.id}"

      # Check whether permitted study samples end up in the assay's processSequence
      assay_output_ids = []
      assay_json['processSequence'].map do |process|
        process['outputs'].map { |output| assay_output_ids.push(output['@id']) }
      end

      assert assay_output_ids.include? "#other_material/#{assay_1_stream_2_sample.id}"
      assert assay_output_ids.include? "#data_file/#{assay_2_stream_2_sample.id}"
      refute assay_output_ids.include? "#other_material/#{assay_1_stream_2_hidden_sample.id}"
      refute assay_output_ids.include? "#data_file/#{assay_2_stream_2_hidden_sample.id}"
    end
  end

  test 'generates a valid export of sources in single page' do
    with_config_value(:project_single_page_enabled, true) do
      # Generate the excel data
      id_label, person, project, study, source_sample_type, sources = setup_file_upload.values_at(
        :id_label, :person, :project, :study, :source_sample_type, :sources
      )

      source_ids = sources.map { |s| { id_label => s.id } }
      sample_type_id = source_sample_type.id
      study_id = study.id
      assay_id = nil

      post_params = { sample_data: source_ids.to_json,
                      sample_type_id: sample_type_id.to_json,
                      study_id: study_id.to_json,
                      assay_id: assay_id.to_json }

      post :export_to_excel, params: post_params, xhr: true

      assert_response :ok, msg = "Couldn't reach the server"

      response_body = JSON.parse(response.body)
      assert response_body.key?('uuid'), msg = "Response body is expected to have a 'uuid' key"
      cache_uuid = response_body['uuid']

      get :download_samples_excel, params: { uuid: cache_uuid }
      assert_response :ok, msg = 'Unable to generate the excel'
    end
  end

  test 'generates a valid export of source samples in single page' do
    with_config_value(:project_single_page_enabled, true) do
      id_label, study, assay, sample_collection_sample_type, source_samples = setup_file_upload.values_at(
        :id_label, :study, :assay, :sample_collection_sample_type, :source_samples
      )

      source_sample_ids = source_samples.map { |ss| { id_label => ss.id } }
      sample_type_id = sample_collection_sample_type.id
      study_id = study.id
      assay_id = assay.id

      post_params = { sample_data: source_sample_ids.to_json,
                      sample_type_id: sample_type_id.to_json,
                      study_id: study_id.to_json,
                      assay_id: assay_id.to_json }

      post :export_to_excel, params: post_params, xhr: true

      assert_response :ok, msg = "Couldn't reach the server"

      response_body = JSON.parse(response.body)
      assert response_body.key?('uuid'), msg = "Response body is expected to have a 'uuid' key"
      cache_uuid = response_body['uuid']

      get :download_samples_excel, params: { uuid: cache_uuid }
      assert_response :ok, msg = 'Unable to generate the excel'
    end
  end

  test 'invalid file extension should raise exception' do
    with_config_value(:project_single_page_enabled, true) do
      file_path = 'upload_single_page/00_wrong_format_spreadsheet.ods'
      file = fixture_file_upload(file_path, 'application/vnd.oasis.opendocument.spreadsheet')

      project, source_sample_type = setup_file_upload.values_at(
        :project, :source_sample_type
      )

      post :upload_samples, params: { file:, project_id: project.id,
                                      sample_type_id: source_sample_type.id }

      assert_response :bad_request
      assert_equal flash[:error], "Please upload a valid spreadsheet file with extension '.xlsx'"
    end
  end

  test 'Should prevent to upload to the wrong Sample Type' do
    with_config_value(:project_single_page_enabled, true) do
      project, sample_collection_sample_type = setup_file_upload.values_at(
        :project, :sample_collection_sample_type
      )

      file_path = 'upload_single_page/01_combo_update_sources_spreadsheet.xlsx'
      file = fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

      post :upload_samples, as: :json, params: { file:, project_id: project.id,
                                                 sample_type_id: sample_collection_sample_type.id }

      assert_response :bad_request
    end
  end

  test 'Should not process invalid workbooks' do
    with_config_value(:project_single_page_enabled, true) do
      project, source_sample_type = setup_file_upload.values_at(
        :project, :source_sample_type
      )

      file_path = 'upload_single_page/02_invalid_workbook.xlsx'
      file = fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

      post :upload_samples, as: :json, params: { file:, project_id: project.id,
                                                 sample_type_id: source_sample_type.id }

      assert_response :bad_request
    end
  end

  test 'Should update, create and detect duplicate sources when uploading to a source Sample Type' do
    with_config_value(:project_single_page_enabled, true) do
      project, source_sample_type = setup_file_upload.values_at(
        :project, :source_sample_type
      )

      file_path = 'upload_single_page/01_combo_update_sources_spreadsheet.xlsx'
      file = fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

      post :upload_samples, as: :json, params: { file:, project_id: project.id,
                                                 sample_type_id: source_sample_type.id }

      response_data = JSON.parse(response.body)['uploadData']
      assert_response :success

      updated_samples = response_data['updateSamples']
      assert(updated_samples.size, 2)

      new_samples = response_data['newSamples']
      assert(new_samples.size, 2)

      possible_duplicates = response_data['possibleDuplicates']
      assert(possible_duplicates.size, 1)
    end
  end

  test 'Should update, create and detect duplicate samples when uploading to a source sample Sample Type' do
    with_config_value(:project_single_page_enabled, true) do
      project, sample_collection_sample_type = setup_file_upload.values_at(
        :project, :sample_collection_sample_type
      )

      file_path = 'upload_single_page/03_combo_update_samples_spreadsheet.xlsx'
      file = fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

      post :upload_samples, as: :json, params: { file:, project_id: project.id,
                                                 sample_type_id: sample_collection_sample_type.id }

      response_data = JSON.parse(response.body)['uploadData']
      assert_response :success

      updated_samples = response_data['updateSamples']
      assert(updated_samples.size, 2)

      new_samples = response_data['newSamples']
      assert(new_samples.size, 2)

      possible_duplicates = response_data['possibleDuplicates']
      assert(possible_duplicates.size, 1)
    end
  end

  test 'Should update, create and detect duplicate samples when uploading to a assay Sample Type' do
    with_config_value(:project_single_page_enabled, true) do
      project, assay_sample_type = setup_file_upload.values_at(
        :project, :assay_sample_type
      )

      file_path = 'upload_single_page/04_combo_update_assay_samples_spreadsheet.xlsx'
      file = fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

      post :upload_samples, as: :json, params: { file:, project_id: project.id,
                                                 sample_type_id: assay_sample_type.id }

      response_data = JSON.parse(response.body)['uploadData']
      assert_response :success

      updated_samples = response_data['updateSamples']
      assert(updated_samples.size, 2)

      new_samples = response_data['newSamples']
      assert(new_samples.size, 1)

      possible_duplicates = response_data['possibleDuplicates']
      assert(possible_duplicates.size, 1)
    end
  end

  def setup_file_upload
    id_label = "#{Seek::Config.instance_name} id"
    person = @member.person
    project = FactoryBot.create(:project, id: 10_000)
    study = FactoryBot.create(:study, id: 10_001)
    assay = FactoryBot.create(:assay, id: 10_002, study:)

    source_sample_type_template = FactoryBot.create(:isa_source_template, id: 10_006)
    source_sample_type = FactoryBot.create(:isa_source_sample_type,
                                           id: 10_003,
                                           contributor: person,
                                           project_ids: [project.id],
                                           isa_template: source_sample_type_template,
                                           studies: [study])

    sample_collection_sample_type_template = FactoryBot.create(:isa_sample_collection_template, id: 10_007)
    sample_collection_sample_type = FactoryBot.create(:isa_sample_collection_sample_type,
                                                      id: 10_004,
                                                      contributor: person,
                                                      project_ids: [project.id],
                                                      isa_template: sample_collection_sample_type_template,
                                                      studies: [study],
                                                      linked_sample_type: source_sample_type)

    assay_sample_type_template = FactoryBot.create(:isa_assay_material_template, id: 10_008)
    assay_sample_type = FactoryBot.create(:isa_assay_material_sample_type,
                                          id: 10_005,
                                          contributor: person,
                                          isa_template: assay_sample_type_template,
                                          projects: [project],
                                          studies: [study],
                                          linked_sample_type: sample_collection_sample_type)

    sources = (1..5).map do |n|
      FactoryBot.create(
        :sample,
        id: 10_010 + n,
        title: "source#{n}",
        sample_type: source_sample_type,
        project_ids: [project.id],
        contributor: person,
        data: {
          'Source Name': 'Source Name',
          'Source Characteristic 1': 'Source Characteristic 1',
          'Source Characteristic 2':
            source_sample_type
              .sample_attributes
              .find_by_title('Source Characteristic 2')
              .sample_controlled_vocab
              .sample_controlled_vocab_terms
              .first
              .label
        }
      )
    end

    source_samples = (1..4).map do |n|
      FactoryBot.create(
        :sample,
        id: 10_020 + n,
        title: "Sample collection #{n}",
        sample_type: sample_collection_sample_type,
        project_ids: [project.id],
        contributor: person,
        data: {
          Input: [sources[n - 1].id, sources[n].id],
          'sample collection': 'sample collection',
          'sample collection parameter value 1': 'sample collection parameter value 1',
          'Sample Name': "sample nr. #{n}",
          'sample characteristic 1': 'sample characteristic 1'
        }
      )
    end

    assay_samples = (1..3).map do |n|
      FactoryBot.create(
        :sample,
        id: 10_030 + n,
        title: "Assay Sample #{n}",
        sample_type: assay_sample_type,
        project_ids: [project.id],
        contributor: person,
        data: {
          Input: [source_samples[n - 1].id, source_samples[n].id],
          'Protocol Assay 1': 'How to make concentrated dark matter',
          'Assay 1 parameter value 1': 'Assay 1 parameter value 1',
          'Extract Name': "Extract nr. #{n}",
          'other material characteristic 1': 'other material characteristic 1'
        }
      )
    end

    { "id_label": id_label, "person": person, "project": project, "study": study, "assay": assay,
      "source_sample_type": source_sample_type, "sample_collection_sample_type": sample_collection_sample_type,
      "assay_sample_type": assay_sample_type, "sources": sources, "source_samples": source_samples,
      "assay_samples": assay_samples }
  end
end
