$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'geocoder/us/constants'

include Geocoder::US

class TestConstants < Test::Unit::TestCase
  def initialize (*args)
    @map = Map[
      "Abbreviation" => "abbr",
      "Two words"    => "2words",
      "Some three words" => "3words"
    ]
    super(*args)
  end
  def test_class_constructor
    assert_kind_of Map, @map
    assert_kind_of Hash, @map
  end  
  def test_key
    assert @map.key?( "Abbreviation" )
    assert @map.key?( "abbreviation" )
    assert !(@map.key? "abbreviation?")
    assert @map.key?( "abbr" )
    assert @map.key?( "Two words" )
    assert @map.key?( "2words" )
  end
  def test_fetch
    assert_equal "abbr", @map["Abbreviation"]
    assert_equal "abbr", @map["abbreviation"]
    assert_nil @map["abbreviation?"]
    assert_equal "abbr", @map["abbr"]
    assert_equal "2words", @map["Two words"]
    assert_equal "2words", @map["2words"]
  end
#  def test_partial
#    assert @map.partial?( "Abbreviation" )
#    assert @map.partial?( "Two" )
#    assert @map.partial?( "two" )
#    assert !(@map.partial? "words")
#    assert @map.partial?( "Some" )
#    assert !(@map.partial? "words")
#    assert @map.partial?( "Some three" )
#    assert @map.partial?( "SOME THREE WORDS" )
#  end
  def test_constants
    assert_kind_of Map, Directional
    assert_kind_of Map, Prefix_Qualifier
    assert_kind_of Map, Suffix_Qualifier
    assert_kind_of Map, Prefix_Type
    assert_kind_of Map, Suffix_Type
    assert_kind_of Map, Unit_Type
    assert_kind_of Map, Name_Abbr
    assert_kind_of Map, State
  end
end
