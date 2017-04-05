LineChart = function(e) {
  var chart_data = e.data("chart")

  google.charts.load('current', {packages: ['corechart', 'line']});
  google.charts.setOnLoadCallback(drawCurveTypes);

  function drawCurveTypes() {
      var data = new google.visualization.DataTable();

      $.each(chart_data.columns, function(index, column) {
        if(column.role == "tooltip") {
          data.addColumn(column.data)
        } else {
          data.addColumn(column.data[0], column.data[1]);
        }
      })

      data.addRows(chart_data.rows);

      var chart = new google.visualization.LineChart(e[0]);
      chart.draw(data, chart_data.options);
    }
}