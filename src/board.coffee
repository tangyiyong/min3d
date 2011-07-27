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


class M3.Board
	# Cube scale factor
	SCALE = 10.0
	
	# Block states
	STATE_NORMAL = 0
	STATE_EMPTY = 1
	STATE_FLAGGED = 2
	STATE_CAKED = 3
	
	# Block overlays
	FOCUS_NONE = 0
	FOCUS_HOVER = 1
	
	# Block content
	CONTENT_NONE = 0
	CONTENT_MINE = 1
	CONTENT_CAKE = 2


	constructor: (@M, @szX, @szY, @szZ) ->
		@size = vec3.create([@szX, @szY, @szZ])
		console.log("Board size: " + vec3.str(@size))
		@gl = @M.gl

		###
		 Each face has this form
		
		 The cube faces are arranged as
		   ____
		  / 4 /| <- 2
	3 -> +---+ |  
		 | 0 |1+       |   /
		 |___|/   x->  y  z
		   /\ 
		   5

		Side cube verts are arranged as:
		 1---3   +---5   +---7
		 | 0 | > | 1 | > | 2 | > back to 0,1 
		 0___2   +___4   +---6
		
		###
		# Note: we need per-face normals, so have to specify every vertex for 
		#	every face here, rather than doing something clever with strips.
		#   x  y  z    u  v   nx  ny  nz    tangent
		_verts = [
			# Front
			0, 0, 0,   0, 0,   0,  0,  1,
			1, 1, 0,   1, 1,   0,  0,  1,   
			1, 0, 0,   1, 0,   0,  0,  1,   
			1, 1, 0,   1, 1,   0,  0,  1,
			0, 0, 0,   0, 0,   0,  0,  1,
			0, 1, 0,   0, 1,   0,  0,  1,
			# Right
			1, 0, 0,   0, 0,   1,  0,  0,
			1, 1, 1,   1, 1,   1,  0,  0,
			1, 0, 1,   1, 0,   1,  0,  0,
			1, 1, 1,   1, 1,   1,  0,  0,
			1, 0, 0,   0, 0,   1,  0,  0,
			1, 1, 0,   0, 1,   1,  0,  0,
			# Back
			1, 0, 1,   0, 0,   0,  0, -1,
			0, 1, 1,   1, 1,   0,  0, -1,
			0, 0, 1,   1, 0,   0,  0, -1,
			0, 1, 1,   1, 1,   0,  0, -1,
			1, 0, 1,   0, 0,   0,  0, -1,
			1, 1, 1,   0, 1,   0,  0, -1,
			# Left
			0, 0, 1,   0, 0,  -1,  0,  0,
			0, 1, 0,   1, 1,  -1,  0,  0,
			0, 0, 0,   1, 0,  -1,  0,  0,
			0, 1, 0,   1, 1,  -1,  0,  0,
			0, 0, 1,   0, 0,  -1,  0,  0,
			0, 1, 1,   0, 1,  -1,  0,  0,
			# Top
			0, 1, 0,   0, 0,   0,  1,  0,
			1, 1, 1,   1, 1,   0,  1,  0,
			1, 1, 0,   1, 0,   0,  1,  0,
			1, 1, 1,   1, 1,   0,  1,  0,
			0, 1, 0,   0, 0,   0,  1,  0,
			0, 1, 1,   0, 1,   0,  1,  0,
			# Bottom
			0, 0, 1,   0, 0,   0, -1,  0,
			1, 0, 0,   1, 1,   0, -1,  0,
			1, 0, 1,   1, 0,   0, -1,  0,
			1, 0, 0,   1, 1,   0, -1,  0,
			0, 0, 1,   0, 0,   0, -1,  0,
			0, 0, 0,   0, 1,   0, -1,  0,
		]
		nElmts = 8
		@nVertsPerCube = _verts.length / nElmts

		# scale up vert positions to be SCALE sized
		for i in [0..(_verts.length / nElmts) - 1]
			for j in [0..2]
				index = i * nElmts + j
				_verts[index] = _verts[index] * SCALE
			
		# full vert and index list
		verts = []
		
		# fill the vert and index lists from the per-cube _vert and _index list
		extendCube = (n, delta) =>
			offset = 0
			for val in _verts
				if offset < 3 # position
					verts.push(val + delta[offset])
				else # textureCoord
					verts.push(val)
				offset += 1
				offset %= nElmts

		# build all verts, the index list, and the cube state list
		@cubes = []
		@nCubes = @szX * @szY * @szZ
		n = 0
		for i in [0..@szX-1]
			@cubes.push []
			for j in [0..@szY-1]
				@cubes[i].push []
				for k in [0..@szZ-1]
					pos = [i * SCALE, j * SCALE, k * SCALE]
					extendCube(n, pos)
					@cubes[i][j].push({
						state: STATE_NORMAL
						focus: FOCUS_NONE
						content: CONTENT_NONE
						aabb: new M3.AABB(pos, [pos[0] + SCALE, pos[1] + SCALE, pos[2] + SCALE])
					})
					n += 1

		# push vertex and index buffer to the card
		vertData = new Float32Array(verts);
		@vertBuf = new M3.ArrayBuffer(@M, vertData, 8 * 4, 
			[{size: 3, type: @gl.FLOAT, offset: 0, normalize: false},
			 {size: 2, type: @gl.FLOAT, offset: 12, normalize: false},
			 {size: 3, type: @gl.FLOAT, offset: 20, normalize: false}], 
			@gl.STATIC_DRAW, @gl.TRIANGLES)

		# each frame we will also need to provide the state number to the
		#	renderer, so create an array buffer for it
		@stateData = new Float32Array(verts.length / nElmts * 2)
		@stateBuf = new M3.ArrayBuffer(@M, @stateData, 8,
			[{size: 1, type: @gl.FLOAT, offset: 0, normalize: false}
			 {size: 1, type: @gl.FLOAT, offset: 4, normalize: false}],
			@gl.DYNAMIC_DRAW)

		# the board has its own local coordinate center
		@center = vec3.create([@szX * SCALE / 2, @szY * SCALE / 2, @szZ * SCALE / 2])

		# the shader to draw the cubes		
		@shader = @M.loadShaderFromStrings(VERTEX_SHADER, FRAGMENT_SHADER,
			["aVertexPosition", "aTextureCoord", "aVertexNormal", "aState", "aFocus"], 
			["uMVMatrix", "uPMatrix", "uSampler", "uNormals", "uSkymap", "uReflectivity", "uMark", "uSunDir", "uSunColor"])
		
		# load textures for the cube
		@cubeFaceTex = @M.loadTexture "/materials/cube/color-256.jpg"
		@cubeNormalTex = @M.loadTexture "/materials/cube/normal-256.png"
		@cubeReflectivityTex = @M.loadTexture "/materials/cube/reflectivity-256.png"
		@cubeMarkTex = @M.loadTexture "/materials/cube/marked-512.png"



	# Set initial states from a text representation, face on.
	initFromPlanarChars: (S) ->
		if S.length != @szZ then throw "Incorrect Z dimension initing from state vector"
		for i in [0..@szZ-1]
			if S[i].length != @szY then throw "Incorrect Y dimension initing from state vector"
			for j in [0..@szY-1]
				if S[i][@szY - j - 1].length != @szX then throw "Incorrect X dimension initing from state vector"
				for k in [0..@szX-1]
					st = switch S[i][@szY - j - 1][k]
						when "x" then STATE_NORMAL
						when " " then STATE_EMPTY
						when "m" then STATE_FLAGGED
					@cubes[k][j][i].state = st

	# Search for and apply focusing on cubes
	updateFocus: ->
		# note: transform ray by world center to get the real coordinates
		ptr = @M.agent.worldPointer
		tmp = vec3.create(ptr.pos)
		vec3.add(tmp, @center)
		ray = new M3.Ray tmp, ptr.dir

		# find cubes that intersect our pointer and update cube focus
		hits = []
		for i in [0..@szX-1]
			for j in [0..@szY-1]
				for k in [0..@szZ-1]
					@cubes[i][j][k].focus = FOCUS_NONE
					if @cubes[i][j][k].state == STATE_EMPTY
						continue
					hit = @cubes[i][j][k].aabb.intersectRay ray
					if hit > 0
						hits.push [hit, i, j, k]
		hits.sort()
		if hits.length == 0
			return
		
		@cubes[hits[0][1]][hits[0][2]][hits[0][3]].focus = FOCUS_HOVER
		
	
	# Apply cube states to the state buf and upload
	updateStateBuf: ->
		n = 0
		for i in [0..@szX-1]
			for j in [0..@szY-1]
				for k in [0..@szZ-1]
					st = @cubes[i][j][k].state
					fc = @cubes[i][j][k].focus
					for m in [0..@nVertsPerCube-1]
						@stateData[n] = st
						@stateData[n+1] = fc
						n += 2
		@stateBuf.update(@stateData)


	clear_current: () ->
		for i in [0..@szX-1]
			for j in [0..@szY-1]
				for k in [0..@szZ-1]
					if @cubes[i][j][k].focus == FOCUS_HOVER
						# don't open flagged boxes
						if @cubes[i][j][k].state == STATE_FLAGGED
							return
						@cubes[i][j][k].state = STATE_EMPTY
						return

	mark_current: () ->
		for i in [0..@szX-1]
			for j in [0..@szY-1]
				for k in [0..@szZ-1]
					if @cubes[i][j][k].focus == FOCUS_HOVER
						if @cubes[i][j][k].state == STATE_FLAGGED
							@cubes[i][j][k].state = STATE_NORMAL
						else
							@cubes[i][j][k].state = STATE_FLAGGED
						return


	move: (dt) ->
		;	

	VERTEX_SHADER = """
		attribute vec3 aVertexPosition;
		attribute vec2 aTextureCoord;
		attribute vec3 aVertexNormal;
		attribute float aState;
		attribute float aFocus;

		uniform mat4 uMVMatrix;
		uniform mat4 uPMatrix;
		uniform vec3 uSunDir;
		uniform vec4 uSunColor;
	
		varying float vState;
		varying vec4 vColor;
		varying vec2 vTextureCoord;
		varying vec3 vTLightVec;
		varying vec3 vTEyeVec;
		varying vec3 vHalfVec;

		void main(void) {
			// figure out what our object space tangent vector is, based on axis
			vec3 faceTangent;
			if(aVertexNormal.y == 0.0) // all side faces
				faceTangent = vec3(0.0, 1.0, 0.0);
			else // the top and bottom faces
				faceTangent = vec3(0.0, 0.0, 1.0);
			vec3 faceBinorm = cross(aVertexNormal, faceTangent);

			// move light vector into tangent space
			vTLightVec.x = dot(uSunDir, faceTangent);
			vTLightVec.y = dot(uSunDir, faceBinorm);
			vTLightVec.z = dot(uSunDir, aVertexNormal);
			vTLightVec = normalize(vTLightVec);
			// move eye vector into tangent space
			vec3 pos = (uMVMatrix * vec4(aVertexPosition, 1.0)).xyz;
			vTEyeVec.x = dot(pos, faceTangent);
			vTEyeVec.y = dot(pos, faceBinorm);
			vTEyeVec.z = dot(pos, aVertexNormal);
			// compute half vector between eye and light
			vec3 h = (normalize(pos) + uSunDir) / 2.0;
			vHalfVec = normalize(h);

			// transform and apply base tc
			gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
			vTextureCoord = aTextureCoord;
			vState = aState;

			// set color modifier based on state and focus status		
			if(aState == 0.0) { // normal
				vColor = vec4(1.0, 1.0, 1.0, 1.0);
			} else if(aState == 1.0) { // empty
				vColor = vec4(0.0, 0.0, 0.0, 0.0);
			} else if(aState == 2.0) { // flagged
				vColor = vec4(1.0, 0.7, 0.7, 1.0);
			} else {
				vColor = vec4(1.0, 0.0, 1.0, 1.0);
			}
		
			if(aFocus == 1.0 && aState != 2.0) {
				vColor *= vec4(0.7, 0.7, 1.0, 1.0);
			}
		}
	"""

	FRAGMENT_SHADER = """	
		#ifdef GL_ES
		precision highp float;
		#endif

		varying float vState;
		varying vec4 vColor;
		varying vec2 vTextureCoord;
		varying vec3 vTLightVec;
		varying vec3 vTEyeVec;
		varying vec3 vHalfVec;

		uniform sampler2D uSampler;
		uniform sampler2D uNormals;
		uniform sampler2D uReflectivity;
		uniform sampler2D uMark;
		uniform samplerCube uSkymap;
	
		uniform vec3 uSunDir;
		uniform vec4 uSunColor;

		void main(void) {
			// discard transparent fragments
			if(vColor.w == 0.0) discard;
		
			// lookup and compute base color
			vec4 color = texture2D(uSampler, vTextureCoord);
			color *= vColor;

			// if flagged, overlay the flag color
			if(vState >= 1.5 && vState < 2.5) { // flagged
				vec4 mark = texture2D(uMark, 1.0 - vTextureCoord);
				color = vColor * vec4(mix(color.xyz, mark.xyz, mark.w), 1.0);
			}

			// base ambient light
			gl_FragColor = vec4(0.3, 0.3, 0.3, 1.0) * color;

			// perform normal lookup and renormalization
			vec3 normal = texture2D(uNormals, vTextureCoord).xyz;
			normal = normalize(2.0 * normal - 1.0); // renormalize to [-1,1]

			// compute reflection vector
			// vTEyeVec is incident ray in tangent space for this formula
			//		R = I - 2 * N * (N dot I)
			vec3 I = -vTEyeVec;
			vec3 vReflection = I - 2.0 * normal * dot(normal, I);
		
			// lookup sky reflection position using the reflection vector
			vec4 skycolor = textureCube(uSkymap, vReflection);

			// compute diffuse lighting
			float lambertFactor = max(dot(vTLightVec, normal), 0.0);
			if(lambertFactor > 0.0) {
				gl_FragColor += vec4((color * uSunColor * lambertFactor).xyz, 1.0);

				//vec4 mSpecular = vec4(1.0);
				//vec4 lSpecular = vec4(1.0);
				//gl_FragColor += mSpecular * lSpecular * shininess;
				float shininess = pow(max(dot(vHalfVec, normal), 0.0), 2.0);
			}
		
			// mix in the background reflection
			gl_FragColor += skycolor * texture2D(uReflectivity, vTextureCoord) / 2.25;

		}
	"""
	# /*
	

	draw: ->
		@updateFocus()
		@updateStateBuf()

		@gl.enable(@gl.BLEND)
		@gl.blendFunc(@gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA)
		
		@M.mvPush()
		mat4.translate(@M.mMV, vec3.negate(vec3.create(@center)))
		
		## CUBE
		@shader.use()
		@vertBuf.bind()
		@shader.linkAttribute('aVertexPosition', @vertBuf, 0)
		@shader.linkAttribute('aTextureCoord', @vertBuf, 1)
		@shader.linkAttribute('aVertexNormal', @vertBuf, 2)
		@stateBuf.bind()
		@shader.linkAttribute('aState', @stateBuf, 0)
		@shader.linkAttribute('aFocus', @stateBuf, 1)
		@shader.linkUniformMatrix('uPMatrix', @M.mP)
		@shader.linkUniformMatrix('uMVMatrix', @M.mMV)
		@shader.linkUniformVec3('uSunDir', @M.skybox.sunDir)
		@shader.linkUniformVec4('uSunColor', @M.skybox.sunColor)

		@cubeFaceTex.bind(0)
		@shader.linkSampler('uSampler', @cubeFaceTex)

		@cubeNormalTex.bind(1)
		@shader.linkSampler('uNormals', @cubeNormalTex)

		@cubeReflectivityTex.bind(2)
		@shader.linkSampler('uReflectivity', @cubeReflectivityTex)

		@M.skybox.cubeMap.bind(3)
		@shader.linkSampler('uSkymap', @M.skybox.cubeMap)

		@cubeMarkTex.bind(4)
		@shader.linkSampler('uMark', @cubeMarkTex)

		@vertBuf.draw()
		
		@cubeFaceTex.unbind()
		@cubeNormalTex.unbind()
		@shader.unuse()
		
		@gl.disable(@gl.BLEND)

		@M.mvPop()


		## ## DEBUG
		#@M.debug.drawRay @M.agent.worldPointer, 500
		#return
		## ## END DEBUG




