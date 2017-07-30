require 'byebug'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

RSpec.configure do |config|

  # cature Thor's STDOUT
  # https://github.com/erikhuda/thor/blob/9dde9502be1730d59eafe2a2e8b3361cb11e3bb7/spec/helper.rb#L50
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

end
