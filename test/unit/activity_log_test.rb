require 'test_helper'
class ActivityLogTest < ActiveSupport::TestCase

  test "duplicates" do
    df = Factory :data_file
    sop = Factory :sop

    df_log_1 = Factory :activity_log,:activity_loggable=>df,:action=>"create",:controller_name=>"data_files",:created_at=>2.hour.ago
    df_log_2 = Factory :activity_log,:activity_loggable=>df,:action=>"create",:controller_name=>"data_files",:created_at=>1.hour.ago
    df_log_3 = Factory :activity_log,:activity_loggable=>df,:action=>"create",:controller_name=>"data_files",:created_at=>1.minute.ago
    df_log_4 = Factory :activity_log,:activity_loggable=>df,:controller_name=>"data_files",:action=>"download"
    df_log_5 = Factory :activity_log,:activity_loggable=>df,:controller_name=>"data_files",:action=>"download"

    sop_log_1 = Factory :activity_log,:activity_loggable=>sop,:controller_name=>"sops",:action=>"create",:created_at=>2.hour.ago
    sop_log_2 = Factory :activity_log,:activity_loggable=>sop,:controller_name=>"sops",:action=>"create",:created_at=>1.hour.ago
    sop_log_3 = Factory :activity_log,:activity_loggable=>sop,:controller_name=>"sops",:action=>"create",:created_at=>2.minute.ago
    sop_log_4 = Factory :activity_log,:activity_loggable=>sop,:controller_name=>"sops",:action=>"show"
    sop_log_5 = Factory :activity_log,:activity_loggable=>sop,:controller_name=>"sops",:action=>"show"

    assert_equal 2,ActivityLog.duplicates("create").length
    assert_equal 1,ActivityLog.duplicates("download").length
    assert_equal 1,ActivityLog.duplicates("show").length
  end

  test "remove duplicates" do
    df = Factory :data_file
    sop = Factory :sop
    
    df_log_1 = Factory :activity_log,:activity_loggable=>df,:action=>"create",:created_at=>2.hour.ago
    df_log_2 = Factory :activity_log,:activity_loggable=>df,:action=>"create",:created_at=>1.hour.ago
    df_log_3 = Factory :activity_log,:activity_loggable=>df,:action=>"create",:created_at=>1.minute.ago
    df_log_4 = Factory :activity_log,:activity_loggable=>df,:action=>"download"
    df_log_5 = Factory :activity_log,:activity_loggable=>df,:action=>"download"

    sop_log_1 = Factory :activity_log,:activity_loggable=>sop,:action=>"create",:created_at=>2.hour.ago
    sop_log_2 = Factory :activity_log,:activity_loggable=>sop,:action=>"create",:created_at=>1.hour.ago
    sop_log_3 = Factory :activity_log,:activity_loggable=>sop,:action=>"create",:created_at=>2.minute.ago
    sop_log_4 = Factory :activity_log,:activity_loggable=>sop,:action=>"show"
    sop_log_5 = Factory :activity_log,:activity_loggable=>sop,:action=>"show"

    assert_difference("ActivityLog.count",-4) do
      ActivityLog.remove_duplicate_creates
    end

    all=ActivityLog.all
    assert all.include?(df_log_1)
    assert all.include?(df_log_4)
    assert all.include?(df_log_5)
    assert !all.include?(df_log_2)
    assert !all.include?(df_log_3)
    
    all=ActivityLog.all
    assert all.include?(sop_log_1)
    assert all.include?(sop_log_4)
    assert all.include?(sop_log_5)
    assert !all.include?(sop_log_2)
    assert !all.include?(sop_log_3)
    
  end

  test "should be able to create activity log for none-published item" do
    user = Factory(:user)
    df = Factory(:data_file, :contributor => user)
    assert !df.can_view?(nil)
    #activitylog can not be created if cannot_view
    ac = ActivityLog.create(:action => 'create', :activity_loggable => df, :culprit => user)
    assert ac.new_record?
    assert !ac.errors.full_messages.empty?

    #activitylog can be created if can_view
    User.with_current_user user do
      assert df.can_view?
      ac = ActivityLog.create(:action => 'create', :activity_loggable => df, :culprit => user)
      assert !ac.new_record?
      assert ac.errors.full_messages.empty?
    end
  end
end