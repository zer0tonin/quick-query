{ScrollView, $} = require 'atom-space-pen-views'

module.exports =
class QuickQueryResultView extends ScrollView

  constructor:  ()->
    atom.commands.add '.quick-query-result', 'quick-query:copy': => @copy()
    super

  initialize: ->
    $(window).resize =>
      @fixSizes()
    @handleResizeEvents()
  # Returns an object that can be retrieved when package is activated
  getTitle: ->
    return 'Query Result'
  serialize: ->

  @content: ->
    @div class: 'quick-query-result' , =>
      @div class: 'quick-query-result-resize-handler', ''
      @table class: 'table quick-query-result-numbers', =>
        @thead => (@tr => @th '#')
        @tbody outlet: 'numbers', ''
      @table class: 'table', outlet: 'table' , ''

  # Tear down any state and detach
  destroy: ->
    # @element.remove()

  showRows: (rows, fields)->
    if atom.config.get('quick-query.resultsInTab')
      @find('.quick-query-result-resize-handler').hide()
    $thead = $('<thead/>')
    $tr = $('<tr/>')
    for field in fields
      $th = $('<th/>')
      $th.text(field.name)
      $tr.append($th)
    $thead.html($tr)
    @table.html($thead)
    $tbody = $('<tbody/>')
    for row,i in rows
      $tr = $('<tr/>')
      $td = $('<td/>')
      $td.text(i+1)
      @numbers.append($('<tr/>').html($td))
      for field in fields
        $td = $('<td/>')
        $td.text(row[field.name])
        $td.mousedown (e)->
          $(this).closest('table').find('td').removeClass('selected')
          $(this).addClass('selected')
        $tr.append($td)
      $tbody.append($tr)
    @table.append($tbody)

    @table.find('tbody').scroll (e) =>
      scroll = $(e.target).scrollTop() - 33 #hardcoded!
      @numbers.css 'margin-top': (-1*scroll)
  copy: ->
    $td = @find('td.selected')
    if $td.length == 1
      atom.clipboard.write($td.text())

  fixSizes: ->
    if @table.find('tbody tr').length > 0
      tds = @table.find('tbody tr:first').children()
      @table.find('thead tr').children().each (i, th) =>
        td = tds[i]
        thw = $(th).outerWidth()
        tdw = $(td).outerWidth()
        w = Math.max(tdw,thw)
        $(td).css('min-width',w+"px")
        $(th).css('min-width',w+"px")

  handleResizeEvents: ->
    @on 'mousedown', '.quick-query-result-resize-handler', (e) => @resizeStarted(e)
  resizeStarted: ->
    $(document).on('mousemove', @resizeResultView)
    $(document).on('mouseup', @resizeStopped)
  resizeStopped: ->
    $(document).off('mousemove', @resizeResultView)
    $(document).off('mouseup', @resizeStopped)
  resizeResultView: ({pageY, which}) =>
    return @resizeStopped() unless which is 1
    height = @outerHeight() + @offset().top - pageY
    @height(height)
