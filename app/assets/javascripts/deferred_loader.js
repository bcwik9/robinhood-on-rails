DeferredLoader = function(element) {
  if(element.html() == "" && !element.data("loaded")) {
    element.data("loaded", true)
    $.get(element.data("path"), function(data) {
      element.html(data)
    })
  }
}