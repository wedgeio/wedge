class Playground
  class CurrentUserComponent < Wedge::Plugins::CurrentUser
    name :current_user

    attr_reader :id, :is_admin, :secret_key
    attr_accessor :first_name, :last_name

    def admin?
      is_admin
    end
  end
end
