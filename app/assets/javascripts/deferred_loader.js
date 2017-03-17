DeferredLoader = function(element) {

  var update_content = function() {
    $.get(element.data("path"), function(data) {
      element.html(data);
    })
  }

  if(element.html() == "" && !element.data("loaded")) {
    element.data("loaded", true);
    update_content();
    if(element.data("refresh")){
      setInterval(function(){ update_content(); }, element.data("refresh")*1000);
    }
  }
}