FundamentalsTooltip = function(element) {
  $(".symbol").hover(function(e) {
    var target = $(e.target)
    if(!target.data("tooltip-loaded")){
      target.data("tooltip-loaded", true)
      var url = element.data("path")+ "/?symbols=" + e.target.text
      $.get(url, function(data){
        target.attr("title", data)
        target.tooltip("show")
      })
    }
  })
}