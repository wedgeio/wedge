class Playground
  class Abilities < Wedge::Plugins::AbilityList
    name :ability_list

    def initialize user
      if user.admin?
        can :view, :admin
      end
    end
  end
end
