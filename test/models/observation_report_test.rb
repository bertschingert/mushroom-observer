require "test_helper"

class ObservationReportTest < UnitTestCase
  def do_report_test(report_type, obs, expect, &block)
    query = Query.lookup(:Observation, :all)
    report = report_type.new(query: query).body
    assert_not_empty(report)
    table = CSV.parse(report)
    assert_equal(query.num_results + 1, table.count)
    idx = query.results.sort_by(&block).index(obs)
    assert_equal(expect, table[idx+1], "(coprinus_comatus_obs)")
  end

  def test_adolf
    obs = observations(:agaricus_campestris_obs)
    do_report_test(ObservationReport::Adolf, obs, [
      nil,
      nil,
      nil,
      "Agaricus",
      nil,
      "campestris",
      "L.",
      nil,
      nil,
      nil,
      nil,
      "USA",
      "California",
      "Burbank",
      "34.15",
      "-118.37",
      "34.22",
      "-118.29",
      nil,
      nil,
      nil,
      nil,
      "2007-03-19",
      "Rolf Singer",
      nil,
      nil,
      nil,
      "From the lawn next door",
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      obs.id.to_s,
      nil
    ], &:text_name)
  end

  def test_darwin
    obs = observations(:detailed_unknown_obs)
    do_report_test(ObservationReport::Darwin, obs, [
      "2006-05-12 17:21:00 UTC",
      "MushroomObserver",
      nil,
      obs.id.to_s,
      "Fungi",
      nil,
      "Kingdom",
      "Fungi",
      nil,
      nil,
      "Mary Newbie",
      "2006-05-11",
      "2006",
      "5",
      "11",
      "USA",
      "California",
      nil,
      "Burbank",
      "34.185",
      "-118.33",
      "148",
      "294",
      "Found in a strange place... & with śtrangè characters™"
    ], &:id)
  end

  def test_mycoflora
    obs = observations(:detailed_unknown_obs)
    img1, img2 = obs.images.sort_by(&:id)
    do_report_test(ObservationReport::Mycoflora, obs, [
      obs.id.to_s,
      "Fungi",
      nil,
      "Kingdom",
      "Mary Newbie",
      "2006-05-11",
      "USA, California, Burbank",
      "34.185",
      "-118.33",
      "148",
      "294",
      "2006-05-12 17:21:00 UTC",
      "Found in a strange place... & with śtrangè characters™",
      "http://mushroomobserver.org/#{obs.id}",
      "http://mushroomobserver.org//remote_images/orig/#{img1.id}.jpg " \
        "http://mushroomobserver.org//remote_images/orig/#{img2.id}.jpg"
    ], &:id)
  end

  def test_raw
    obs = observations(:detailed_unknown_obs)
    do_report_test(ObservationReport::Raw, obs, [
      obs.id.to_s,
      obs.user.id.to_s,
      "mary",
      "Mary Newbie",
      "2006-05-11",
      "X",
      "Cortinarius sp.: NYBG 1234",
      obs.name.id.to_s,
      "Fungi",
      nil,
      "Kingdom",
      "0.0",
      "547147019",
      "USA",
      "California",
      nil,
      "Burbank",
      nil,
      nil,
      nil,
      "34.22",
      "34.15",
      "-118.29",
      "-118.37",
      "294",
      "148",
      "X",
      obs.thumb_image.id.to_s,
      "Found in a strange place... & with śtrangè characters™"
    ], &:id)
  end

  def test_symbiota
    obs = observations(:unknown_with_lat_long)
    do_report_test(ObservationReport::Symbiota, obs, [
      "Fungi",
      nil,
      "Kingdom",
      "Fungi",
      nil,
      nil,
      "Mary Newbie",
      obs.id.to_s,
      "2010-07-22",
      "2010",
      "7",
      "22",
      "USA",
      "California",
      nil,
      "Burbank",
      "34.1622",
      "-118.3521",
      "148",
      "294",
      "2010-07-22 09:21:00 UTC",
      "unknown_with_lat_long"
    ], &:id)
  end

  def test_row_formatting_directly
    # TODO
  end
end
