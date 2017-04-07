FundamentalsTooltip = function(element) {

  var symbols = $(".symbol")

  var hide_all = function() {
    symbols.tooltip("hide")
  }


  var init = function() {
    symbols.on("shown.bs.tooltip", function(e) {
      Elemental.load($(e.target).siblings(".tooltip"))
    })

    symbols.hover(function(e) {
      hide_all()
      var target = $(e.target)
      if(!target.data("tooltip-loaded")){
        target.data("tooltip-loaded", true)
        var url = "fundamentals/?symbols=" + e.target.text
        $.get(url, function(data){
          target.attr("title", data)
          target.tooltip("show")
        })
      }
    })

    $(document).click(function() {
      hide_all()
    })
  }

  init()
}