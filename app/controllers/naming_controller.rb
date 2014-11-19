# encoding: utf-8

# Controller for handling the naming of observations
class NamingController < ApplicationController
  before_filter :login_required

  before_filter :disable_link_prefetching, except: [
    :create,
    :edit]

  def edit # :prefetch: :norobots:
    pass_query_params
    @params = NamingParams.new
    naming = @params.naming = Naming.from_params(params)
    @params.observation = naming.observation
    return default_redirect(naming.observation) unless check_permission!(naming)
    @params.vote = naming.first_vote # TODO: Can this get moved into NamingParams#naming=
    request.method == "POST" ? edit_post : @params.edit_init
  end

  def create # :prefetch: :norobots:
    pass_query_params
    @params = NamingParams.new
    @params.observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @params.observation
    create_post if request.method == "POST"
  end

  def destroy # :norobots:
    pass_query_params
    naming = Naming.find(params[:id].to_s)
    if can_destroy?(naming)
      Transaction.delete_naming(id: naming)
      flash_notice(:runtime_destroy_naming_success.t(id: params[:id].to_s))
    end
    default_redirect(naming.observation)
  end

  private

  def can_destroy?(naming)
    if !check_permission!(naming)
      flash_error(:runtime_destroy_naming_denied.t(id: naming.id))
    elsif !naming.deletable?
      flash_warning(:runtime_destroy_naming_someone_else.t)
    elsif !naming.destroy
      flash_error(:runtime_destroy_naming_failed.t(id: naming.id))
    else
      true
    end
  end

  def create_post
    if rough_draft && can_save?
      save_changes
      check_for_notifications
    else # If anything failed reload the form.
      @params.add_reason(params[:reason])
    end
  end

  def rough_draft
    @params.rough_draft(params[:naming], params[:vote],
                        param_lookup([:name, :name]),
                        params[:approved_name],
                        param_lookup([:chosen_name, :name_id], "").to_s)
  end

  def check_for_notifications
    action = if has_unshown_notifications?(@user, :naming)
               :show_notifications
             else
               :show_observation
             end
    default_redirect(@params.observation, action)
  end

  def can_save?
    unproposed_name(:runtime_create_naming_already_proposed) &&
      validate_object(@params.naming) &&
      validate_object(@params.vote)
  end

  def unproposed_name(warning)
    @params.name_been_proposed? ? flash_warning(warning.t) : true
  end

  def validate_name
    success = resolve_name(param_lookup([:name, :name], "").to_s,
                           param_lookup([:chosen_name, :name_id], "").to_s)
    flash_object_errors(@params.naming) if @params.name_missing?
    success
  end

  def default_redirect(obs, action = :show_observation)
    redirect_with_query(controller: :observer,
                        action: action,
                        id: obs.id)
  end

  def edit_post
    if validate_name &&
        (@params.naming_is_name? ||
         unproposed_name(:runtime_edit_naming_someone_else))
      @params.need_new_naming? ? create_new_naming : change_naming
      default_redirect(@params.observation)
    else
      @params.add_reason(params[:reason])
    end
  end

  def create_new_naming
    @params.rough_draft(params[:naming], params[:vote])
    naming = @params.naming
    return unless validate_object(naming) && validate_object(@params.vote)
    naming.create_reasons(params[:reason], params[:was_js_on] == "yes")
    save_with_transaction(naming)
    @params.logged_change_vote
    flash_warning :create_new_naming_warn.l
  end

  def change_naming
    return unless @params.update_name(@user, params[:reason],
                                      params[:was_js_on] == "yes")
    flash_notice(:runtime_naming_updated_at.t)
    @params.change_vote(param_lookup([:vote, :value]) { |r| r.to_i })
  end

  def save_changes
    @params.update_naming(params[:reason], params[:was_js_on] == "yes")
    save_with_transaction(@params.naming)
    @params.save_vote
  end

  def resolve_name(given_name, chosen_name)
    @params.resolve_name(given_name, params[:approved_name], chosen_name)
  end
end