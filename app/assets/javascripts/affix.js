$(function() {
  $(".affix").affix()
  $(document).on("affixed-top.bs.affix", function(event) {
    $(".side-menu").removeClass("affix-top")
    $(".side-menu").addClass("affix")
  })
  $(".side-menu").removeClass("affix-top")
  $(".side-menu").addClass("affix")
})