$LOAD_PATH.unshift '../lib'

require 'test/unit'
require 'set'
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
    assert_equal Block_State+1, parse.remaining_states.length
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
    assert_nil parse.extend(:prenum, nil, "55A")
    parse2 = parse.extend :number, /^\d+$/o, ","
    assert_equal "", parse2[:number]
    assert_equal :sufnum, parse2.state
  end
  def test_substitute
    parse = Parse.new 
    parse[:number] = "21-55A"
    parse[:suftyp] = "Street"
    parse.substitute!
    assert_equal "21-", parse[:prenum]
    assert_equal "55", parse[:number]
    assert_equal "A", parse[:sufnum]
    assert_equal "St", parse[:suftyp]
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
  def test_tokens
    addr = Address.new("  1600 Pennsylvania Av.,  Washington DC   ")
    tokens = ["1600", "Pennsylvania", "Av", ",", "Washington", "DC"]
    assert_equal tokens, addr.tokens
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
    assert_equal ["Mount","Mt"], addr.expand_token("Mt").to_a.sort
  end

  def assert_state (state, value, parse)
    assert_equal state, parse.state
    assert_equal value, parse[state]
  end

  def test_parse_token
    addr  = Address.new "Test"
    stack = addr.parse_token([Parse.new], "Test", 0)
    assert_equal 1, stack.size
    assert_state :street, "Test", stack[0]

    stack = addr.parse_token([stack[0]], "2", 0)
    assert_equal 5, stack.size # expansions of "2"
    assert_state :street, "Test 2", stack[0]
    assert_state :street, "Test second", stack[1]
    assert_state :street, "Test two", stack[2]
    assert_state :city,   "second", stack[3]
    assert_state :city,   "two", stack[4]

    stack = addr.parse_token([Parse.new], "3", 0)
    assert_equal 4, stack.size # expansions of "3"
    assert_state :number, "3", stack[0]
    assert_state :street, "3", stack[1]
    assert_state :street, "third", stack[2]
    assert_state :street, "three", stack[3]
    
    parse = Parse.new
    parse.state = :street
    stack = addr.parse_token([parse], "st", 0)
    assert_equal 5, stack.size # expansions of "st"
    assert_state :street, "Saint", stack[0]
    assert_state :street, "st",    stack[1]
    assert_state :suftyp, "st",    stack[2]
    assert_state :city,   "Saint", stack[3]
    assert_state :city,   "st",    stack[4]

    stack2 = addr.parse_token(stack, "apt", 1)
    assert_equal 15, stack2.length # test out penalty parsing

    stack = addr.parse_token(stack, "apt", 0)
    assert_equal 10, stack.size
    assert_state :street,  "Saint apt", stack[0] # 1->0
    assert_state :unittyp, "apt",    stack[1]    # 0->1
    assert_state :city,    "apt",    stack[2]    # 0->2
    assert_state :street,  "st apt", stack[3]    # 0->0
    assert_state :unittyp, "apt",    stack[4]    # 1->1
    assert_state :city,    "apt",    stack[5]    # 1->2
    assert_state :unittyp, "apt",    stack[6]    # 2->0
    assert_state :city,    "apt",    stack[7]    # 2->1
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
      result = addr.parse(0,10,:city)
      assert result.any?
      assert_kind_of Parse, result[0]
      for key, val in [:city, :state, :zip].zip(fixture[1..3]) do
        assert_equal val, result[0][key], "city test " + fixture.join("/")
      end
    end
  end

  def test_parse
    addrs = [
      {:text   => "1600 Pennsylvania Av., Washington DC 20050",
       :number => "1600",
       :street => "Pennsylvania",
       :suftyp => "Ave",
       :city   => "Washington",
       :state  => "DC",
       :zip    => "20050"},

      {:text   => "1600 Pennsylvania, Washington DC",
       :number => "1600",
       :street => "Pennsylvania",
       :city   => "Washington",
       :state  => "DC"},

      {:text   => "1600 Pennsylvania Washington DC",
       :number => "1600",
       :street => "Pennsylvania",
       :city   => "Washington",
       :state  => "DC"},

      #{:text   => "1600 Pennsylvania Washington",
      # :number => "1600",
      # :street => "Pennsylvania",
      # :city   => "Washington"},

      #{:text   => "1600 Pennsylvania 20050",
      # :number => "1600",
      # :street => "Pennsylvania",
      # :zip    => "20050"},

      {:text   => "1600 Pennsylvania Av, 20050-9999",
       :number => "1600",
       :street => "Pennsylvania",
       :suftyp => "Ave",
       :zip    => "20050",
       :plus4  => "9999"},

      {:text   => "1600A Pennsylvania",
       :number => "1600",
       :sufnum => "A",
       :street => "Pennsylvania"},

      {:text   => "A1600 Pennsylvania",
       :number => "1600",
       :prenum => "A",
       :street => "Pennsylvania"},

      {:text   => "1600 1/2 Pennsylvania Av",
       :number => "1600",
       :fraction => "1/2",
       :street => "Pennsylvania",
       :suftyp => "Ave",
       :index  => 2},

      {:text   => "1600 Pennsylvania Apt C",
       :number => "1600",
       :street => "Pennsylvania",
       :unittyp => "Apt",
       :unit   => "C"},

      {:text   => "1005 Gravenstein Highway North",
       :number => "1005",
       :street => "Gravenstein",
       :suftyp => "Hwy",
       :sufdir => "N"},

      {:text   => "100 N 7 St, Brooklyn",
       :number => "100",
       :predir => "N",
       :street => "7",
       :suftyp => "St"},

      #{:text   => "100 N 7th St, Brooklyn",
      # :number => "100",
      # :predir => "N",
      # :street => "7",
      # :suftyp => "St"},

      {:text   => "100 N Seventh St, Brooklyn",
       :number => "100",
       :predir => "N",
       :street => "7",
       :suftyp => "St"},

      {:text   => "100 Central Park West, New York, NY",
       :number => "100",
       :street => "Central Park",
       :sufdir => "W"},

      {:text   => "100 Central Park West, 10010",
       :index  => 1,
       :number => "100",
       :street => "Central Park",
       :sufdir => "W"},

      {:text   => "1400 Avenue of the Americas, New York, NY 10019",
       :number => "1400",
       :pretyp => "Ave",
       :street => "of the Americas",
       :city   => "New York",
       :state  => "NY"},

      {:text   => "1400 Avenue of the Americas, New York",
       :index  => 2,
       :number => "1400",
       :pretyp => "Ave",
       :street => "of the Americas",
       :city   => "New York"},

      {:text   => "1400 Ave of the Americas, New York",
       :index  => 2,
       :number => "1400",
       :pretyp => "Ave",
       :street => "of the Americas",
       :city   => "New York"},

      {:text   => "1400 Av of the Americas, New York",
       :index  => 2,
       :number => "1400",
       :pretyp => "Ave",
       :street => "of the Americas",
       :city   => "New York"},

      {:text   => "1400 Av of the Americas New York",
       :index  => 5,
       :number => "1400",
       :pretyp => "Ave",
       :street => "of the Americas",
       :city   => "New York"},
    ]
    for fixture in addrs
      text = fixture.delete :text
      idx  = fixture.delete(:index) || 0
      addr = Address.new(text)
      result = addr.parse(0,25)
      assert_kind_of Array, result
      assert result.length <= 25
      #result.each_with_index {|x,i| print [i,x.score,x.inspect.length,x].inspect, "\n"}
      for key, val in fixture
        assert_kind_of Parse, result[idx]
        assert_equal val, result[idx][key], "#{text} (#{key})"
      end
    end
  end
end
