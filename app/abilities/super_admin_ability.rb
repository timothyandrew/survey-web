class SuperAdminAbility < Ability
  def initialize(user_info)
    @user_info = user_info

    can :manage, :all
    cannot :create, Survey
    cannot :create, Response
  end
end