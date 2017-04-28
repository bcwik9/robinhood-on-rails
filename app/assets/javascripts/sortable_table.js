SortableTables = function(element) {

  var update_list = function(target, drag_target) {
    id = target.data("id")
    sort_target = target.data("sort-target")
    instrument_order = []
    robinhood_order = []
    $.each(target.find(sort_target), function(index,e) {
      instrument_order.push($(e).data("instrument-id"))
    })
    $.each($(sort_target), function(index,e) {
      robinhood_order.push($(e).data("instrument-id"))
    })
    $.post("reorder_positions", {id: id, instrument_id: drag_target.data("instrument-id"), instrument_order: instrument_order, robinhood_order: robinhood_order})
  }

  var init = function() {
    $.each($(".sortable-table"), function(index,t) {
      table = $(t)
      table.sortable({
        items: table.data("sort-target"),
        connectWith: ".sortable-table",
        receive: function(event,ui) {
          // item moved to a different list
          update_list($(event.target), $(ui.item))
        },
        stop: function(event,ui){
          if($(event.target).find(ui.item).parent().length) {
            // item moved within the same list
            update_list($(event.target), $(ui.item))
          }
        }
      })
    })
  }

  init()
}