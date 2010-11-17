exports = window

class CalcObject
class CalcConstant extends CalcObject
	state: 'constant'
	
combineUnits = (a, b) ->
	out = {}
	for u of a
		out[u] = a[u]
	for u of b
		if not out[u]
			out[u] = 0
		out[u] += b[u]
		if out[u] == 0
			delete out[u]
	return out
	
powUnits = (a, p) ->
	out = {}
	for u,e of a
		out[u] = e*p
	return out
	
checkUnitsEqual = (a, b) ->
	for i, e of a
		return false if b[i] != e
	for i, e of b
		return false if a[i] != e
	return true
	
class UnitValue extends CalcConstant
	constructor: (@value, @units) ->
	
	setName: (@name) ->
	
	display: ->
		pos_units = []
		pos_units = ([Math.abs(e), i] for i,e of @units when e >= 0)
		neg_units = ([Math.abs(e), i] for i,e of @units when e < 0)
		console.info('units', pos_units, neg_units)
		pos_units.sort(); neg_units.sort()
		
		units = $("<span class='units'></span>")
		
		for i in pos_units
			units.append(' * ')
			units.append(i[1])
			if i[0] != 1
				units.append($('<sup></sup>').text(i[0]))
		for i in neg_units
			units.append(' / ')
			units.append(i[1])
			if i[0] != 1
				units.append($('<sup></sup>').text(i[0]))
		
		$("<span class='value'></span>").text(@value).append(units)
			
	multiply: (other) ->
		new UnitValue(@value*other.value, combineUnits(this.units, other.units))
		
	divide: (other) ->
		new UnitValue(@value/other.value, combineUnits(this.units, powUnits(other.units, -1)))
	
	add: (other) ->
		checkUnitsEqual(this.units, other.units)
		new UnitValue(@value+other.value, @units)
		
	subtract: (other) ->
		checkUnitsEqual(this.units, other.units)
		new UnitValue(@value-other.value, @units)
		
	pow: (other) ->
		checkUnitsEqual(other.units, {})
		new UnitValue(Math.pow(@value, other.value), powUnits(this.units, other.value))
		
	trig: (fn) ->
		new UnitValue(fn(@value), {}) #TODO: check units, degrees
		
	wrap: (fn) ->
		new UnitValue(fn(@value), @units)
		
class Unit extends UnitValue
	constructor: (@definition, names) ->
		@value = 1
		@names = names
		if names and names.length
			@setName(names[0])
		else
			@setName('UnnamedUnit')
		
	setName: (@name) ->
		@units = {}
		@units[@name] = 1

exports.number = number = (c) -> new UnitValue(c, {})

exports.CalcExpression = class CalcExpression extends CalcObject
	state: 'expression'
	constructor: (exp) ->
		try
			p = parse(exp)
			[js, @deps] = ast_compile(p)
			console.log(js)
			eval("function fn(vals){return #{js}}")
			@fn = fn
		catch e
			@parseError = new CalcError(e)
			
	evaluate: (context) ->
		if @parseError
			@parseError
		else if not @fn
			return new CalcError("Not compiled!")
		else
			vals = {}
			for i in @deps
				vals[i] = context.getVar(i)
				if not vals[i]
					return new CalcError("Undefined variable #{i}")
				if vals[i].state is 'error'
					return new CalcError("Previous error from #{i}")
			@fn(vals)
			
exports.CalcError = class CalcError extends CalcObject
	state: 'error'
	constructor: (@error) ->
	
	display: ->
		e = if @error.message
			@error.message
		else 
			@error
		$("<span style='color:red'></span>").text(e)
		
exports.Context = class Context
	constructor: (@scopes)->
		@vars = {}
		@cache = {}
		
	getVar: (v) ->
		if not @cache[v]
			val =  @vars[v]
			if not val
				for i in @scopes
					return i[v] if i[v]
				return false
			if val.state is 'expression'
				@cache[v] = new CalcError("recursive") # set it to error while running so it errors out instead of entering loop
				val = @vars[v].evaluate(this)
			@cache[v] = val
		return @cache[v]
		
	varExists: (v) ->
		if v of @vars
			return true
		else
			for i in @scopes
				return true if i[v]
		return false
		
	setVar: (v, val) ->
		@vars[v] = val
		@update(v)
		
	renameVar: (n1, n2) ->
		if n2
			n2 = @uniquifyName(n2)
			return if n1 is n2
			@vars[n2] = @vars[n1]
		del @vars[n1]
		@update(n1)
		if n2
			@update(n2)
			
	uniquifyName: (name) ->
		if not name
			name = 'r1'
			
		if name.charAt(0) <= '9'
			name = 'r'+name
		
		if @varExists(name)
			countstr = /\d*$/.exec(name)[0]
			if countstr
				count = parseInt(countstr, 10) + 1
			else
				count = 1
			return @uniquifyName(name.slice(0, name.length-countstr.length)+count)
			
		return name
		
	update: (v, inside) ->
		inside = inside ? []
		inside.unshift(v)

		delete @cache[v]

		for i of @vars
			if @vars[i].deps and (@vars[i].deps.indexOf(v) != -1) and (inside.indexOf(i) == -1)
				@update(i, inside)
		

	
		
OPS = {'*':'multiply', '/':'divide', '+':'add', '-':'subtract', '^':'pow'}
FNS = {
	sin: (x) -> x.trig(Math.sin)
	cos: (x) -> x.trig(Math.cos)
	tan: (x) -> x.trig(Math.tan)
	round: (x) -> x.wrap(Math.round)
	abs: (x) -> x.wrap(Math.abs),
	sqrt: (x) -> x.sqrt()
	ln: (x) -> x.ln(),
	unit: (x) -> new Unit(x)
}

ast_compile = (exp) ->
	deps = []
	exp_to_js = (v) ->
		switch v.arity
			when 'literal', 'number'
				"number(#{v.value})"
			when 'name'
				deps.push(v.value)
				"vals['#{v.value}']"
			when 'binary'
					op = OPS[v.value]
					"#{exp_to_js(v.first)}.#{op}(#{exp_to_js(v.second)})"
			when 'function'
				if FNS[v.value]
					a = (exp_to_js(i) for i in v.args).join(',')
					"FNS.#{v.value}(#{a})"
				else
					throw {message:"undefined function: #{v.value}"}
			else
				console.error('unknown', v.arity)
	[exp_to_js(exp), deps]

units = [
	[false, ['meter', 'meters', 'm']],
	[false, ['second', 'seconds', 's']],
	[false, ['kilogram', 'kilograms', 'kg']],
]

exports.unitscope = {}

for i in units
	p = false
	if i[0]
		p = unitscope[i[0]]
	u = new Unit(p, i[1])
	for name in i[1]
		unitscope[name] = u
