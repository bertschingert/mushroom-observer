class Query::NameWithObservationsInSet < NameWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      ids:        [Observation],
      old_title?: :string
    )
  end

  def initialize_flavor
    title_args[:observations] = params[:old_title] ||
                                :query_title_in_set.t(type: :observation)
    add_id_condition("observations.id", params[:ids])
    super
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :in_set, params_with_old_by_restored)
  end
end
