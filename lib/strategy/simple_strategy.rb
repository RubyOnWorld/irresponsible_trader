# Buys every time you are not invested and stock price drops.
# Sell every time the stock price is more than LIMIT % higher than when you bought.
# Adapted from Sentdex Algorithmic Trading tutorial: http://bit.ly/1gW231h

module Strategy
  class SimpleStrategy < Base
    LIMIT = 1

    def initialize feeder, starting_capital, commission_per_trade
      @feeder = feeder
      Frappuccino::Stream.new(feeder).
        select{ |event| event.has_key?(:bar) && event[:bar].present? }.
        map{ |event| event[:bar] }.
        on_value(&method(:on_bar))

      @portfolio = Portfolio.new self, starting_capital, commission_per_trade
      @last_close = {}
    end

    def on_bar bar
      @date = bar.date
      bar.bar_data.each do |symbol, data|
        holding_for_symbol = @portfolio.holdings[symbol].to_i
        current_close = data[:adj_close].to_f
        last_close = @last_close[symbol].to_f
        change = current_close - last_close
        change_pct = (change / last_close) * 100
        trade_type = if holding_for_symbol == 0 && change < 0
                       :buy
                     elsif holding_for_symbol > 0 && change_pct > LIMIT
                       :sell
                     end

        # keep current's adj_close so that on next bar we can
        # refer to the last bar's adj_close
        @last_close[symbol] = current_close

        if trade_type.present?
          # TODO look-ahead bias here - should only place order on the next bar
          emit symbol: symbol, type: trade_type, price: current_close
        end
      end
    end
  end
end
