
class Constants
  @width = window.innerWidth
  @height = window.innerHeight
  @defaultRootSize = 100
  @defaultNodeSize = 10
  @requiredNodesToMerge = 5

  @colors =
    meteor:
      start: '#fff'
      end: '#666'
    earthy:
      start: '#0f0'
      end: '#310c0c'
    sun:
      start: '#a00'
      end: '#fa0'
    watery:
      start: '#007fff'
      end: '#006'

svg = null
svgContainer = null
force = null
id = 0

nodeTree =
  y: Constants.height / 2
  x: Constants.width / 2
  size: Constants.defaultRootSize
  type: "sun"
  fixed: yes
  auto: no
  children: []

numInRange = (min, max) ->
  Math.random() * (max-min) + min

addChildTo = (parent, size = 1, type = "meteor") ->
  parent.children.push newNode parent, size, type

newNode = (parent = {x: Math.random()*Constants.width, y: Math.random*Constants.height}, size = 1, type = "meteor") ->

  type: type
  children: []
  size: size
  id: ++id
  x: numInRange parent.x-50, parent.x+50
  y: numInRange parent.y-50, parent.y+50
  auto: if type is "watery" then yes else no

roots = [nodeTree]
orphaned = []

getAllRootNodes = ->
  roots.concat orphaned

allLinks = -> svgContainer.selectAll '.link'
allNodes = -> svgContainer.selectAll '.node'

tickCounter = 0

tick = ->
  allLinks()
    .attr "x1", (d) -> d.source.x
    .attr "y1", (d) -> d.source.y
    .attr "x2", (d) -> d.target.x
    .attr "y2", (d) -> d.target.y

  allNodes()
    .attr "transform", (d) -> "translate(#{d.x},#{d.y})"

  if tickCounter++ > 100
    tickCounter = 0

    nodes = flattenNodes()
    _.each (_.filter nodes, (node) -> node.auto), (node) -> generateChildFor node

loadForce = ->
  force = d3.layout.force()
    .linkDistance 150
    .charge (d) -> if d.type is "sun" then -1000 else -150
    .chargeDistance 500
    .gravity 0.03
    .friction 0.9
    .linkStrength 0.7
    .size [Constants.width, Constants.height]
    .on "tick", tick

flattenNodes = ->
  nodes = []

  recurse = (node) ->
    nodes.push node
    node.id = ++id if not node.id
    _.each node.children, recurse if node.children

  _.each getAllRootNodes(), recurse

  nodes

severLinksFor = (node) ->
  orphaned.push child for child in node.children

generateChildFor = (node) ->
  addChildTo node

  tryToMergeChildren node

  if node.type is "sun"
    node.size--

    if node.size is 0
      roots = _.without roots, node
      severLinksFor node

  gameUpdate()

nodeClick = (node) ->
  return if node.size is 0 or node.type in ['meteor']
  generateChildFor node

nodeValue = (node) ->
  return node.size if node.children.length is 0
  node.size + _.reduce node.children, ((prev, node) -> prev+nodeValue node), 0

tryToMergeChildren = (parent) ->

  #TODO start from the lower tier and try to merge, if not, then try to do all of the other ones, sequentually
  for i in [0...3]
    counted = _.groupBy parent.children, (node) -> node.type
    for type, nodes of counted
      continue if nodes.length < Constants.requiredNodesToMerge
      parent.children = _.without parent.children, nodes...
      totalValue = _.reduce nodes, ((prev, node) -> prev+nodeValue node), 0

      nextType = nextNodeType type
      if nextType is "sun"
        roots.push newNode null, totalValue, nextType
      else
        addChildTo parent, totalValue, nextType

nextNodeType = (type) ->
  switch type
    when "meteor" then return "watery"
    when "watery" then return "earthy"
    when "earthy" then return "sun"

gameUpdate = ->
  nodes = flattenNodes()

  links = d3.layout.tree().links nodes

  force
    .nodes nodes
    .links links
    .start()

  svg.select "defs"
    .selectAll "*"
    .remove()

  gradients = svg.select "defs"
    .selectAll "radialGradient"
    .data nodes
    .enter()
    .append "radialGradient"
    .attr "gradientUnits", "objectBoundingBox"
    .attr "cx", 0
    .attr "cy", 0
    .attr "r", "100%"
    .attr "id", (d) -> "gradient-#{d.id}"

  gradients.append "stop"
    .attr "offset", "0%"
    .style "stop-color", (d) -> Constants.colors[d.type].start

  gradients.append "stop"
    .attr "offset", "100%"
    .style "stop-color", (d) -> Constants.colors[d.type].end

  links = allLinks().data links, (d) -> d.target.id
  links.exit().remove()
  links.enter()
    .insert "line", ".node"
    .attr "class", "link"

  nodes = allNodes().data nodes, (d) -> d.id
  nodes.exit().remove()

  nodeSize = (d) -> Math.max Constants.defaultNodeSize, d.size
  nodeText = (d) -> d.size

  enteredNodes = nodes
    .enter()
    .append "g"
    .attr "class", "node"
    .on "click", nodeClick
    .call force.drag

  enteredNodes
    .append "circle"
    .attr "r", nodeSize

  enteredNodes
    .append "text"
    .attr "dy", ".35em"
    .attr "fill", "#fff"
    .attr "text-anchor", "middle"
    .text nodeText

  nodes
    .select "circle"
    .style "fill", (d) -> "url(#gradient-#{d.id})"
    .attr "r", nodeSize

  nodes
    .select "text"
    .text nodeText

startGame = ->
  gameUpdate()

loadPage = ->

  zoomFunc = ->
    svgContainer.attr "transform", "scale(#{d3.event.scale})"

  zoomBehavior = d3.behavior.zoom()
    .scaleExtent [0, 10]
    .on "zoom", zoomFunc

  svg = d3
    .select 'body'
    .append 'svg'
    .attr "width", Constants.width
    .attr "height", Constants.height
    .attr "viewBox", "0 0 #{Constants.width} #{Constants.height}"
    .attr "preserveAspectRatio", "xMidYMid meet"
    .attr "pointer-events", "all"

  svgContainer = svg
    .append 'g'
    .call zoomBehavior
    .on "dblclick.zoom", null

  svg.append 'defs'

addWindowWatcher = ->
  d3
    .select window
    .on "resize", ->
      svg
        .attr "width", window.innerWidth
        .attr "height", window.innerHeight

do loadPage
do loadForce
do addWindowWatcher
do startGame