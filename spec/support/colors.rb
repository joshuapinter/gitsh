require 'gitsh/colors'

module Color
  def self.included(other)
    other.let(:clear) { Gitsh::Colors::CLEAR }
    other.let(:red_background) { Gitsh::Colors::RED_BG }
    other.let(:red) { Gitsh::Colors::RED_FG }
    other.let(:orange) { Gitsh::Colors::ORANGE_FG }
  end
end
