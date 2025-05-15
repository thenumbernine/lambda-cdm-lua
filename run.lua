#!/usr/bin/env luajit
--[[
some stupid equations
https://en.wikipedia.org/wiki/Lambda-CDM_model
--]]
require 'ext'

--[[
local rawget = rawget
local rawset = rawset
local env = setmetatable({}, {
	__index = _G,
	__newindex = function(env,k,v)
		print(k,v)
		rawset(env,k,v)
	end,
})
if setfenv ~= nil then
	setfenv(1, env)
else
	_ENV = env
end
--]]

-- Omega_x = rho_x (t = t_0) / rho_crit = 8 pi G rho_x (t = t_0) / (3 H_0^2), for x = 'b' for baryons, 'c' for cold dark matter, 'rad' for radiation (photons, relativistic neutrions), 'DE' or 'Lambda' for dark energy
-- sum of Omega_i = 1

-- current parameters:
-- Omega_b h^2 = .02230 +- .00014
-- Omega_c h^2 = .1188 +- .001
-- t_0 = (13.799 +- .021) * 1e+9 years
-- n_s = .9667 +- .004
-- Delta_R^2 = (2.441 + .088 - .092) * 1e+9
-- tau = .066 +- .012

-- fixed
w = -1	-- dark energy EOS
-- Sigma_m_nu = .06 eV / c^2
-- N_eff = 3.046
-- r = 0
-- dn_s/dln_k = 0

-- Calculated values:

G = 6.6740831e-11	-- m^3 / (kg s^2) = Gravitational constant

H_0 = 67.74	-- +- .46 km / (s Mpc) = Hubble constant
m_in_pc = 3.08567758149137e+16
m_in_Mpc = m_in_pc * 1e+6
m_in_km = 1000
H_0_in_inv_s = H_0 * m_in_km / m_in_Mpc
inv_H_0_in_s = 1 / H_0_in_inv_s
s_in_yr = 60 * 60 * 24 * 365.254
inv_H_0_in_yr = inv_H_0_in_s / s_in_yr

h_in_inv_s = H_0_in_inv_s / 100	-- dimensionless, reduced Hubble constant

Omega_b_t0 = .0486	-- +- .001 = Baryon density parameter
Omega_c_t0 = .2589 -- +- .0057 = dark matter density parameter
Omega_Lambda_t0 = .6911	-- +- .0062
Omega_m_t0 = .3089 -- +- .0062 = matter density .. should equal Omega_b + Omega_c ?

rho_crit = 3 * H_0_in_inv_s^2 / (8 * math.pi * G)	-- kg m^-3 = critical density = point at zero curvature
-- rho_crit = should be (8.62 +- .12) * 1e-27

-- fluctation amplitude at 8 h^-1 Mpc
sigma8 = .8159 -- +- .0086

-- redshift at decoupling
zStar = 1089.90 -- +- .23

-- age at decoupling
tStar = 377700 -- +- 3200 years

-- redshift reionization
z_re = 8.5	-- + 1 - 1.1

-- minimial 6-parameter Lambda-CDM assumes...
Omega_k = 0	-- curvature

-- radiation
Omega_rad = 1e-4

local _1 = function(x) return x end	-- in the spirit of boost ...
local D = function(x) return function() return x end end
local G = function(x) return function() return _G[x] end end

--function Omega_Lambda(t) return 8 * math.pi * G * rho_Lambda_t0 / (3 * H_0^2) end
Omega_Lambda = G'Omega_Lambda_t0'
Omega_b = G'Omega_b_t0'
Omega_c = G'Omega_c_t0'

Omega_m = Omega_b + Omega_c
Omega_tot = Omega_Lambda + Omega_b + Omega_c -- should be 1 ...

-- Friedmann equation H(a) = a' / a
-- page uses Omega_DE in the eqn, then says "Omega_Lambda works too", then proceeds to use Omega_Lambda everywhere else...
--function H(a) return H_0 * math.sqrt( (Omega_c + Omega_b) * a^-3 + Omega_rad * a^-4 + Omega_k * a^-2 + Omega_Lambda() * a^(-3*(1+w)) ) end
H = H_0 * math.sqrt:o( Omega_m * _1^-3 + Omega_rad * _1^-4 + Omega_k * _1^-2 + Omega_Lambda * _1^(-3*(1+G'w')) )
-- with w = -1 and Omega_k = 0 this becomes ...
H = H_0 * math.sqrt:o( Omega_m * _1^-3 + Omega_rad * _1^-4 + Omega_Lambda) -- = a' / a, solve for a ...

