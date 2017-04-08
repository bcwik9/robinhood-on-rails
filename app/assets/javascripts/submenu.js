SubMenu = function(element) {
  var tabs = element.find("li")
  var all_tab_content = $(".sub-menu-tab")

  var set_initial_state = function() {
    all_tab_content.hide()
    $(all_tab_content[0]).show()
  }

  var init = function() {
    tabs.click(function(event) {
      event.preventDefault()
      tab = $(event.target)
      all_tab_content.hide()
      tabs.removeClass("active")
      target_content = $(tab.data("target"))
      tab.parent().addClass("active")
      target_content.show()
    })

    set_initial_state()
  }

  init()
}