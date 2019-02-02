PreventDeferredLoader = function(element) {
  var set_loader_state = function(loader, state) {
    loader.data("dontupdate", state)
  }

  $(".modal").on("show.bs.modal", function(event){
    set_loader_state($("#positions"), true)
    set_loader_state($(".watchlist-content"), true)
    set_loader_state($(".crypto-watchlist-content"), true)
  })

  $(".modal").on("hide.bs.modal", function(event){
    set_loader_state($("#positions"), false)
    set_loader_state($(".watchlist-content"), false)
    set_loader_state($(".crypto-watchlist-content"), false)
  })
}