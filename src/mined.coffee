###
# Copyright 2011, Terrence Cole
# 
# This file is part of MIN3D.
# 
# MIN3D is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# MIN3D is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with MIN3D.  If not, see <http://www.gnu.org/licenses/>.
###

M3 = new Object()

# shim layer with setTimeout fallback
window.requestAnimFrame = (() ->
	return window.requestAnimationFrame    or
		window.webkitRequestAnimationFrame or
		window.mozRequestAnimationFrame    or 
		window.oRequestAnimationFrame      or 
		window.msRequestAnimationFrame     or 
		((callback, element) ->
			window.setTimeout(callback, 1000 / 60);
		)
)()

mined_start = ->
	window.M = new M3.Min3d


class M3.Min3d
	DATA_DIR = 'data'

	constructor: ->
		# the model-view matrix and stack
		@mMV = mat4.create();
		@sMV = []
		
		# the perspective matrix
		@mP = mat4.create();
		@sP = []

		# tracker for loaded shaders, indexed by sources
		@shaders = {}
		
		# tracker for loaded textures, indexed by source
		@textures = {}
		
		# load the viewport with gl
		@canvas = document.getElementById 'mined-canvas'
		req =
			alpha: false
			depth: true
			stencil: false
			antialias: true
			premultipliedAlpha: true
			preserveDrawingBuffer: false
		@gl = @canvas.getContext 'experimental-webgl', req
		@setupGL()

		# The one providing input to the system
		@agent = new M3.Agent this
		
		# setup our input system
		@input = new M3.Input this, @agent

		# load the skybox
		@skybox = new M3.Skybox this

		# load a world to track some state
		@world = new M3.World this

		# load the menu system
		@menu = new M3.Menu this

		# create a default game board
		@board = null
		@doStart()
		#@loadCustomLevel 2, 2, 2, 1
		#@menu.nextState 'play'

		# hook up window resize handling
		$(window).resize(@onResize)
		
		# create the debug drawing instance
		@debug = new M3.Debug(this)
		
		# time-keeping from frame drawing
		@prior = new Date().getTime()
		requestAnimFrame(@frame, @canvas)
		@frame()


	frame: () =>
		now = (new Date()).getTime()
		dt = (now - @prior) / 1000
	
		@agent.move(dt)
		@board.move(dt)
		@draw_scene()

		@prior = now
		requestAnimFrame(@frame, @canvas)
		#window.setTimeout(@frame, 500)


	checkGLError: ->
		error = @gl.getError()
		if error != @gl.NO_ERROR
			str = "GL Error: " + error
			document.body.appendChild(document.createTextNode(str))
			throw str


	draw_scene: () ->
		@gl.clear @gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT

		@mvPush()

		mat4.rotateX(@mMV, -@agent.ang[0])
		mat4.rotateY(@mMV, -@agent.ang[1])
		mat4.translate(@mMV, vec3.negate(@agent.pos, vec3.create()))

		@agent.draw()
		@skybox.draw()
		@board.draw()
		
		@mvPop()
		
		@gl.finish()
		@gl.flush()


	setupGL: ->
		# set clear color to black
		@gl.clearColor(0, 0, 0, 1)
	
		# setup depth buffer testing
		@gl.clearDepth 1
		@gl.enable @gl.DEPTH_TEST
		@gl.depthFunc @gl.LEQUAL

		# setup automatic rearward facing face culling
		@gl.enable @gl.CULL_FACE
		@gl.frontFace @gl.CCW
		@gl.cullFace @gl.BACK

		# initialize these -- then resize to set perspective correctly
		mat4.identity(@mP)
		mat4.identity(@mMV)
		@onResize()

		console.log("Supported Extensions: ", @gl.getSupportedExtensions())
		

	onResize: (e) =>
		@canvas.width = $(window).width()
		@canvas.height = $(window).height()
		@aspectRatio = @canvas.width / @canvas.height
		@gl.viewport(0, 0, @canvas.width, @canvas.height)
		# setup perspective and model-view matricies
		mat4.perspective(60, @canvas.width / @canvas.height, 0.1, 10000.0, @mP)
		

	# MODEL_VIEW glPushMatrix
	mvPush: ->
		@sMV.push(mat4.create(@mMV))
	
	
	# MODEL_VIEW glPopMatrix
	mvPop: ->
		@mMV = @sMV.pop()


	# PROJECTION glPushMatrix
	pPush: ->
		@sP.push(mat4.create(@mP))
	
	
	# PROJECTION glPopMatrix
	pPop: ->
		@mP = @sP.pop()


	###
	Enter the game start state
	###
	doStart: ->
		@menu.nextState 'start'
		@board = @world.makeStart()
		@agent.reset()

	###
	Restart the current state.
	###
	doRestart: ->
		@menu.nextState 'play'
		@board = @world.resetLevel()
		@world.positionAgentForBoard @board

	###
	Restart with the same layout, but different mines.
	###
	doNewGame: ->
		@menu.nextState 'play'
		@board = @world.makeCustomLikeCurrent()
		@world.positionAgentForBoard @board

	###
	Enter the death state.
	###
	doDeath: (minePos) ->
		@menu.nextState 'death'

	###
	Enter the win state.
	###
	doVictory: () ->
		@menu.nextState 'win'

	###
	Load a new level with the given parameters.
	###
	loadCustomLevel: (nX, nY, nZ, nMines) ->
		@board = @world.makeCustom nX, nY, nZ, nMines
		@world.positionAgentForBoard @board

	###
	Create and return a shader, unless it is already loaded, in which case we 
	return the already loaded shared of the given resources.
	###
	loadShaderFromElements: (vshader_id, fshader_id, aNames, uNames) ->
		index = vshader_id + ':' + fshader_id
		if index in @shaders
			return @shaders[index]
		shader = new M3.ShaderProgram(this, vshader_id, fshader_id, aNames, uNames)
		@shaders[ index ] = shader
		return shader


	loadShaderFromStrings: (vshader, fshader, aNames, uNames) ->
		index = vshader + ':' + fshader
		if index in @shaders
			return @shaders[index]
		shader = new M3.ShaderProgram(this, vshader, fshader, aNames, uNames, true)
		@shaders[ index ] = shader
		return shader


	loadTexture: (url) ->
		url = DATA_DIR + url
		if url in @textures
			return @textures[url]
		texture = new M3.Texture2D(this, url)
		@textures[url] = texture
		return texture


	loadCubeMap: (url, extension) ->
		url = DATA_DIR + url
		if url in @textures
			return @textures[url]
		cm = new M3.CubeMap(this, url, extension)
		@textures[url] = cm
		return cm

