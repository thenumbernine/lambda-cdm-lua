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

--function Omega_Lambda(t) return 8 * math.pi * G * rho_Lambda_t0 / (3 * H_0^2) end
Omega_Lambda = Omega_Lambda_t0
Omega_b = Omega_b_t0
Omega_c = Omega_c_t0
function Omega_m() return Omega_b + Omega_c end

function Omega_tot() return Omega_Lambda + Omega_b + Omega_c end -- should be 1 ...

-- Friedmann equation H(a) = a' / a
-- page uses Omega_DE in the eqn, then says "Omega_Lambda works too", then proceeds to use Omega_Lambda everywhere else...
function H(a) return H_0 * math.sqrt( (Omega_c + Omega_b) * a^-3 + Omega_rad * a^-4 + Omega_k * a^-2 + Omega_Lambda * a^(-3*(1+w)) ) end

-- neglecting radiation energy and solving for H(a)
function t_Lambda() return 2 / (3 * H_0 * math.sqrt(Omega_Lambda)) end

function a(t) 
	return (Omega_m() / Omega_Lambda)^(1/3) * (math.sinh(t/t_Lambda()))^(2/3) 
end


-- in years this should be 13.799e+9
--print('time units', 13.799e+9 / t_0)
--print('time units b', inv_H_0_in_yr * t_0)

local bisect = require 'bisect'
local matrix = require 'matrix'
--[[
local gnuplot = require 'gnuplot'
local n = 1000
local ts = matrix{n}:lambda(function(i) return i/n*2*t_0 end)
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
local ImGuiApp = require 'imguiapp'
local gl = require 'ffi.OpenGL'
local ig = require 'ffi.imgui'
local App = class(ImGuiApp)
function App:update()
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glLoadIdentity()

	t_0 = bisect(0, 1, (a-1)^2, 20)

tmin = 0
tmax = t_0 * 2
local trange = tmax - tmin
local n = 1000
local ts = matrix{n}:lambda(function(i) return i/n*tmax end)
local as = ts:map(a)

	amax = table.sup(as)
	amin = table.inf(as)
	local arange = amax - amin
	gl.glOrtho(-.1 * trange + tmin, .1 * trange + tmax, -.1 * arange + amin, .1 * arange + amax, -1, 1)
	
	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glLoadIdentity()

	for _,info in ipairs{
		{buf=as, color={1,0,0}},
	} do
		gl.glBegin(gl.GL_LINE_STRIP)
		gl.glColor3f(table.unpack(info.color))
		for i=1,n do
			gl.glVertex2f(ts[i], as[i])
		end
		gl.glEnd()
	end
	App.super.update(self)
end
local ffi = require 'ffi'
local f = ffi.new('float[1]', 0)
function App:updateGUI()
	for _,field in ipairs{
		'Omega_Lambda',
		'Omega_b',
		'Omega_c',
	} do
		f[0] = _G[field]
		if ig.igSliderFloat(field, f, 0, 1) then
			_G[field] = f[0]
		end
	end

	for _,field in ipairs{
		'tmin', 'tmax',
		'amin', 'amax',
		'Omega_tot',
		't_Lambda',
		't_0',
		'H_0_in_inv_s',
		'rho_crit',
	} do
		local v = _G[field]
		if type(v) == 'function' then v = v() end
		ig.igText(field..' '..v)
	end
end
App():run()
--]]
