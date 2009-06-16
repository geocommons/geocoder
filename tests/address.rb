$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'set'
require 'geocoder/us/address'

include Geocoder::US

class TestAddress < Test::Unit::TestCase
  def test_new
    addr = Address.new("1600 Pennsylvania Av., Washington DC")
    assert_equal "1600 Pennsylvania Av., Washington DC", addr.text
  end
  def test_clean
    addr = Address.new("")
    assert_equal "cleaned text", addr.clean("cleaned: text!")
    assert_equal "cleaned-text #2", addr.clean("cleaned-text: #2?")
    assert_equal "it's working 1/2", addr.clean("~it's working 1/2~")
    assert_equal "it's working, yes", addr.clean("it's working, yes...?")
  end
  def test_tokenize
    addr = Address.new("  1600 Pennsylvania Av.,  Washington DC   ")
    tokens = ["1600", "Pennsylvania", "Av", ",", "Washington", "DC"]
    assert_equal tokens, addr.tokenize
  end
  def test_expand_token
    addr = Address.new("")
    num_list = ["5", "fifth", "five"]
    num_list.each {|n|
      assert_equal num_list, addr.expand_token(n).to_a.sort
    }
    ex = addr.expand_token("St")
    assert_kind_of Array, ex
    assert !(ex.member? nil)
    assert_equal ["Saint","St"], ex.to_a.sort
    assert_equal ["St","Street"], addr.expand_token("Street").to_a.sort
    assert_equal ["Mount","Mt"], addr.expand_token("Mt").to_a.sort
  end
  def test_city_parse
    places = [
      [ "New York, NY",     "New York", "NY", "" ],
      [ "New York",         "New York", "",   "" ],
      [ "Philadelphia",     "Philadelphia", "", "" ],
      [ "Philadelphia PA",  "Philadelphia", "PA", "" ],
      [ "Philadelphia, PA", "Philadelphia", "PA", "" ],
      [ "Philadelphia, Pennsylvania", "Philadelphia", "PA", "" ],
      [ "Philadelphia, Pennsylvania 19131", "Philadelphia", "PA", "19131" ],
      [ "Philadelphia 19131", "Philadelphia", "", "19131" ],
      [ "Pennsylvania 19131", "Pennsylvania", "", "19131" ], # kind of a misfeature
      [ "19131", "", "", "19131" ],
      [ "19131-9999", "", "", "19131" ],
    ]
    for fixture in places
      addr  = Address.new fixture[0]
      [:city, :state, :zip].zip(fixture[1..3]).each {|key,val|
        result = addr.send key
        print "fixture #{key} #{val} #{result.inspect}\n"
        assert result.member?(val), "city test " + fixture.join("/")
      }
    end
  end

#  def test_parse
#    addrs = [
#      {:text   => "1600 Pennsylvania Av., Washington DC 20050",
#       :number => "1600",
#       :street => "Pennsylvania",
#       :suftyp => "Ave",
#       :city   => "Washington",
#       :state  => "DC",
#       :zip    => "20050"},
#
#      {:text   => "1600 Pennsylvania, Washington DC",
#       :number => "1600",
#       :street => "Pennsylvania",
#       :city   => "Washington",
#       :state  => "DC"},
#
#      {:text   => "1600 Pennsylvania Washington DC",
#       :number => "1600",
#       :street => "Pennsylvania",
#       :city   => "Washington",
#       :state  => "DC"},
#
#      #{:text   => "1600 Pennsylvania Washington",
#      # :number => "1600",
#      # :street => "Pennsylvania",
#      # :city   => "Washington"},
#
#      #{:text   => "1600 Pennsylvania 20050",
#      # :number => "1600",
#      # :street => "Pennsylvania",
#      # :zip    => "20050"},
#
#      {:text   => "1600 Pennsylvania Av, 20050-9999",
#       :number => "1600",
#       :street => "Pennsylvania",
#       :suftyp => "Ave",
#       :zip    => "20050",
#       :plus4  => "9999"},
#
#      {:text   => "1600A Pennsylvania",
#       :number => "1600",
#       :sufnum => "A",
#       :street => "Pennsylvania"},
#
#      {:text   => "A1600 Pennsylvania",
#       :number => "1600",
#       :prenum => "A",
#       :street => "Pennsylvania"},
#
#      {:text   => "1600 1/2 Pennsylvania Av",
#       :number => "1600",
#       :fraction => "1/2",
#       :street => "Pennsylvania",
#       :suftyp => "Ave",
#       :index  => 2},
#
#      {:text   => "1600 Pennsylvania Apt C",
#       :number => "1600",
#       :street => "Pennsylvania",
#       :unittyp => "Apt",
#       :unit   => "C"},
#
#      {:text   => "1005 Gravenstein Highway North",
#       :number => "1005",
#       :street => "Gravenstein",
#       :suftyp => "Hwy",
#       :sufdir => "N"},
#
#      {:text   => "100 N 7 St, Brooklyn",
#       :number => "100",
#       :predir => "N",
#       :street => "7",
#       :suftyp => "St"},
#
#      #{:text   => "100 N 7th St, Brooklyn",
#      # :number => "100",
#      # :predir => "N",
#      # :street => "7",
#      # :suftyp => "St"},
#
#      {:text   => "100 N Seventh St, Brooklyn",
#       :number => "100",
#       :predir => "N",
#       :street => "7",
#       :suftyp => "St"},
#
#      {:text   => "100 Central Park West, New York, NY",
#       :number => "100",
#       :street => "Central Park",
#       :sufdir => "W"},
#
#      {:text   => "100 Central Park West, 10010",
#       :index  => 2,
#       :number => "100",
#       :street => "Central Park",
#       :sufdir => "W"},
#
#      {:text   => "1400 Avenue of the Americas, New York, NY 10019",
#       :number => "1400",
#       :pretyp => "Ave",
#       :street => "of the Americas",
#       :city   => "New York",
#       :state  => "NY"},
#
#      {:text   => "1400 Avenue of the Americas, New York",
#       :index  => 2,
#       :number => "1400",
#       :pretyp => "Ave",
#       :street => "of the Americas",
#       :city   => "New York"},
#
#      {:text   => "1400 Ave of the Americas, New York",
#       :index  => 2,
#       :number => "1400",
#       :pretyp => "Ave",
#       :street => "of the Americas",
#       :city   => "New York"},
#
#      {:text   => "1400 Av of the Americas, New York",
#       :index  => 2,
#       :number => "1400",
#       :pretyp => "Ave",
#       :street => "of the Americas",
#       :city   => "New York"},
#
#      {:text   => "1400 Av of the Americas New York",
#       :index  => 5,
#       :number => "1400",
#       :pretyp => "Ave",
#       :street => "of the Americas",
#       :city   => "New York"},
#    ]
#    for fixture in addrs
#      text = fixture.delete :text
#      idx  = fixture.delete(:index) || 0
#      addr = Address.new(text)
#      result = addr.parse(0,25)
#      assert_kind_of Array, result
#      assert result.length <= 25
#      #result.each_with_index {|x,i| print [i,x.score,x.inspect.length,x].inspect, "\n"}
#      for key, val in fixture
#        assert_kind_of Parse, result[idx]
#        assert_equal val, result[idx][key], "#{text} (#{key})"
#      end
#    end
#  end
end
