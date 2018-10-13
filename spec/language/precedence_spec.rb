RSpec.describe KaiserRuby do
  context 'operator precedence' do
    it 'function call with mixed arguments' do
      expect(KaiserRuby.transpile('A taking B, C and D')).to eq 'a(@b, @c, @d)'
    end

    it 'function call with math operation' do
      expect(KaiserRuby.transpile('say A taking B, C plus D')).to eq 'puts a(@b, @c) + @d'
    end

    it 'function call with logical and math' do
      expect(KaiserRuby.transpile('say A taking B, C plus D and E')).to eq 'puts a(@b, @c) + @d && @e'
    end

    it 'function call with logical and comparison' do
      expect(KaiserRuby.transpile('If Modulus taking Counter and Fizz is 0')).to eq 'if modulus(@counter, @fizz) == 0'
    end

    it 'function call with literal numbers' do
      expect(KaiserRuby.transpile('say A taking 3, 4 and 5')).to eq 'puts a(3, 4, 5)'
    end

    it 'function call with literal numbers' do
      expect(KaiserRuby.transpile('say B times A taking C')).to eq 'puts @b * a(@c)'
    end
  end
end