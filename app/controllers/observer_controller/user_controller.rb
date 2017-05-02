# encoding: utf-8
# see observer_controller.rb
class ObserverController
  # User index, restricted to admins.
  def index_user # :nologin: :norobots:
    if in_admin_mode? || find_query(:User)
      query = find_or_create_query(:User, by: params[:by])
      show_selected_users(query, id: params[:id].to_s, always_index: true)
    else
      flash_error(:runtime_search_has_expired.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  # People guess this page name frequently for whatever reason, and
  # since there is a view with this name, it crashes each time.
  alias_method :list_users, :index_user

  # User index, restricted to admins.
  def users_by_name # :norobots:
    if in_admin_mode?
      query = create_query(:User, :all, by: :name)
      show_selected_users(query)
    else
      flash_error(:permission_denied.t)
      redirect_to(action: "list_rss_logs")
    end
  end

  # Display list of User's whose name, notes, etc. match a string pattern.
  def user_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (user = User.safe_find(pattern))
      redirect_to(action: "show_user", id: user.id)
    else
      query = create_query(:User, :pattern_search, pattern: pattern)
      show_selected_users(query)
    end
  end

  def show_selected_users(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: "list_users",
      include: :user_groups,
      matrix: !in_admin_mode?
    }.merge(args)

    # Add some alternate sorting criteria.
    if in_admin_mode?
      args[:sorting_links] = [
        ["id",          :sort_by_id.t],
        ["login",       :sort_by_login.t],
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["last_login",  :sort_by_last_login.t]
      ]
    else
      args[:sorting_links] = [
        ["login",         :sort_by_login.t],
        ["name",          :sort_by_name.t],
        ["created_at",    :sort_by_created_at.t],
        ["location",      :sort_by_location.t],
        ["contribution",  :sort_by_contribution.t]
      ]
    end

    # Paginate by "correct" letter.
    if (query.params[:by] == "login") ||
       (query.params[:by] == "reverse_login")
      args[:letters] = "users.login"
    else
      args[:letters] = "users.name"
    end

    show_index_of_objects(query, args)
  end

  # users_by_contribution.rhtml
  def users_by_contribution # :nologin: :norobots:
    SiteData.new
    @users = User.order("contribution desc, name, login")
  end

  # show_user.rhtml
  def show_user # :nologin: :prefetch:
    store_location
    id = params[:id].to_s
    @show_user = find_or_goto_index(User, id)
    return unless @show_user
    @user_data = SiteData.new.get_user_data(id)
    @life_list = Checklist::ForUser.new(@show_user)
    @query = Query.lookup(:Observation, :by_user,
                          user: @show_user, by: :owners_thumbnail_quality)
    @observations = @query.results(limit: 6)
    return unless @observations.length < 6
    @query = Query.lookup(:Observation, :by_user,
                          user: @show_user, by: :thumbnail_quality)
    @observations = @query.results(limit: 6)
  end

  # Go to next user: redirects to show_user.
  def next_user # :norobots:
    redirect_to_next_object(:next, User, params[:id].to_s)
  end

  # Go to previous user: redirects to show_user.
  def prev_user # :norobots:
    redirect_to_next_object(:prev, User, params[:id].to_s)
  end

  # Display a checklist of species seen by a User, Project,
  # SpeciesList or the entire site.
  def checklist # :nologin: :norobots:
    store_location
    user_id = params[:user_id] || params[:id]
    proj_id = params[:project_id]
    list_id = params[:species_list_id]
    if !user_id.blank?
      if (@show_user = find_or_goto_index(User, user_id))
        @data = Checklist::ForUser.new(@show_user)
      end
    elsif !proj_id.blank?
      if (@project = find_or_goto_index(Project, proj_id))
        @data = Checklist::ForProject.new(@project)
      end
    elsif !list_id.blank?
      if (@species_list = find_or_goto_index(SpeciesList, list_id))
        @data = Checklist::ForSpeciesList.new(@species_list)
      end
    else
      @data = Checklist::ForSite.new
    end
  end

  # Admin util linked from show_user page that lets admin add or change bonuses
  # for a given user.
  def change_user_bonuses # :root: :norobots:
    return unless (@user2 = find_or_goto_index(User, params[:id].to_s))
    if in_admin_mode?
      if request.method != "POST"
        # Reformat bonuses as string for editing, one entry per line.
        @val = ""
        if @user2.bonuses
          vals = @user2.bonuses.map do |points, reason|
            sprintf("%-6d %s", points, reason.gsub(/\s+/, " "))
          end
          @val = vals.join("\n")
        end
      else
        # Parse new set of values.
        @val = params[:val]
        line_num = 0
        errors = false
        bonuses = []
        @val.split("\n").each do |line|
          line_num += 1
          if (match = line.match(/^\s*(\d+)\s*(\S.*\S)\s*$/))
            bonuses.push([match[1].to_i, match[2].to_s])
          else
            flash_error("Syntax error on line #{line_num}.")
            errors = true
          end
        end
        # Success: update user's contribution.
        unless errors
          contrib = @user2.contribution.to_i
          # Subtract old bonuses.
          if @user2.bonuses
            @user2.bonuses.each do |points, _reason|
              contrib -= points
            end
          end
          # Add new bonuses
          bonuses.each do |points, _reason|
            contrib += points
          end
          # Update database.
          @user2.bonuses      = bonuses
          @user2.contribution = contrib
          @user2.save
          redirect_to(action: "show_user", id: @user2.id)
        end
      end
    else
      redirect_to(action: "show_user", id: @user2.id)
    end
  end
end