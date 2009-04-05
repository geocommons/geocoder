$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'geocoder/us/address'

include Geocoder::US

class TestParse < Test::Unit::TestCase
  def test_constants
    assert_kind_of Array, Fields
    assert_kind_of Array, Fields[0]
    assert_equal :prenum, Fields[0][0]
    assert_equal :plus4, Fields[-1][0]
    assert_kind_of Hash, Field_Index
    assert_equal 0, Field_Index[:prenum]
    assert_equal 16, Field_Index[:plus4]
    assert_equal :street, Fields[Field_Index[:street]][0]
  end
  def test_new
    parse = Parse.new
    assert_equal Fields.length, parse.keys.length
    assert_equal [""] * Fields.length, parse.values
    assert_equal :prenum, parse.state
    assert_equal 0, parse.penalty
  end
  def test_remaining_states
    parse = Parse.new
    assert_equal Fields.length, parse.remaining_states.length
    parse.state = :street
    assert_equal :street, parse.remaining_states[0][0] 
    assert_equal 10, parse.remaining_states.length
    parse.state = :plus4
    assert_equal :plus4, parse.remaining_states[0][0] 
    assert_equal [Fields[-1]], parse.remaining_states
    parse.state = :dogfood
    assert_equal [], parse.remaining_states
    parse.state = nil
    assert_equal [], parse.remaining_states
  end
  def test_next_state
    parse = Parse.new
    parse.next_state!
    assert_equal Fields[1][0], parse.state
    parse.next_state!
    assert_equal Fields[2][0], parse.state
    parse.state = :plus4
    parse.next_state!
    assert_nil parse.state
    parse.next_state!
    assert_nil parse.state
  end
  def test_test
    parse = Parse.new
    assert parse.test?(State, "WV")
    assert !parse.test?(State, "EV")
    assert parse.test?(/[A-Z][A-Z]/o, "WV")
    assert !parse.test?(/[A-Z][A-Z]/o, "55")
    assert parse.test?(lambda {|p,s| p.state == s}, Fields[0][0])
    assert !parse.test?(lambda {|p,s| p.state == s}, Fields[1][0])
    assert_equal false, parse.test?([], "whatever"), "not a valid match arg"
  end
  def test_skip
    parse = Parse.new
    skipped = parse.skip
    assert_not_equal parse.object_id, skipped.object_id
    assert_equal 1, skipped.penalty 
    assert_equal parse.state, skipped.state
  end
  def test_extend
    parse = Parse.new
    parse2 = parse.extend :number, /^\d+$/o, "55"
    assert_not_equal parse.object_id, parse2.object_id
    assert_equal "55", parse2[:number]
    assert_equal :number, parse2.state
    assert_nil parse2.extend(:number, /^\d+$/o, "plus 55")
    parse3 = parse2.extend(:number, /^\d+ \w+ \d+$/o, "plus 55")
    assert_equal "55 plus 55", parse3[:number]
    parse2 = parse.extend :prenum, nil, "55A"
    assert_equal parse.object_id, parse2.object_id
    assert_equal :number, parse.state
    parse2 = parse.extend :number, /^\d+$/o, ","
    assert_equal "", parse[:number]
    assert_equal :sufnum, parse.state
  end
  def test_substitute
    parse = Parse.new 
    parse[:number] = "21-55A"
    parse[:suftyp] = "Street"
    parse.substitute!
    assert "21-", parse[:prenum]
    assert "55", parse[:number]
    assert "A", parse[:sufnum]
    assert "St", parse[:suftyp]
  end
  def test_score
    parse = Parse.new
    parse[:number] = "21-55A"
    parse[:suftyp] = "Street"
    assert 2, parse.score
    parse.substitute!
    assert 4, parse.score
    parse.penalty = 1
    assert 3, parse.score
  end
end
