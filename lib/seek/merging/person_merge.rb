module Seek
  module Merging
    module PersonMerge
      def merge(other_person)
        merge_simple_attributes(other_person)
        merge_annotations(other_person)

        # Merging group_memberships deals with work_groups, programmes, institutions and projects
        merge_associations(group_memberships, other_person.group_memberships, 'work_group_id')
        merge_associations(subscriptions, other_person.subscriptions, 'subscribable_id')
        merge_resources(other_person)
        merge_permissions(other_person)
        merge_roles(other_person)
        Person.transaction do
          save!
          other_person.destroy
        end
      end

      private

      # This attributes are directly copied from other_person if they are empty in the person to which its merging.
      # first_letter is also updated
      def simple_attributes
        %i[
          first_name
          last_name
          email
          phone
          skype_name
          web_page
          description
          avatar_id
          orcid
        ]
      end

      def merge_simple_attributes(other_person)
        simple_attributes.each do |attribute|
          send("#{attribute}=", other_person.send(attribute)) if send(attribute).nil?
        end
        update_first_letter
      end

      def annotation_types
        %w[
          expertise
          tools
        ]
      end

      def merge_annotations(other_person)
        annotation_types.each do |annotation_type|
          add_annotations(send(annotation_type)+other_person.send(annotation_type), annotation_type.singularize, self)
        end
      end

      def merge_associations(current_associations, other_associations, check_existing)
        other_associations.each do |other_association|
          existing_association = nil
          if check_existing
            existing_association = current_associations.find do |assoc|
              # Check if association already exists
              assoc.send(check_existing) == other_association.send(check_existing)
            end
          end

          next if existing_association

          duplicated_association = other_association.dup
          duplicated_association.person_id = id
          current_associations << duplicated_association
        end
      end

      def merge_resources(other_person)
        # Contributed
        Person::RELATED_RESOURCE_TYPES.each do |resource_type|
          resource_type.constantize.where(contributor_id: other_person.id).update_all(contributor_id: id)
        end
        # Created
        duplicated = other_person.created_items.pluck(:id) & created_items.pluck(:id)
        AssetsCreator.where(creator_id: other_person.id, asset_id: duplicated).destroy_all
        AssetsCreator.where(creator_id: other_person.id).update_all(creator_id: id)
        # Reload to prevent destruction of unlinked resources
        other_person.reload
      end

      def merge_permissions(other_person)
        permissions_other = Permission.where(contributor_type: "Person", contributor_id: other_person.id)
        permissions_slef = Permission.where(contributor_type: "Person", contributor_id: id)
        duplicated = permissions_other.pluck(:policy_id) & permissions_slef.pluck(:policy_id)
        permissions_other.where(policy_id: duplicated).destroy_all
        permissions_other.update_all(contributor_id: id)
      end

      def merge_roles(other_person)
        other_roles = other_person.roles.pluck('scope_type', 'scope_id', 'role_type_id')
        self_roles = roles.pluck('scope_type', 'scope_id', 'role_type_id')
        duplicated = other_roles & self_roles
        other_person.roles.where({
                                   scope_type: duplicated.map { |triple| triple[0] },
                                   scope_id: duplicated.map { |triple| triple[1] },
                                   role_type_id: duplicated.map { |triple| triple[2] }
                                 }).destroy_all
        other_person.roles.update_all(person_id: id)
        # Reload to prevent destruction of unlinked roles
        other_person.reload
      end

    end
  end
end