-- neglecting radiation energy and solving for H(a)
t_Lambda = 2 / (3 * H_0 * math.sqrt:o(Omega_Lambda) )

-- what happens when Omega_Lambda = 0?
a = (Omega_m / Omega_Lambda)^(1/3) * (math.sinh:o(_1/t_Lambda))^(2/3)

-- in years this should be 13.799e+9
--print('time units', 13.799e+9 / t_0)
--print('time units b', inv_H_0_in_yr * t_0)

local bisect = require 'bisect'
local matrix = require 'matrix'
--[[
local gnuplot = require 'gnuplot'
local n = 1000
local ts = matrix{n}:lambda(_1/n*2*t_0)
local as = ts:map(a)
gnuplot{
	output = 'a.png',
	style = 'data lines',
	data = {ts,as},
	{using='1:2', title='a'},
	{'1'},
}
--]]
-- [[
local ffi = require 'ffi'
local gl = require 'gl'
local ig = require 'imgui'
local ImGuiApp = require 'imgui.app'
local vec2f = require 'vec-ffi.vec2f'
local App = require 'glapp.view'.apply(ImGuiApp)
App.title = 'Lambda-CDM model'

local n = 1000
function App:initGL()
	App.super.initGL(self)

	graphVtxs = require 'gl.arraybuffer'{
		data = ffi.new('vec2f_t[?]', n),
		size = ffi.sizeof'vec2f_t' * n,
		count = n,
		dim = 2,
		mode = gl.GL_DYNAMIC_DRAW,
	}:unbind()
	graphObj = require 'gl.sceneobject'{
		program = {
			version = 'latest',
			precision = 'best',
			vertexCode = [[
in vec2 vertex;
uniform mat4 mvProjMat;
void main() {
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
			fragmentCode = [[
out vec4 fragColor;
uniform vec3 color;
void main() {
	fragColor = vec4(color, 1.);
}
]],
		},
		vertexes = graphVtxs,
		geometry = {
			mode = gl.GL_LINE_STRIP,
			count = n,
		},
	}
end

function App:update()
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)

	t_0 = bisect(0, 1, (a-1)^2, 20)
	t_a_eq_0 = bisect(0, 1, a, 20)

tmin = 0
tmax = t_0 * 3
local trange = tmax - tmin
local ts = matrix{n}:lambda(_1*tmax/n)
local as = ts:map(a)
local y_eq_1 = ts:map(D(1))

	amax = table.sup(as)
	amin = table.inf(as)
	local arange = amax - amin

	self.view.projMat:setOrtho(-.1 * trange + tmin, .1 * trange + tmax, -.1 * arange + amin, .1 * arange + amax, -1, 1)
	self.view.mvMat:setIdent()
	self.view.mvProjMat:mul4x4(self.view.projMat, self.view.mvMat)

	for _,info in ipairs{
		{buf=as, color={1,0,0}},
		{buf=y_eq_1, color={1,1,1}},
	} do

		for i=1,n do
			graphVtxs.data[i-1]:set(ts[i], info.buf[i])
		end
		graphVtxs
			:bind()
			:updateData()
			:unbind()
		graphObj.uniforms.mvProjMat = self.view.mvProjMat.ptr
		graphObj.uniforms.color = info.color
		graphObj:draw()
	end

	App.super.update(self)
end

function App:updateGUI()
	for _,field in ipairs{
		'Omega_Lambda_t0',
		'Omega_b_t0',
		'Omega_c_t0',
	} do
		ig.luatableSliderFloat(field, _G, field, 0, 1)
	end

	for _,field in ipairs{
		'tmin', 'tmax',
		'amin', 'amax',
		'Omega_tot',
		't_Lambda',
		't_0',
		't_a_eq_0',
		'H_0_in_inv_s',
		'rho_crit',
	} do
		local v = _G[field]
		if type(v) == 'function' then v = v() end
		ig.igText(field..' '..v)
	end
end
return App():run()
--]]
