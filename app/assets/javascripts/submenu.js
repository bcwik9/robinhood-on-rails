SubMenu = function(element) {
  var tabs = element.find("li")

  var init = function() {
    tabs.click(function(event) {
      event.preventDefault()
      tab = $(event.target)
      all_tab_content = $(".sub-menu-tab")
      all_tab_content.hide()
      tabs.removeClass("active")
      target_content = $(tab.data("target"))
      tab.parent().addClass("active")
      target_content.show()
    })
  }

  init()
}