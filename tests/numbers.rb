$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'geocoder/us/numbers'

include Geocoder::US

class TestAddress < Test::Unit::TestCase
  def test_number_to_cardinal
    assert_equal 'one', Cardinals[1]
    assert_equal 'ten', Cardinals[10] 
    assert_equal 'twelve', Cardinals[12] 
    assert_equal 'eighty-seven', Cardinals[87]
  end

  def test_cardinal_to_number
    assert_equal 1,   Cardinals['one'] 
    assert_equal 1,   Cardinals['One']
    assert_equal 10,  Cardinals['ten']
    assert_equal 12,  Cardinals['twelve']
    assert_equal 87,  Cardinals['eighty-seven']
    assert_equal 87,  Cardinals['eighty seven']
    assert_equal 87,  Cardinals['eightyseven']
  end

  def test_number_to_ordinal
    assert_equal 'first', Ordinals[1]
    assert_equal 'second', Ordinals[2]
    assert_equal 'tenth', Ordinals[10] 
    assert_equal 'twelfth', Ordinals[12] 
    assert_equal 'twentieth', Ordinals[20]
    assert_equal 'twenty-second', Ordinals[22]
    assert_equal 'eighty-seventh', Ordinals[87]
  end

  def test_ordinal_to_number
    assert_equal 1,   Ordinals['first'] 
    assert_equal 1,   Ordinals['First']
    assert_equal 10,  Ordinals['tenth']
    assert_equal 12,  Ordinals['twelfth']
    assert_equal 73,  Ordinals['seventy-third']
    assert_equal 74,  Ordinals['seventy  fourth']
    assert_equal 75,  Ordinals['seventyfifth']
    assert_equal nil, Ordinals['seventy-eleventh']
  end
end
