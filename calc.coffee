exports = window

class CalcObject
		setName: (@name) ->

class CalcReactive extends CalcObject
	constructor: ->
		super
		@listeners = []
		@cache = false
		@invalidated = false
	
	addListener: (l) ->
		@listeners.push(l)
		
	removeListener: (l) ->
		i = @listeners.indexOf(l)
		if i != -1
			@listeners.splice(i, 1)
		
	invalidateCache: ->
		@cache = false
		if not @invalidated
			@invalidated = true
			listener.invalidateCache() for listener in @listeners
			
	setValid: ->
		@invalidated = false
		
	get: -> @cache

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
			
	get: ->
		@setValid()
		if not @cache
			@cache = recursiveDepError # so it fails if accessed by evaluate()
			@cache = @evaluate()
		return super()
		
	
fnToExpressionClass = (fn) ->
	(args) ->
		cl = new CalcExpression()
		cl.args = args
		
		for i in args
			i.addListener(cl)
	 	
		cl.evaluate = ->
			evaluatedArgs = []
			for a in @args
				v = a.get()
				if v.type == 'error'
					if v.name
						return new CalcError("Previous error from '#{a.name}'")
					else
						return v
				evaluatedArgs.push(v)
			fn.apply(this, evaluatedArgs)
		
		return cl

		
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
	unit: fnToExpressionClass (x) -> new Unit(x)
}


expression = (v, context) ->
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
				new FNS[v.value](a)
			else
				new CalcError("Undefined function '#{v.value}'")
		else
			console.error('unknown', v.arity)
			new CalcError('unknown AST node')


		
class CalcVarExpression extends CalcReactive
	type: 'var'
	constructor: (@name, value) ->
		super
		@value = false
		@set(value) if value
		@inside = false
		
	get: ->
		@setValid()
		return recursiveDepError if @inside
	
		@inside = true
		v = @value.get()
		@inside = false
		
		v.setName(@name)
		return v
		
	set: (value) ->
		if @value
			@value.removeListener()
		@value = value
		@value.addListener(this)
		@invalidateCache()
		
		
		
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
