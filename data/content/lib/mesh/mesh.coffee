mesh = angular.module('Mesh', ['ui'])

mesh.value 'ui.config',
  codemirror:
    mode: 'text/javascript'
    theme: 'monoguy'
    lineNumbers: true
    matchBrackets: true

mesh.directive 'ngEnter', () ->
  return (scope, element, attrs) ->
    element.bind "keypress", (event) ->
      if event.which is 13
        scope.$apply(attrs.ngEnter)

mesh.factory 'editor', ($window) ->
  editor = {}

  editor.open = (file, handler) ->
    mimetype = $window.app.mime.lookup(file)
    $window.app.fs.readFile file, {encoding: 'utf8'}, (err, data) ->
      if err then throw(err)
      handler
        mime: mimetype
        path: file
        content: data.toString('utf8')

  editor

mesh.controller 'FileManagerController', ['$scope', 'shell', 'editor', ($scope, shell, editor) ->
  $scope.shell = shell
  $scope.editor = editor
  $scope.grid = [[[],[]],[[],[]]]
  $scope.editors = {}
  $scope.focused_row = 0
  $scope.focused_col = 0

  $scope.$on 'edit_file', (event, path, row, col) ->
    console.log path, row, col
    # test if file is open
    if $scope.editors[path]
      # focus the edit pane?
      console.log "FileManagerController file already open!!!"
    else
      $scope.focused_row = row
      $scope.focused_col = col
      $scope.editor.open path, (file_proxy) ->
        $scope.$apply ->
          cell = $scope.grid[$scope.focused_row][$scope.focused_col]
          cell.push file_proxy
          $scope.editors[path] = {row: $scope.focused_row, col: $scope.focused_col}
          console.log "FileManagerController apply file open", file_proxy
  ]

mesh.factory 'shell', ($window) ->
  shell = {}
  externals =
    cd: true
    ls: true
    cwd: true
    pwd: true
    test: true

  peruse = (query) ->
    path = $window.app.shell.pwd()
    out = $window.app.shell.find(path).filter (file) -> file.match RegExp(query)
    if e = $window.app.shell.error()
      {code: 1, output: [e]}
    else
      {code: 0, output: out, openable: true}

  open_project = (path) ->
    res = $window.app.shell.cd(path)
    e = $window.app.shell.error()
    if e is null
      {code: 0, output: ["project opened"]}
    else
      {code: 1, output: [e]}

  clear_history = () ->
    {code: 255, output: []}

  internals =
    p: peruse
    ch: clear_history
    op: open_project

  direct_exec = (callable, params) ->
    result = callable(params)
    if typeof result is 'string'
      result = Array(result)
    e = $window.app.shell.error()
    if e is null
      {code: 0, output: result}
    else
      {code: 1, output: [e]}

  shell.raw = () ->
    $window.app.shell

  shell.exec = (command, handler) ->
    return false if command.length is 0
    parts = command.split /\s+/
    cmd = parts.shift()
    params = parts.join(' ')
    callable = internals[cmd] or externals[cmd]
    if angular.isFunction callable
      handler callable(params)

    else if callable
      callable = $window.app.shell[cmd]
      handler direct_exec(callable, params)

    else
      child = $window.app.shell.exec command,  async: true
      on_data = (data) ->
        str = data.toString()
        arr = str.split(/\r?\n/)
        handler {code: 0, output: arr}
        
      child.stdout.on 'data', on_data
      child.stderr.on 'data', on_data

  shell

mesh.controller 'ShellController', ['$scope', 'shell', ($scope, shell) ->
  $scope.shell = shell
  $scope.history = []
  $scope.current = null
  $scope.command = ''
  $scope.cwd = ''

  $scope.open_file = (event) ->
    path = event.target.innerText
    return false if not Boolean($scope.current.openable)
    return false if $scope.shell.raw().test('-d', path)
    console.log "ShellController shell.open_file path", path, event
    
    col = Number(event.ctrlKey)
    row = Number(event.shiftKey)
    $scope.$parent.$broadcast "edit_file", path, row, col

  $scope.process_cmd = ->
    cmd = "" + $scope.command
    $scope.shell.exec cmd, (result) ->
      switch result.code
        when 255
          $scope.command = ''
          $scope.history = []
          $scope.current = {}
        when 0
          $scope.command = ''
          $scope.history.push $scope.current
          if cmd is "pwd"
            $scope.cwd = result.output[0]
          $scope.current =
            request: cmd
            response: result.output
            openable: result.openable
  ]
