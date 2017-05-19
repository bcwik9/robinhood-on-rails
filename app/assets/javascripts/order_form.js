OrderForm = function(element) {
  var element = $("."+element.attr("class"))
  var side = element.data("side")
  var price = element.data("price")
  var price_input = element.find("#price")
  var market_price = price_input.siblings(".market-placeholder")
  var stop_input = element.find("#stop_price").parent()

  var get_order_description = function(type) {
    if(side === "buy") {
      if(type == "Market"){
        return "Market orders execute at the following market price. Market buy orders are adjusted to limit orders collared up to 5%. Limit orders higher than the current offering will be executed at the next best available price. Keep in mind that the price you see when you enter the order may differ from the executed price."
      } else if(type === "Limit") {
        return "Limit orders specify the maximum amount you are willing to pay for a stock."
      } else if(type === "Stop loss") {
        return "Stop loss orders trigger a market order to buy when the stop price is reached."
      } else if(type === "Stop limit") {
        return "Stop limit orders will trigger a specified limit order when the stop price is met. This may be used to limit the price your trade will execute for after the stop is triggered, but there is risk that it will not execute if the stock moves past it."
      }
    // SELL
    } else {
      if(type == "Market"){
        return "The order will sell at the next best available price. Keep in mind that the price you see when you place the order may differ from the executed price."
      } else if(type === "Limit") {
        return " Limit orders specify the minimum amount you are willing to receive when selling a stock."
      } else if(type === "Stop loss") {
        return "Stop loss orders trigger a market order to sell when the stop price is met."
      } else if(type === "Stop limit") {
        return "Stop limit orders will trigger a specified limit order when the stop price is reached. This may be used to limit the price your trade will execute for after the stop is triggered, but there is risk that it will not execute if the stock moves past it."
      }
    }
  }

  var update_order_description = function(type){
    description = get_order_description(type)
    element.find(".order-description").text(description)  
  }

  var update_input_states = function(type) {
    set_price_input_state(false)
    stop_input.hide()
    if(type == "Limit") {
      set_price_input_state(true)
    } else if(type == "Stop loss") {
      stop_input.show()
    } else if(type == "Stop limit"){
      set_price_input_state(true)
      stop_input.show()
    }
  }

  var set_price_input_state = function(enabled) {
    if(enabled) {
      price_input.show()
      market_price.hide()
    } else {
      price_input.hide()
      market_price.show()
    }
  }

  var init = function() {
    order_select_field = element.find("select[name=type]")
    type = order_select_field.val()
    update_order_description(type)
    update_input_states(type)

    order_select_field.on("change", function(event){
      type = $(event.target).val()
      update_input_states(type)
      update_order_description(type)
    })
  }

  init()
}