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
end
