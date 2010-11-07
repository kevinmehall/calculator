editGrid = (table, outsideBoundFn) ->
	$(table).find('input').live 'keydown', (e) ->
		elem = this
		
		moveTo = (table, col, row, cursorPos) ->
			if col<0 or row<0 then return
			tr = $(table).children().eq(row)
			input = $(tr).find('input').eq(col)
			try
				$(elem).change()
			catch e
				console.error(e)
			if input.length
				input.focus()
			else
				outsideBoundFn(elem, col, row)
		
		pos = ->
			tr = $(elem).closest('tr')
			table = $(tr).parent()
			row = $(table).children().index(tr)
			col = $(tr).find('input').index(elem)
			[table,col,row]
			
		moveBy = (x, y, cursorPos) ->
			[table,col,row] = pos()
			moveTo(table, col+x, row+y, cursorPos)

		if event.which == 38 #up
			moveBy(0, -1)
		else if event.which == 40 or event.which == 13 #down, enter
			moveBy(0, 1)
		else if (event.which == 39 or event.which == 187 and not event.shiftKey) and elem.selectionEnd == elem.value.length #right
			moveBy(1, 0, -1)
		else if event.which == 37 and elem.selectionStart == 0 #left
			moveBy(-1, 0, 1)
		else
			return true
		return false
		

class CalcValue
	
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
	
class ConstantValue extends CalcValue
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
		new ConstantValue(@value*other.value, combineUnits(this.units, other.units))
		
	divide: (other) ->
		new ConstantValue(@value/other.value, combineUnits(this.units, powUnits(other.units, -1)))
	
	add: (other) ->
		checkUnitsEqual(this.units, other.units)
		new ConstantValue(@value+other.value, @units)
		
	subtract: (other) ->
		checkUnitsEqual(this.units, other.units)
		new ConstantValue(@value-other.value, @units)
		
	pow: (other) ->
		checkUnitsEqual(other.units, {})
		new ConstantValue(Math.pow(@value, other.value), powUnits(this.units, other.value))
		
	trig: (fn) ->
		new ConstantValue(fn(@value), {}) #TODO: check units, degrees
		
	wrap: (fn) ->
		new ConstantValue(fn(@value), @units)
		
class Unit extends ConstantValue
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

number = (c) -> new ConstantValue(c, {})

class CalcObject
	constructor: (@parent) ->
		@tr = $("<tr><td class='name'><input /></td><td>=</td><td><input /></td><td>=></td><td></td></tr>")
		$(@tr).data('obj', this)
		[@td_name, _, @td_value, _, @td_ans] = @tr.find('td')
		@inp_name = $(@td_name).find('input')
		@inp_name.change => @updateName(@inp_name.val())
		@inp_val = $(@td_value).find('input')
		@inp_val.change => @update(@inp_val.val())
	
	update: (@value) ->
		try
			p = parse(@value)
			[js, @deps] = ast_compile(p)
			eval("function fn(get){return #{js}}")
			@fn = fn
			@recalc()
		catch e
			@setError(e.message)
			console.error(e)
			throw e
		
	findRecursiveDeps: (chain) ->
		throw "abort!" if chain and chain.length > 10
		if chain and @name == chain[0]
			s = chain.join(' -> ')
			throw {message:"Recursive dependency: #{s}"}
		chain ?= []
		console.log('chain', chain)
		for dep in @deps
			if @parent.vars[dep]
				console.log("dep", dep)
				@parent.vars[dep].findRecursiveDeps(chain.concat([@name]))

		
	recalc: ->
		return if not @fn
		console.log("recalc", @name, @deps)
		try
			@findRecursiveDeps()
			get = (v) =>
				o = @parent.getVar(v)
				if not o
					throw {message: "Undefined variable #{v}"}
				else
					if o.isError
						throw {message: "Secondary error from #{v}"}
					if o.evaluate
						o = o.evaluate()
				return o
			@value = @fn(get)
			@isError = false
			if not @value.name
				@value.setName(@name)
			$(@td_ans).empty().append(@value.display())
			@parent.updated(@name)
		catch e
			@setError(e.message)
			console.error(e, e.stack)
			return
			
			
		
	setError: (e) ->
		@isError = e
		$(@td_ans).empty().append($("<span style='color:red'></span>").text(e))
		#@parent.updated(@name)
	
	updateName: (name) ->
		if not name
			name = 'r1'
			
		if name.charAt(0) <= '9'
			name = 'r'+name
		
		return if name == @name
		
		if @parent.getVar(name)
			countstr = /\d*$/.exec(name)[0]
			if countstr
				count = parseInt(countstr, 10) + 1
			else
				count = 1
			return @updateName(name.slice(0, name.length-countstr.length)+count)
			
		return if name == @name
		
		oldname = @name
		@name = name
		@value.name = name if @value
		@inp_name.val(name)
		@parent.nameChanged(this, oldname, name)
		@recalc()
		
	evaluate: -> @value

	render: ->
		@inp_name.val(@name)
		@inp_val.val(@value)
		return @tr
		
		
class Calc
	constructor: (@table, scopes) ->
		editGrid @table, (elem, col, row) =>
			console.log('offside', col, row)
			if col > 1 #off the side
				$(elem).change()
			if row >= $(@table).find('tr').length #off the bottom
				@newRow()
				
		@vars = {}
		@scopes = scopes ? []
		@newRow()
		
	getVar: (v) ->
		if v of @vars
			return @vars[v]
		else
			for i in @scopes
				if i[v]
					return i[v]
		return undefined
					
	updated: (name) ->
		for i of @vars
			if @vars[i].deps and (name in @vars[i].deps)
				@vars[i].recalc()
		
	nameChanged: (obj, oldname, newname) ->
		if oldname
			delete @vars[oldname]
			try
				@updated(oldname)
			catch e
				console.error(e)
		if newname
			@vars[newname] = obj
		console.log('namechanged', newname, @vars)
		
	newRow: ->
		final = new CalcObject(this)
		e = final.render()
		@table.append(e)
		$(e).find('input').eq(0).focus()
	
		
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
				"get('#{v.value}')"
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

unitscope = {}

for i in units
	p = false
	if i[0]
		p = unitscope[i[0]]
	u = new Unit(p, i[1])
	for name in i[1]
		unitscope[name] = u


$ ->
	window.calc = new Calc($('#page'), [unitscope])				
