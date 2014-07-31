require_dependency 'issue'

module RedmineLimitedVisibility
  module IssuePatch
    def self.included(base)
      base.class_eval do
        unloadable

        safe_attributes "authorized_viewers"

        unless instance_methods.include?(:notified_users_with_limited_visibility)
          def notified_users_with_limited_visibility
            if involved_roles_ids.present?
              notified_users_without_limited_visibility & involved_users
            else
              notified_users_without_limited_visibility
            end
          end
          alias_method_chain :notified_users, :limited_visibility
        end

        def involved_users
          users = []
          if Redmine::Plugin.installed?(:redmine_organizations)
            users = User.joins(:organization_involvements)
                        .joins('LEFT OUTER JOIN organization_memberships ON organization_memberships.id = organization_involvements.organization_membership_id')
                        .joins('LEFT OUTER JOIN organization_roles ON organization_roles.organization_membership_id = organization_memberships.id')
                        .where("#{OrganizationMembership.table_name}.project_id = ? AND #{OrganizationRole.table_name}.role_id IN (?)", project_id, involved_roles_ids)
                        .uniq
          else
            members = Member.joins(:member_roles).where("#{Member.table_name}.project_id = ? AND #{MemberRole.table_name}.role_id IN (?)", project_id, involved_roles_ids)
            users << members.map(&:user)
          end
          return users
        end

        def involved_roles_ids
          authorized_viewers.split('|').delete_if(&:blank?) if authorized_viewers
        end

      end
    end
  end
end

unless Issue.included_modules.include? RedmineLimitedVisibility::IssuePatch
  Issue.send :include, RedmineLimitedVisibility::IssuePatch
end
