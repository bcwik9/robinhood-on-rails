DeferredLoader = function(element) {

  var update_content = function() {
    if(!element.data("dontupdate")){
      $.get(element.data("path"), function(data) {
        target = element.data("target")
        if(target){
          target = $(target)
        } else {
          target = element
        }
        target.html(data);
        Elemental.load(target.html())
      })
    }
  }

  trigger = element.data("trigger")
  if(element.html() == "" && !element.data("loaded")) {
    element.data("loaded", true);
    if(!trigger){ update_content(); }

    if(element.data("refresh")){
      setInterval(function(){ update_content(); }, element.data("refresh")*1000);
    }
  }

  if(trigger){
    if(trigger === "click"){
      element.click(function(event){
        update_content();
      })
    }
  }
}