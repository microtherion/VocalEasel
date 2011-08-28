#
# vl - VocalEasel common filter infrastructure
#

class VL
  NoPitch = -128
  
  TiedWithNext = 1
  TiedWithPrev = 2
  WantSharp    = 0x10
  Want2Sharp   = 0x20
  WantFlat     = 0x40
  Want2Flat    = 0x80
  WantNatural  = 0x50
  Accidentals  = 0xF0

  Unison       = 1<<0
  Min2nd       = 1<<1
  Maj2nd       = 1<<2
  Min3rd       = 1<<3
  Maj3rd       = 1<<4
  Fourth       = 1<<5
  Dim5th       = 1<<6
  Fifth        = 1<<7
  Aug5th       = 1<<8
  Dim7th       = 1<<9
  Min7th       = 1<<10
  Maj7th       = 1<<11
  Octave       = 1<<12
  Min9th       = 1<<13
  Maj9th       = 1<<14
  Aug9th       = 1<<15
  Dim11th      = 1<<16
  Eleventh     = 1<<17
  Aug11th      = 1<<18
  Dim13th      = 1<<19
  Min13th      = 1<<20
  Maj13th      = 1<<21

  class Chord
    #
    # Triads
    #
    Maj    = VL::Unison+VL::Maj3rd+VL::Fifth
    Min    = VL::Unison+VL::Min3rd+VL::Fifth
    Aug    = VL::Unison+VL::Maj3rd+VL::Aug5th
    Dim    = VL::Unison+VL::Min3rd+VL::Dim5th
    #
    # 7ths
    #
    Dom7   = Maj+VL::Min7th
    Maj7   = Maj+VL::Maj7th
    Min7   = Min+VL::Min7th
    Dim7   = Dim+VL::Dim7th
    Aug7   = Aug+VL::Min7th
    M7b5   = Dim+VL::Min7th
    MMin7  = Min+VL::Maj7th
    #
    # 6ths
    #
    Maj6   = Maj+VL::Dim7th
    Min6   = Min+VL::Dim7th
    # 
    # 9ths
    #
    Dom9   = Dom7+VL::Maj9th
    Maj9   = Maj7+VL::Maj9th
    Min9   = Min7+VL::Maj9th
    #
    # 11ths
    #
    Dom11  = Dom9+VL::Eleventh
    Maj11  = Maj9+VL::Eleventh
    Min11  = Min9+VL::Eleventh
    #
    # 13ths
    #
    Dom13  = Dom11+VL::Maj13th
    Maj13  = Maj11+VL::Maj13th
    Min13  = Min11+VL::Maj13th
    #
    # Suspended
    #
    Sus4   = VL::Unison+VL::Fourth+VL::Fifth
    Sus2   = VL::Unison+VL::Maj2nd+VL::Fifth
  end

  class Fract
    include Comparable

    def initialize(num, denom)
      @num   = num
      @denom = denom

      normalize()
    end

    def num
      return @num
    end

    def denom
      return @denom
    end

    def _gcd(x, y)
      while y != 0
        x,y = [y, x % y]
      end
      
      return x
    end

    def normalize
      g       = _gcd(@num, @denom)
      @num   /= g
      @denom /= g
    end

    def -@()
      return Fract.new(-@num, @denom)
    end

    def +(other)
      return Fract.new(@num*other.denom+other.num*@denom, @denom*other.denom)
    end

    def -(other)
      return Fract.new(@num*other.denom-other.num*@denom, @denom*other.denom)
    end

    def <=>(other)
      return @num*other.denom <=> other.num*@denom
    end
  end
end

if ARGV.size > 0
  INFILE = File.new(ARGV[0], "r")
else
  INFILE = $stdin
end
