	
eachUnitPair = (alist, blist, fn) ->
	ai = bi = 0
	r = []
	while ai < alist.length or bi < blist.length
		a = alist[ai]
		b = blist[bi]
		if not b or (a and a[0].name < b[0].name)
			r.push fn(a[0], a[1], 0)
			ai += 1
		else if a and b and a[0] is b[0]
			r.push fn(a[0],  a[1], b[1])
			ai += 1
			bi += 1
		else if not a or (b and a[0].name > b[0].name)
			r.push fn(b[0], 0, b[1])
			bi += 1
			
	return r
		
combineUnits = (a, b) ->
	out = []
	eachUnitPair a, b, (unit, ac, bc) -> if ac+bc then out.push [unit, ac+bc]
	return out
	
powUnits = (a, p) ->
	([u, c*p] for [u,c] in a)
	
checkUnitsEqual = (a, b) ->
	Math.min.apply(undefined, eachUnitPair a, b, (unit, ac, ab) -> ac==ab) == 1
	
class UnitValue extends CalcConstant
	constructor: (@value, @units) ->
	
	display: ->
		pos_units = []
		pos_units = ([Math.abs(e), i] for [i,e] in @units when e >= 0)
		neg_units = ([Math.abs(e), i] for [i,e] in @units when e < 0)
		pos_units.sort(); neg_units.sort()
		
		units = $("<span class='units'></span>")
		
		for i in pos_units
			units.append(' * ')
			units.append(i[1].name)
			if i[0] != 1
				units.append($('<sup></sup>').text(i[0]))
		for i in neg_units
			units.append(' / ')
			units.append(i[1].name)
			if i[0] != 1
				units.append($('<sup></sup>').text(i[0]))
				
		v = Math.abs(@value)
		if v >= 1e5 or v <= 1e-4
			p = Math.floor(Math.log(v)/Math.LN10)
			v = Math.round(1e8 * v/Math.pow(10, p)) / 1e8
			s = (if @value < 0 then '-' else '')
			v = $("<span class='value'>#{s}#{v} &times; 10<sup>#{p}</sup><span>")
		else
			v = $("<span class='value'></span>").text(@value)
		v.append(units)
		
	numUnits: -> @units.length
		
	isUnitless: ->  @numUnits() == 0
		
	maxDepth: ->
		Math.max.apply(undefined, [0] + (Math.abs(exponent) for [unit, exponent] in @units))
		
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
			
	replaceUnit: (match, replacement) ->
		([(if u is match then replacement else u), count] for  [u, count] in @units)
		
	toBaseUnits: ->
		out = this
		for [u, count] in @units
			if u.definition
				out = out.replaceUnit(u, u.definition)
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
		new UnitValue(a.value-b.value, b.units)
		
	pow: (other) ->
		if not other.isUnitless()
			return new CalcError("Exponent must be unitless")
		else
			return @powJS(other.value)
			
	powJS: (pow) -> 
		new UnitValue(Math.pow(@value, pow), powUnits(this.units, pow))
		
	trig: (fn) ->
		new UnitValue(fn(@value), []) #TODO: check units, degrees
		
	wrap: (fn) ->
		new UnitValue(fn(@value), @units)
		
class Unit extends UnitValue
	constructor: (definition, @name) ->
		@value = 1
		@definitionObj = definition
		@definition = definition.get(rootbinding).toBaseUnits() if definition
		@units = [[this,1]]
		
	invalidate: ->
		@definition = @definitionObj.get(rootbinding).toBaseUnits() if definition
		super
		
	get: (bindings) ->
		@name ||= bindings.name
		super
	 
	setName: (name) ->
		if not @name
			@name = name

exports.number = number = (c, u) -> new UnitValue(c, u||[])


$ ->
	u = exports.unitscope = {}
	u.m = u.meters = u.meter = new Unit(null, 'meter')
	u.s = u.seconds = u.second = new Unit(null, 'second')
	u.kg = u.kilograms = u.kilograms = new Unit(null, 'kilogram')
	u.N = u.newtons = u.newton = new Unit(u.kg.multiply(u.m.divide(u.s.powJS(2))), 'Newton')
	u.J = u.joules = u.joule = new Unit(u.N.multiply(u.m), 'Joule')
	u.C = u.couloumbs = u.coulomb = new Unit(null, 'Coulomb')
	
	u.PI = u.pi = number(Math.PI, [])
	u.E = number(Math.PI, [])
	u.qe = number(1.6e-19, [[u.C, 1]])
	u.e0 = number(8.854187817e-12, [[u.C, 2], [u.kg, -1], [u.m, -3], [u.s, 2]])



