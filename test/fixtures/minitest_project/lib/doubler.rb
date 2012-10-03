class Doubler
  def double x
    if Numeric === x
      x * 2
    else
      "NaN"
    end
  end
end
