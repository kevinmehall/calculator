	
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
	
getUnit = (name) ->
	# TODO: don't use global
	calc.getVar(name)
	
copy = (obj) ->
	o = {}
	for i of obj
		o[i] = obj[i]
	return o
	
class UnitValue extends CalcConstant
	constructor: (@value, @units) ->
	
	display: ->
		pos_units = []
		pos_units = ([Math.abs(e), i] for i,e of @units when e >= 0)
		neg_units = ([Math.abs(e), i] for i,e of @units when e < 0)
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
		
	numUnits: ->
		count = 0
		count++ for i of @units
		return count
		
	isUnitless: ->  @numUnits() == 0
		
	maxDepth: ->
		Math.max.apply(undefined, [0] + (Math.abs(@units[i]) for i of @units))
		
	matchUnits: (other) ->
		# return pair of this and other converted to the same unit
		
		if this.units == other.units
			return [this, other]
		else
			u1 = this
			u2 = other
			
			u1 = u1.normalize()
			unit = new UnitValue(1, u1.units)
			u2 = u2.divide(unit)
			u2 = u2.normalize()
			throw "Incompatible units" if not u2.isUnitless()
			u2.units = u1.units
			return [u1, u2]
			
	replaceUnit: (unitName, value) ->
		res = this.multiply(new UnitValue(Math.pow(value.value, @units[unitName]), powUnits(value.units, @units[unitName])))
		delete res.units[unitName]
		return res
		
	toBaseUnits: ->
		out = this
		for i of @units
			u = getUnit(i) #TODO
			if u.definition
				out = out.replaceUnit(i, u.definition)
		return out
		
	normalize: ->
		@toBaseUnits()
			
	multiply: (other) ->
		new UnitValue(@value*other.value, combineUnits(this.units, other.units))
		
	divide: (other) ->
		new UnitValue(@value/other.value, combineUnits(this.units, powUnits(other.units, -1)))
	
	add: (other) ->
		[a,b] = @matchUnits(other)
		new UnitValue(a.value+b.value, a.units)
		
	subtract: (other) ->
		[a,b] = @matchUnits(other)
		new UnitValue(a.value+b.value, b.units)
		
	pow: (other) ->
		checkUnitsEqual(other.units, {})
		new UnitValue(Math.pow(@value, other.value), powUnits(this.units, other.value))
		
	trig: (fn) ->
		new UnitValue(fn(@value), {}) #TODO: check units, degrees
		
	wrap: (fn) ->
		new UnitValue(fn(@value), @units)
		
class Unit extends UnitValue
	constructor: (definition, names) ->
		@value = 1
		@definition = definition.toBaseUnits() if definition
		@names = names
		if names and names.length
			@setName(names[0])
		else
			@setName('UnnamedUnit')
		
	setName: (@name) ->
		@units = {}
		@units[@name] = 1

exports.number = number = (c) -> new UnitValue(c, {})


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
