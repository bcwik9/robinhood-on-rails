DeferredLoader = function(element) {
  if(element.html() == "") {
    $.get(element.data("path"), function(data) {
      element.html(data)
    })
  }
}