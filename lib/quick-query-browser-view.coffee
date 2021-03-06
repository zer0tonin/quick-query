{ScrollView, $} = require 'atom-space-pen-views'

module.exports =
class QuickQueryBrowserView extends ScrollView

  editor: null
  connection: null
  connections: []
  selectedConnection: null

  constructor: ->
    atom.commands.add '#quick-query-connections',
      'quick-query:select-1000': => @simpleSelect()
      'quick-query:alter': => @alter()
      'quick-query:drop': => @drop()
      'quick-query:create': => @create()
      'quick-query:copy': => @copy()
      'quick-query:set-default': => @setDefault()
      'core:delete': => @delete()

    super

  initialize: ->
    @find('#quick-query-new-connection').click (e) =>
      workspaceElement = atom.views.getView(atom.workspace)
      atom.commands.dispatch(workspaceElement, 'quick-query:new-connection')
    @find('#quick-query-run').click (e) =>
      workspaceElement = atom.views.getView(atom.workspace)
      atom.commands.dispatch(workspaceElement, 'quick-query:run')
    @find('#quick-query-connections').blur (e) =>
      $tree = $(e.currentTarget)
      $li = $tree.find('li.selected')
      $li.removeClass('selected')
    @handleResizeEvents()
  # Returns an object that can be retrieved when package is activated
  getTitle: ->
    return 'Query Result'
  serialize: ->

  @content: ->
    @div class: 'quick-query-browser tree-view-resizer tool-panel', 'data-show-on-right-side': !atom.config.get('quick-query.showBrowserOnLeftSide') , =>
      @div =>
        @button id: 'quick-query-run', class: 'btn icon icon-playback-play' , title: 'Run' , style: 'width:50%'
        @button id: 'quick-query-new-connection', class: 'btn icon icon-plus' , title: 'New connection' , style: 'width:50%'
      @div class: 'tree-view-scroller', outlet: 'scroller', =>
        @ol id:'quick-query-connections' , class: 'tree-view list-tree has-collapsable-children focusable-panel', tabindex: -1, outlet: 'list'
      @div class: 'tree-view-resize-handle', outlet: 'resizeHandle'


  # Tear down any state and detach
  destroy: ->
    @element.remove()

  delete: ->
    connection = null
    $li = @find('ol:focus li.quick-query-connection.selected')
    if $li.length == 1
      connection = $li.data('item')
      i = @connections.indexOf(connection)
      @connections.splice(i,1)
      @showConnections()
      @trigger('quickQuery.connectionDeleted',[connection])

  setDefault: ->
    $li = @find('li.selected')
    unless $li.hasClass('default')
      model = $li.data('item')
      model.connection.setDefaultDatabase model.name

  addConnection: (connectionPromise) ->
    connectionPromise.then (connection)=>
      @selectedConnection = connection
      @connections.push(connection)
      @trigger('quickQuery.connectionSelected',[connection])
      @showConnections()
      connection.onDidChangeDefaultDatabase (database) =>
        @defaultDatabaseChanged(connection,database)

  defaultDatabaseChanged: (connection,database)->
    @find('ol#quick-query-connections').children().each (i,e)->
      if $(e).data('item') == connection
        $(e).find(".quick-query-database").removeClass('default')
        $(e).find(".quick-query-database[data-name=\"#{database}\"]").addClass('default')

  showConnections: ()->
    $ol = @find('ol#quick-query-connections')
    $ol.empty()
    for connection in @connections
        $li = $('<li/>').addClass('entry list-nested-item collapsed')
        $div = $('<div/>').addClass('header list-item')
        $icon = $('<span/>').addClass('icon')
        $li.attr('data-protocol',connection.protocol)
        if connection == @selectedConnection
          $li.addClass('default')
        $div.mousedown (e) =>
          $li = $(e.currentTarget).parent()
          $li.parent().find('li').removeClass('selected')
          $li.addClass('selected')
          $li.parent().find('li').removeClass('default')
          $li.addClass('default')
          @expandConnection($li) if e.which != 3
        $div.text(connection)
        $div.prepend($icon)
        $li.data('item',connection)
        $li.html($div)
        @setItemClasses(connection,$li)
        $ol.append($li)

  expandConnection: ($li,callback)->
    connection = $li.data('item')
    if connection != @selectedConnection
      @selectedConnection = connection
      @trigger('quickQuery.connectionSelected',[connection])
    $li.toggleClass('collapsed expanded')
    if $li.hasClass("expanded")
      connection.getDatabases (databases,err) =>
        unless err
          @showItems(connection,databases,$li)
          callback() if callback

  showItems: (parentItem,childrenItems,$e)->
    ol_class = switch parentItem.child_type
      when 'database'
        "quick-query-databases"
      when 'schema'
        "quick-query-schemas"
      when 'table'
        "quick-query-tables"
      when 'column'
        "quick-query-columns"
    $ol = $e.find("ol.#{ol_class}")
    if $ol.length == 0
      $ol = $('<ol/>').addClass('list-tree entries')
      if parentItem.child_type != 'column'
        $ol.addClass("has-collapsable-children")
      $ol.addClass(ol_class)
      $e.append($ol)
    else
      $ol.empty()
    if parentItem.child_type != 'column'
      childrenItems = childrenItems.sort(@compareItemName)
    for childItem in childrenItems
      $li = $('<li/>').addClass('entry')
      $div = $('<div/>').addClass('header list-item')
      $icon = $('<span/>').addClass('icon')
      if childItem.type != 'column'
        $li.addClass('list-nested-item collapsed')
      if childItem.type == 'database' && childItem.name == @selectedConnection.getDefaultDatabase()
        $li.addClass('default')
      $div.mousedown (e) =>
        $li = $(e.currentTarget).parent()
        $li.closest('ol#quick-query-connections').find('li').removeClass('selected')
        $li.addClass('selected')
        @expandItem($li) if e.which != 3
      $div.text(childItem)
      $div.prepend($icon)
      $li.attr('data-name',childItem.name)
      $li.data('item',childItem)
      $li.html($div)
      @setItemClasses(childItem,$li)
      $ol.append($li)

  setItemClasses: (item,$li)->
    $div = $li.children('.header')
    $icon = $div.children('.icon')
    switch item.type
      when 'connection'
        $li.addClass('quick-query-connection')
        $div.addClass("qq-connection-item")
        $icon.addClass('icon-plug')
      when 'database'
        $li.addClass('quick-query-database')
        $div.addClass("qq-database-item")
        $icon.addClass('icon-database')
      when 'schema'
        $li.addClass('quick-query-schema')
        $div.addClass("qq-schema-item")
        $icon.addClass('icon-book')
      when 'table'
        $li.addClass('quick-query-table')
        $div.addClass("qq-table-item")
        $icon.addClass('icon-browser')
      when 'column'
        $li.addClass('quick-query-column')
        $div.addClass("qq-column-item")
        if item.primary_key
          $icon.addClass('icon-key')
        else
          $icon.addClass('icon-tag')

  expandItem: ($li,callback) ->
    $li.toggleClass('collapsed expanded')
    if $li.hasClass("expanded")
      model = $li.data('item')
      model.children (children) =>
        @showItems(model,children,$li)
        callback(children) if callback

  refreshTree: (model)->
    $li = switch model.type
      when 'connection'
        @find('li.quick-query-connection').filter (i,e)->
          $(e).data('item') == model
      when 'database'
        @find('li.quick-query-connection').filter (i,e)->
          $(e).data('item') == model.parent()
      when 'table'
        @find('li.quick-query-database').filter (i,e)->
          $(e).data('item') == model.parent()
      when 'column'
        @find('li.quick-query-table').filter (i,e)->
          $(e).data('item') == model.parent()
    $li.removeClass('collapsed')
    $li.addClass('expanded')
    $li.find('ol').empty();
    model.parent().children (children) =>
      @showItems(model.parent(),children,$li)

  expand: (model,callback)->
    if model.type == 'connection'
      $ol = @find('ol#quick-query-connections')
      $ol.children().each (i,li) =>
        if $(li).data('item') == model
          $(li).removeClass('expanded').addClass('collapsed') #HACK?
          @expandConnection $(li) , =>
            callback($(li)) if callback
    else
      parent = model.parent()
      @expand parent, ($li) =>
        $ol = $li.children("ol")
        $ol.children().each (i,li) =>
          item = $(li).data('item')
          if item && item.name == model.name && item.type == model.type
            @expandItem $(li) , =>
              callback($(li)) if callback

  reveal: (model,callback) ->
    @expand model, ($li) =>
      $li.addClass('selected')
      top = $li.position().top
      bottom = top + $li.outerHeight()
      if bottom > @scroller.scrollBottom()
        @scroller.scrollBottom(bottom)
      if top < @scroller.scrollTop()
        @scroller.scrollTop(top)
      callback() if callback

  compareItemName: (item1,item2)->
    if (item1.name < item2.name)
      return -1
    else if (item1.name > item2.name)
      return 1
    else
      return 0

  simpleSelect: ->
    $li = @find('li.selected.quick-query-table')
    if $li.length > 0
      model = $li.data('item')
      model.connection.getColumns model ,(columns) =>
        text = model.connection.simpleSelect(model,columns)
        atom.workspace.open().then (editor) =>
          grammars = atom.grammars.getGrammars()
          grammar = (i for i in grammars when i.name is 'SQL')[0]
          editor.setGrammar(grammar)
          editor.insertText(text)

  copy: ->
    $li = @find('li.selected')
    $header = $li.children('div.header')
    if $header.length > 0
      atom.clipboard.write($header.text())

  create: ->
    $li = @find('li.selected')
    if $li.length > 0
      model = $li.data('item')
      @trigger('quickQuery.edit',['create',model])


  alter: ->
    $li = @find('li.selected')
    if $li.length > 0
      model = $li.data('item')
      @trigger('quickQuery.edit',['alter',model])

  drop: ->
    $li = @find('li.selected')
    if $li.length > 0
      model = $li.data('item')
      @trigger('quickQuery.edit',['drop',model])

  selectConnection: (connection)->
    return unless connection != @selectedConnection
    $ol = @find('ol#quick-query-connections')
    $ol.children().each (i,li) =>
      if $(li).data('item') == connection
        $ol.children().removeClass('default')
        $(li).addClass('default')
        @selectedConnection = connection
        @trigger('quickQuery.connectionSelected',[connection])

  #events
  onConnectionSelected: (callback)->
    @bind 'quickQuery.connectionSelected', (e,connection) =>
      callback(connection)

  onConnectionDeleted: (callback)->
    @bind 'quickQuery.connectionDeleted', (e,connection) =>
      callback(connection)

  #resizing methods copied from tree-view
  handleResizeEvents: ->
    @on 'dblclick', '.tree-view-resize-handle',  (e) => @resizeToFitContent()
    @on 'mousedown', '.tree-view-resize-handle', (e) => @resizeStarted(e)
  resizeStarted: =>
    $(document).on('mousemove', @resizeTreeView)
    $(document).on('mouseup', @resizeStopped)
  resizeStopped: =>
    $(document).off('mousemove', @resizeTreeView)
    $(document).off('mouseup', @resizeStopped)
  resizeTreeView: ({pageX, which}) =>
    return @resizeStopped() unless which is 1
    if @data('show-on-right-side')
      width =  @outerWidth() + @offset().left - pageX
    else
      width = pageX - @offset().left
    @width(width)
  resizeToFitContent: ->
    @width(1) # Shrink to measure the minimum width of list
    @width(@list.outerWidth())
