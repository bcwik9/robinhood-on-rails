FundamentalsTooltip = function(element) {

  var hide_all = function() {
    $(".symbol").tooltip("hide")
  }

  $(".symbol").hover(function(e) {
    var target = $(e.target)
    if(!target.data("tooltip-loaded")){
      target.data("tooltip-loaded", true)
      var url = "fundamentals/?symbols=" + e.target.text
      $.get(url, function(data){
        target.attr("title", data)
        target.tooltip("show")
        Elemental.load(target.siblings(".tooltip"))
      })
    }
    hide_all()
  })

  $(document).click(function() {
    hide_all()
  })
}