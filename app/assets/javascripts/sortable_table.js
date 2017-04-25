SortableTables = function(element) {

  var init = function() {
    $(".sortable-table").sortable({
        items: "tr",
        update: function(event,ui) {
          $.post("reorder_positions", {}, function(data,status,xhr) {
            console.log(data)
            console.log(status)
            console.log(xhr)
          })
        }
    })
  }

  init()
}