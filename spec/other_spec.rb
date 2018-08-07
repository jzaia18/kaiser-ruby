RSpec.describe KaiserRuby do
  context 'output' do
    it 'prints values' do
      expect(KaiserRuby.transpile('Scream my love')).to eq 'puts my_love'
    end
  end

  context 'metal umlauts' do
    let(:metal_lyrics) do <<~METAL
        Motörhead says We're so metäl we have umläuts everywhere!
        Scream Motörhead
        Ümlaut is gone
      METAL
    end

    it 'handles metal umlauts both in variables and values' do
      expect(KaiserRuby.transpile(metal_lyrics)).to eq <<~PURE_METAL
        motörhead = "We're so metäl we have umläuts everywhere!"
        puts motörhead
        ümlaut = 0
      PURE_METAL
    end
  end

  context 'verses' do
    let(:more_lines) do <<~END
        Put 5 into your heart
        Whisper your heart
      END
    end

    it 'ignores empty lines' do
      expect(KaiserRuby.transpile("\n")).to eq "\n"
    end

    it 'transpiles a string' do
      expect(KaiserRuby.transpile('Tommy is a vampire')).to eq 'tommy = 17'
    end

    it 'transpiles a single line' do
      expect(KaiserRuby.transpile("Put 3 into your mind\n")).to eq "your_mind = 3"
    end

    it 'transpiles multiple lines' do
      expect(KaiserRuby.transpile(more_lines)).to eq <<~RESULT
        your_heart = 5
        puts your_heart
      RESULT
    end
  end

  context 'lyrics' do
    let(:lyrics) do <<~END
        Put 5 into your heart
        Whisper your heart

        Put "Ruby" into a rockstar
        Scream a rockstar
      END
    end

    it 'transpiles multiple blocks of code' do
      expect(KaiserRuby.transpile(lyrics)).to eq <<~RESULT
        your_heart = 5
        puts your_heart

        a_rockstar = "Ruby"
        puts a_rockstar
      RESULT
    end
  end

  context 'comments' do
    let(:comments) do <<~END
        Ruby is a language
        (a programming one)
      END
    end

    it 'transforms comments to ruby comments' do
      expect(KaiserRuby.transpile(comments)).to eq <<~RESULT
        ruby = 18
        # a programming one
      RESULT
    end
  end
end