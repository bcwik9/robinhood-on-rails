SortableTables = function(element) {

  var update_list = function(target, drag_target) {
    id = target.data("id")
    instrument_order = []
    $.each(target.find(".investment"), function(index,e) {
      instrument_order.push($(e).data("instrument-id"))
    })
    $.post("reorder_positions", {id: id, instrument_id: drag_target.data("instrument-id"), instrument_order: instrument_order}, function(data,status,xhr) {
      console.log(data)
      console.log(status)
      console.log(xhr)
    })
  }

  var init = function() {
    $(".sortable-table").sortable({
        items: ".investment",
        connectWith: ".sortable-table",
        receive: function(event,ui) {
          update_list($(event.target), $(ui.item))
        }
    })
  }

  init()
}