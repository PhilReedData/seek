require 'test_helper'
require 'minitest/mock'

class WorkflowsControllerTest < ActionController::TestCase
  include AuthenticatedTestHelper
  include SharingFormTestHelper
  include GeneralAuthorizationTestCases

  def setup
    login_as Factory(:user)
    @project = User.current_user.person.projects.first
  end

  test 'should return 406 when requesting RDF' do
    wf = Factory :workflow, contributor: User.current_user.person
    assert wf.can_view?

    get :show, params: { id: wf, format: :rdf }

    assert_response :not_acceptable
  end

  test 'index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:workflows)
  end

  test 'can create with valid url' do
    mock_remote_file "#{Rails.root}/test/fixtures/files/file_picture.png", 'http://somewhere.com/piccy.png'
    workflow_attrs = Factory.attributes_for(:workflow, project_ids: [@project.id])

    assert_difference 'Workflow.count' do
      post :create, params: { workflow: workflow_attrs, content_blobs: [{ data_url: 'http://somewhere.com/piccy.png', data: nil }], sharing: valid_sharing }
    end
  end

  test 'can create with local file' do
    workflow_attrs = Factory.attributes_for(:workflow,
                                            contributor: User.current_user,
                                            project_ids: [@project.id])

    assert_difference 'Workflow.count' do
      assert_difference 'ActivityLog.count' do
        post :create, params: { workflow: workflow_attrs, content_blobs: [{ data: file_for_upload }], sharing: valid_sharing }
      end
    end
  end

  test 'can edit' do
    workflow = Factory :workflow, contributor: User.current_user.person

    get :edit, params: { id: workflow }
    assert_response :success
  end

  test 'can update' do
    workflow = Factory :workflow, contributor: User.current_user.person
    post :update, params: { id: workflow, workflow: { title: 'updated' } }
    assert_redirected_to workflow_path(workflow)
  end

  test 'can upload new version with valid url' do
    mock_remote_file "#{Rails.root}/test/fixtures/files/file_picture.png", 'http://somewhere.com/piccy.png'
    workflow = Factory :workflow, contributor: User.current_user.person

    assert_difference 'workflow.version' do
      post :new_version, params: { id: workflow, workflow: {}, content_blobs: [{ data_url: 'http://somewhere.com/piccy.png' }] }

      workflow.reload
    end
    assert_redirected_to workflow_path(workflow)
  end

  test 'can upload new version with valid filepath' do
    # by default, valid data_url is provided by content_blob in Factory
    workflow = Factory :workflow, contributor: User.current_user.person
    workflow.content_blob.url = nil
    workflow.content_blob.data = file_for_upload
    workflow.reload

    new_file_path = file_for_upload
    assert_difference 'workflow.version' do
      post :new_version, params: { id: workflow, workflow: {}, content_blobs: [{ data: new_file_path }] }

      workflow.reload
    end
    assert_redirected_to workflow_path(workflow)
  end

  test 'cannot upload file with invalid url' do
    stub_request(:head, 'http://www.blah.de/images/logo.png').to_raise(SocketError)
    workflow_attrs = Factory.build(:workflow, contributor: User.current_user.person).attributes # .symbolize_keys(turn string key to symbol)

    assert_no_difference 'Workflow.count' do
      post :create, params: { workflow: workflow_attrs, content_blobs: [{ data_url: 'http://www.blah.de/images/logo.png' }] }
    end
    assert_not_nil flash[:error]
  end

  test 'cannot upload new version with invalid url' do
    stub_request(:any, 'http://www.blah.de/images/liver-illustration.png').to_raise(SocketError)
    workflow = Factory :workflow, contributor: User.current_user.person
    new_data_url = 'http://www.blah.de/images/liver-illustration.png'
    assert_no_difference 'workflow.version' do
      post :new_version, params: { id: workflow, workflow: {}, content_blobs: [{ data_url: new_data_url }] }

      workflow.reload
    end
    assert_not_nil flash[:error]
  end

  test 'can destroy' do
    workflow = Factory :workflow, contributor: User.current_user.person
    content_blob_id = workflow.content_blob.id
    assert_difference('Workflow.count', -1) do
      delete :destroy, params: { id: workflow }
    end
    assert_redirected_to workflows_path

    # data/url is still stored in content_blob
    assert_not_nil ContentBlob.find_by_id(content_blob_id)
  end

  test 'can subscribe' do
    workflow = Factory :workflow, contributor: User.current_user.person
    assert_difference 'workflow.subscriptions.count' do
      workflow.subscribed = true
      workflow.save
    end
  end

  test 'update tags with ajax' do
    p = Factory :person

    login_as p.user

    p2 = Factory :person
    workflow = Factory :workflow, contributor: p

    assert workflow.annotations.empty?, 'this workflow should have no tags for the test'

    golf = Factory :tag, annotatable: workflow, source: p2.user, value: 'golf'
    Factory :tag, annotatable: workflow, source: p2.user, value: 'sparrow'

    workflow.reload

    assert_equal %w(golf sparrow), workflow.annotations.collect { |a| a.value.text }.sort
    assert_equal [], workflow.annotations.select { |a| a.source == p.user }.collect { |a| a.value.text }.sort
    assert_equal %w(golf sparrow), workflow.annotations.select { |a| a.source == p2.user }.collect { |a| a.value.text }.sort

    post :update_annotations_ajax, xhr: true, params: { id: workflow, tag_list: "soup,#{golf.value.text}" }

    workflow.reload

    assert_equal %w(golf soup sparrow), workflow.annotations.collect { |a| a.value.text }.uniq.sort
    assert_equal %w(golf soup), workflow.annotations.select { |a| a.source == p.user }.collect { |a| a.value.text }.sort
    assert_equal %w(golf sparrow), workflow.annotations.select { |a| a.source == p2.user }.collect { |a| a.value.text }.sort
  end

  test 'should set the other creators ' do
    user = Factory(:user)
    workflow = Factory(:workflow, contributor: user.person)
    login_as(user)
    assert workflow.can_manage?, 'The workflow must be manageable for this test to succeed'
    put :update, params: { id: workflow, workflow: { other_creators: 'marry queen' } }
    workflow.reload
    assert_equal 'marry queen', workflow.other_creators
  end

  test 'should show the other creators on the workflow index' do
    Factory(:workflow, policy: Factory(:public_policy), other_creators: 'another creator')
    get :index
    assert_select 'p.list_item_attribute', text: /: another creator/, count: 1
  end

  test 'should show the other creators in -uploader and creators- box' do
    workflow = Factory(:workflow, policy: Factory(:public_policy), other_creators: 'another creator')
    get :show, params: { id: workflow }
    assert_select 'div', text: 'another creator', count: 1
  end

  test 'filter by people, including creators, using nested routes' do
    assert_routing 'people/7/workflows', controller: 'workflows', action: 'index', person_id: '7'

    person1 = Factory(:person)
    person2 = Factory(:person)

    pres1 = Factory(:workflow, contributor: person1, policy: Factory(:public_policy))
    pres2 = Factory(:workflow, contributor: person2, policy: Factory(:public_policy))

    pres3 = Factory(:workflow, contributor: Factory(:person), creators: [person1], policy: Factory(:public_policy))
    pres4 = Factory(:workflow, contributor: Factory(:person), creators: [person2], policy: Factory(:public_policy))

    get :index, params: { person_id: person1.id }
    assert_response :success

    assert_select 'div.list_item_title' do
      assert_select 'a[href=?]', workflow_path(pres1), text: pres1.title
      assert_select 'a[href=?]', workflow_path(pres3), text: pres3.title

      assert_select 'a[href=?]', workflow_path(pres2), text: pres2.title, count: 0
      assert_select 'a[href=?]', workflow_path(pres4), text: pres4.title, count: 0
    end
  end

  test 'should display null license text' do
    workflow = Factory :workflow, policy: Factory(:public_policy)

    get :show, params: { id: workflow }

    assert_select '.panel .panel-body span#null_license', text: I18n.t('null_license')
  end

  test 'should display license' do
    workflow = Factory :workflow, license: 'CC-BY-4.0', policy: Factory(:public_policy)

    get :show, params: { id: workflow }

    assert_select '.panel .panel-body a', text: 'Creative Commons Attribution 4.0'
  end

  test 'should display license for current version' do
    workflow = Factory :workflow, license: 'CC-BY-4.0', policy: Factory(:public_policy)
    workflowv = Factory :workflow_version_with_blob, workflow: workflow

    workflow.update_attributes license: 'CC0-1.0'

    get :show, params: { id: workflow, version: 1 }
    assert_response :success
    assert_select '.panel .panel-body a', text: 'Creative Commons Attribution 4.0'

    get :show, params: { id: workflow, version: workflowv.version }
    assert_response :success
    assert_select '.panel .panel-body a', text: 'CC0 1.0'
  end

  test 'should update license' do
    user = Factory(:person).user
    login_as(user)
    workflow = Factory :workflow, policy: Factory(:public_policy), contributor: user.person

    assert_nil workflow.license

    put :update, params: { id: workflow, workflow: { license: 'CC-BY-SA-4.0' } }

    assert_response :redirect

    get :show, params: { id: workflow }
    assert_select '.panel .panel-body a', text: 'Creative Commons Attribution Share-Alike 4.0'
    assert_equal 'CC-BY-SA-4.0', assigns(:workflow).license
  end

  test 'programme workflows through nested routing' do
    assert_routing 'programmes/2/workflows', controller: 'workflows', action: 'index', programme_id: '2'
    programme = Factory(:programme, projects: [@project])
    assert_equal [@project], programme.projects
    workflow = Factory(:workflow, policy: Factory(:public_policy), contributor:User.current_user.person)
    workflow2 = Factory(:workflow, policy: Factory(:public_policy))

    get :index, params: { programme_id: programme.id }

    assert_response :success
    assert_select 'div.list_item_title' do
      assert_select 'a[href=?]', workflow_path(workflow), text: workflow.title
      assert_select 'a[href=?]', workflow_path(workflow2), text: workflow2.title, count: 0
    end
  end

  test 'manage menu item appears according to permission' do
    check_manage_edit_menu_for_type('workflow')
  end

  test 'can access manage page with manage rights' do
    person = Factory(:person)
    workflow = Factory(:workflow, contributor:person)
    login_as(person)
    assert workflow.can_manage?
    get :manage, params: {id: workflow}
    assert_response :success

    # check the project form exists, studies and assays don't have this
    assert_select 'div#add_projects_form', count:1

    # check sharing form exists
    assert_select 'div#sharing_form', count:1

    # should be a temporary sharing link
    assert_select 'div#temporary_links', count:1

    assert_select 'div#author_form', count:1
  end

  test 'cannot access manage page with edit rights' do
    person = Factory(:person)
    workflow = Factory(:workflow, policy:Factory(:private_policy, permissions:[Factory(:permission, contributor:person, access_type:Policy::EDITING)]))
    login_as(person)
    assert workflow.can_edit?
    refute workflow.can_manage?
    get :manage, params: {id:workflow}
    assert_redirected_to workflow
    refute_nil flash[:error]
  end

  test 'manage_update' do
    proj1=Factory(:project)
    proj2=Factory(:project)
    person = Factory(:person,project:proj1)
    other_person = Factory(:person)
    person.add_to_project_and_institution(proj2,person.institutions.first)
    person.save!
    other_creator = Factory(:person,project:proj1)
    other_creator.add_to_project_and_institution(proj2,other_creator.institutions.first)
    other_creator.save!

    workflow = Factory(:workflow, contributor:person, projects:[proj1], policy:Factory(:private_policy))

    login_as(person)
    assert workflow.can_manage?

    patch :manage_update, params: {id: workflow,
                                   workflow: {
                                       creator_ids: [other_creator.id],
                                       project_ids: [proj1.id, proj2.id]
                                   },
                                   policy_attributes: {access_type: Policy::VISIBLE, permissions_attributes: {'1' => {contributor_type: 'Person', contributor_id: other_person.id, access_type: Policy::MANAGING}}
                                   }}

    assert_redirected_to workflow

    workflow.reload
    assert_equal [proj1,proj2],workflow.projects.sort_by(&:id)
    assert_equal [other_creator],workflow.creators
    assert_equal Policy::VISIBLE,workflow.policy.access_type
    assert_equal 1,workflow.policy.permissions.count
    assert_equal other_person,workflow.policy.permissions.first.contributor
    assert_equal Policy::MANAGING,workflow.policy.permissions.first.access_type

  end

  test 'manage_update fails without manage rights' do
    proj1=Factory(:project)
    proj2=Factory(:project)
    person = Factory(:person, project:proj1)
    person.add_to_project_and_institution(proj2,person.institutions.first)
    person.save!

    other_person = Factory(:person)

    other_creator = Factory(:person,project:proj1)
    other_creator.add_to_project_and_institution(proj2,other_creator.institutions.first)
    other_creator.save!

    workflow = Factory(:workflow, projects:[proj1], policy:Factory(:private_policy,
                                                                   permissions:[Factory(:permission,contributor:person, access_type:Policy::EDITING)]))

    login_as(person)
    refute workflow.can_manage?
    assert workflow.can_edit?

    assert_equal [proj1],workflow.projects
    assert_empty workflow.creators

    patch :manage_update, params: {id: workflow,
                                   workflow: {
                                       creator_ids: [other_creator.id],
                                       project_ids: [proj1.id, proj2.id]
                                   },
                                   policy_attributes: {access_type: Policy::VISIBLE, permissions_attributes: {'1' => {contributor_type: 'Person', contributor_id: other_person.id, access_type: Policy::MANAGING}}
                                   }}

    refute_nil flash[:error]

    workflow.reload
    assert_equal [proj1],workflow.projects
    assert_empty workflow.creators
    assert_equal Policy::PRIVATE,workflow.policy.access_type
    assert_equal 1,workflow.policy.permissions.count
    assert_equal person,workflow.policy.permissions.first.contributor
    assert_equal Policy::EDITING,workflow.policy.permissions.first.access_type
  end

  test 'create content blob' do
    cwl = Factory(:cwl_workflow_class)
    person = Factory(:person)
    login_as(person)
    assert_difference('ContentBlob.count') do
      post :create_content_blob, params: {
          content_blobs: [{ data: fixture_file_upload('files/workflows/rp2-to-rp2path-packed.cwl', 'application/x-yaml') }],
          workflow_class_id: cwl.id }
    end
    assert_response :success
    assert wf = assigns(:workflow)
    refute_nil wf.content_blob
    assert_equal wf.content_blob.id, session[:uploaded_content_blob_id]
    assert_equal cwl, wf.workflow_class
  end

  test 'create content blob requires login' do
    cwl = Factory(:cwl_workflow_class)

    logout
    assert_no_difference('ContentBlob.count') do
      post :create_content_blob, params: {
          content_blobs: [{ data: fixture_file_upload('files/workflows/rp2-to-rp2path-packed.cwl', 'application/x-yaml') }],
          workflow_class_id: cwl.id }
    end
    assert_response :redirect
  end

  test 'create ro crate with local content' do
    cwl = Factory(:cwl_workflow_class)
    person = Factory(:person)
    login_as(person)
    assert_difference('ContentBlob.count') do
      post :create_ro_crate, params: {
          ro_crate: {
              workflow: { data: fixture_file_upload('files/checksums.txt') },
              diagram: { data: fixture_file_upload('files/file_picture.png') },
              abstract_cwl: { data: fixture_file_upload('files/workflows/rp2-to-rp2path-packed.cwl') }
          },
          workflow_class_id: cwl.id
      }
    end
    assert_response :success
    assert wf = assigns(:workflow)
    refute_nil wf.content_blob
    assert_equal wf.content_blob.id, session[:uploaded_content_blob_id]
    assert_equal cwl, wf.workflow_class
    assert_equal 'new-workflow.basic.crate.zip', wf.content_blob.original_filename
  end

  test 'extract metadata' do
    cwl = Factory(:cwl_workflow_class)
    blob = Factory(:cwl_packed_content_blob)
    session[:uploaded_content_blob_id] = blob.id.to_s
    post :metadata_extraction_ajax, params: { content_blob_id: blob.id.to_s, format: 'js', workflow_class_id: cwl.id }
    assert_response :success
    assert_equal 12, session[:metadata][:internals][:inputs].length
  end

  test 'missing diagram and no CWL viewer available returns 404' do
    wf = Factory(:cwl_workflow)
    login_as(wf.contributor)
    refute wf.diagram_exists?
    refute wf.can_render_diagram?

    get :diagram, params: { id: wf.id }

    assert_response :not_found
  end

  test 'cannot see diagram of private workflow' do
    wf = Factory(:cwl_workflow)
    refute wf.can_view?

    get :diagram, params: { id: wf.id }

    assert_response :redirect
    assert flash[:error].include?('You are not authorized')
  end

  test 'generates diagram if CWL viewer available' do
    with_config_value(:cwl_viewer_url, 'http://localhost:8080/cwl_viewer') do
      wf = Factory(:cwl_workflow)
      login_as(wf.contributor)
      refute wf.diagram_exists?
      assert wf.can_render_diagram?

      VCR.use_cassette('workflows/cwl_viewer_cwl_workflow_diagram') do
        get :diagram, params: { id: wf.id }
      end

      assert_response :success
      assert_equal 'image/svg+xml', response.headers['Content-Type']
      assert wf.diagram_exists?
    end
  end

  test 'picks diagram from RO crate' do
    wf = Factory(:existing_galaxy_ro_crate_workflow)
    login_as(wf.contributor)
    refute wf.diagram_exists?
    assert wf.can_render_diagram?

    get :diagram, params: { id: wf.id }

    assert_response :success
    assert_equal 'image/png', response.headers['Content-Type']
    assert wf.diagram_exists?
  end

  test 'generates diagram from CWL workflow in RO crate' do
    with_config_value(:cwl_viewer_url, 'http://localhost:8080/cwl_viewer') do
      wf = Factory(:just_cwl_ro_crate_workflow)
      login_as(wf.contributor)
      refute wf.diagram_exists?
      assert_nil wf.ro_crate.main_workflow_diagram
      assert wf.can_render_diagram?

      VCR.use_cassette('workflows/cwl_viewer_cwl_workflow_from_crate_diagram') do
        get :diagram, params: { id: wf.id }
      end

      assert_response :success
      assert_equal 'image/svg+xml', response.headers['Content-Type']
      assert wf.diagram_exists?
    end
  end

  test 'generates diagram from abstract CWL in RO crate' do
    with_config_value(:cwl_viewer_url, 'http://localhost:8080/cwl_viewer') do
      wf = Factory(:generated_galaxy_no_diagram_ro_crate_workflow)
      login_as(wf.contributor)
      refute wf.diagram_exists?
      assert wf.can_render_diagram?

      VCR.use_cassette('workflows/cwl_viewer_galaxy_workflow_abstract_cwl_diagram') do
        get :diagram, params: { id: wf.id }
      end

      assert_response :success
      assert_equal 'image/svg+xml', response.headers['Content-Type']
      assert wf.diagram_exists?
    end
  end

  test 'does not render diagram if not in RO crate' do
    wf = Factory(:nf_core_ro_crate_workflow)
    login_as(wf.contributor)
    refute wf.diagram_exists?
    refute wf.can_render_diagram?

    get :diagram, params: { id: wf.id }

    assert_response :not_found
    refute wf.diagram_exists?
  end

  test 'should be able to handle spaces in filenames' do
    cwl = Factory(:cwl_workflow_class)
    person = Factory(:person)
    login_as(person)
    assert_difference('ContentBlob.count') do
      post :create_ro_crate, params: {
          ro_crate: {
              workflow: { data: fixture_file_upload('files/file with spaces in name.txt') },
              diagram: { data: fixture_file_upload('files/file_picture.png') },
              abstract_cwl: { data: fixture_file_upload('files/workflows/rp2-to-rp2path-packed.cwl') }
          },
          workflow_class_id: cwl.id
      }
    end
    assert_response :success
    assert wf = assigns(:workflow)
    crate_workflow = wf.ro_crate.main_workflow
    assert crate_workflow
    assert_equal 'file%20with%20spaces%20in%20name.txt', crate_workflow.id
  end

  test 'downloads valid RO crate' do
    workflow = Factory(:generated_galaxy_ro_crate_workflow, policy: Factory(:public_policy))

    get :ro_crate, params: { id: workflow.id }

    assert_response :success
    crate = ROCrate::WorkflowCrateReader.read_zip(response.stream.to_path)
    assert crate.main_workflow
  end

  def edit_max_object(workflow)
    add_tags_to_test_object(workflow)
    add_creator_to_test_object(workflow)
  end
end
