{parser} = require('./parser')
{lexer} = require('../build/lexer')
{renderJST, util} = require('./renderer')
styl = require('styl')

require('./runtime')

parser.lexer = lexer

window.parser = parser
window.render = renderJST

# TODO: Load tempest.js for observable
window.Observable = (value) ->
  listeners = []

  notify = (newValue) ->
    listeners.each (listener) ->
      listener(newValue)

  self = (newValue) ->
    if arguments.length > 0
      if value != newValue
        value = newValue

        notify(newValue)

    return value

  # TODO: If value is array hook into array modification events
  # to keep things up to date

  # TODO: If value is a function compute dependencies and listen
  # to observables that it depends on

  Object.extend self,
    observe: (listener) ->
      listeners.push listener
    each: (args...) ->
      # Don't add null or undefined values to iteration
      if value?
        [value].each(args...)

  return self

# Promote or "lift" an entity into a dummy object that
# matches the observable interface
Observable.lift = (object) ->
  if typeof object.observe is "function"
    object
  else
    value = object

    # Return a dummy observable
    dummy = (newValue) ->
      if arguments.length > 0
        value = newValue
      else
        value

    # No-op
    dummy.observe = ->

    dummy.each = (args...) ->
      if value?
        [value].forEach(args...)

    return dummy

rerender = ->
  if location.search.match("embed")
    selector = "body"
  else
    selector = "#preview"

  # HACK for embedded
  return unless $("#template").length

  # TODO: Better error reporting
  ast = parser.parse($("#template").val())

  template = Function("return " + render(ast, compiler: CoffeeScript))()

  data = Function("return " + CoffeeScript.compile("do ->\n" + util.indent($("#data").val()), bare: true))()

  style = styl($("#style").val(), whitespace: true).toString()

  $(selector)
    .empty()
    .append(template(data))
    .append("<style>#{style}</style>")

# TODO: Remote sample repos
save = ->
  data = $("#data").val()
  template = $("#template").val()
  style = $("#style").val()

  postData = JSON.stringify(
    public: true
    files:
      data:
        content: data
      template:
        content: template
      style:
        content: style
  )

  $.ajax "https://api.github.com/gists",
    type: "POST"
    dataType: 'json'
    data: postData
    success: (data) ->
      location.hash = data.id

load = (id) ->
  $.getJSON "https://api.github.com/gists/#{id}", (data) ->
    ["data", "style", "template"].each (file) ->
      $("##{file}").val(data.files[file]?.content || "")

    rerender()

$ ->
  if id = location.hash
    load(id.substring(1))
  else
    rerender()

  $("#template, #data, #style").on "change", rerender

  $("#actions .save").on "click", save
