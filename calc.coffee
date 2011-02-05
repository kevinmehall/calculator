exports = window

id = 0

class CalcObject
	constructor: ->
		@id = id++
		
	setName: (@name) ->

class CalcReactive extends CalcObject
	constructor: ->
		super
		@listeners = []
		@invalidated = false
	
	addListener: (l) ->
		@listeners.push(l)
		
	removeListener: (l) ->
		i = @listeners.indexOf(l)
		if i != -1
			@listeners.splice(i, 1)
		
	invalidate: ->
		if not @invalidating
			@invalidating = true
			listener.invalidate() for listener in @listeners
			@invalidating = false
		

class CalcConstant extends CalcObject
	type: 'constant'
	
	addListener: ->
		# ignore, because we'll never notify
		
	removeListener: ->
		
	get: -> this
	
exports.CalcError = class CalcError extends CalcConstant
	type: 'error'
	constructor: (@error) -> super
	
	display: ->
		e = if @error.message
			@error.message
		else 
			@error
		$("<span style='color:red'></span>").text(e)

recursiveDepError = new CalcError("Recursive dependency")

class CalcExpression extends CalcReactive
	type: 'expression'
			
	get: (bindings) ->
		return recursiveDepError if @inside
	
		@inside = true
		v = @evaluate(bindings).get(bindings)
		@inside = false
		return v
	
macroClass = (fn) ->
	(args) ->
		cl = new CalcExpression()
		
		for i in args
			i.addListener(cl)
			
		cl.evaluate = (bindings) ->
			console.log('eval macro')
			try
				fn.apply(bindings, args)
			catch e
				console.error(e, e.stack)
				return new CalcError(e.message ? e)
		return cl

fnToExpressionClass = (fn) ->			
	macroClass ->
		args = Array.prototype.slice.apply(arguments)
		
		evaluatedArgs = []
	
		for a in args
			v = a.get(this)
			if v.type == 'error'
				if v.name
					return new CalcError("Previous error from '#{a.name}'")
				else
					return v
			else if v.type == 'arg'
				return new UnboundArgError(v)
				
			evaluatedArgs.push(v)
	
		fn.apply(this, evaluatedArgs)
		
constructor = (fn) ->
	(args) ->
		obj = fn.apply(this, args)
		
		for i in args
			i.addListener(obj)
			
		return obj
		
OPS = 
	'*': fnToExpressionClass((a, b) -> a.multiply(b))
	'/': fnToExpressionClass((a, b) -> a.divide(b))
	'+': fnToExpressionClass((a, b) -> a.add(b))
	'-': fnToExpressionClass((a, b) -> a.subtract(b))
	'^': fnToExpressionClass((a, b) -> a.pow(b))

FNS = {
	sin: fnToExpressionClass (x) -> x.trig(Math.sin)
	cos: fnToExpressionClass (x) -> x.trig(Math.cos)
	tan: fnToExpressionClass (x) -> x.trig(Math.tan)
	round: fnToExpressionClass (x) -> x.wrap(Math.round)
	abs: fnToExpressionClass (x) -> x.wrap(Math.abs)
	sqrt: fnToExpressionClass (x) -> x.sqrt()
	ln: fnToExpressionClass (x) -> x.ln()
	unit: constructor (x) -> new Unit(x)
	arg: constructor () -> new CalcArg()
	let: macroClass (arg, val, exp) -> exp.get(this.extend(arg.get(this), val))
	linspace: constructor (lolimit, hilimit) -> new Linspace(lolimit, hilimit)
	plot: macroClass (x,y) -> plot(this, x,y)
}


compileExpression = (exp, context) ->
	expression = (v) ->
		switch v.arity
			when 'literal', 'number'
				number(v.value)
			when 'name'
				context.getVar(v.value)
			when 'binary'
				op = OPS[v.value]
				new op([expression(v.first, context), expression(v.second, context)])
			when 'function'
				if FNS[v.value]
					a = (expression(i, context) for i in v.args)
					FNS[v.value](a)
				else
					new CalcError("Undefined function '#{v.value}'")
			else
				console.error('unknown', v.arity)
				new CalcError('unknown AST node')
		
	try
		p = parse(exp)
	catch e
		return new CalcError(e.message ? e)
	
	return expression(p)


		
class CalcVarExpression extends CalcReactive
	type: 'var'
	constructor: (@name, value) ->
		super
		@value = false
		@set(value) if value
		@inside = false
		
	get: (bindings) ->
		return recursiveDepError if @inside
	
		@inside = true
		v = @value.get(bindings.withName(@name))
		@inside = false
		
		return v
		
	set: (value) ->
		if @value
			@value.removeListener()
		@value = value
		@value.addListener(this)
		@invalidate()
		
class CalcArg extends CalcReactive
	type: 'arg'
	constructor: () ->
		super
		
	get: (bindings) -> 
		@name ||= bindings.name
		
		v = bindings.args[@id]
		if v
			v.get(bindings)	
		else
			this
			
	display: -> $("<span style='color:green'></span>").text("Argument #{@name}") 
			
class UnboundArgError extends CalcError
	constructor: (@arg) -> super
	display: -> $("<span style='color:green'></span>").text("Function of #{@error.name}") 
	
class Linspace extends CalcArg
	constructor: (@lolimit, @hilimit) -> 
		super
		
getNumber = (v, bindings) ->
	v.get(bindings).value ? NaN
	
	
class Bindings
	constructor: (@args, @name) ->
		
	extend: (arg, val) ->
		F = -> 
		F.prototype = @args
		v = new F()
		v[arg.id] = val
		return new Bindings(v, @name)
		
	withName: (name) ->
		return new Bindings(@args, name)
		
rootbinding = new Bindings({}, 'TopLevel')
		
exports.Context = class Context
	constructor: (@scopes)->
		@vars = {}

	renameVar: (n1, n2) ->
		if n2
			n2 = @uniquifyName(n2)
			return if n1 is n2
			@vars[n2] = @vars[n1]
		delete @vars[n1]
			
	varExists: (v) -> 
		return true if @vars[v]
		for scope in @scopes
			return true if scope[v]
			
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
		
	getVar: (v) -> 
		return @vars[v] if @vars[v]
		for scope in @scopes
			return scope[v] if scope[v]
		new CalcError("Undefined variable '#{v}'")
