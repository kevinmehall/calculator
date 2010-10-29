editGrid = (table) ->
	$(table).find('input').live 'keydown', (e) ->
		elem = this
		
		moveTo = (table, col, row, cursorPos) ->
			if col<0 or row<0 then return
			tr = $(table).children().eq(row)
			input = $(tr).find('input').eq(col)
			input.focus()
		
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
		else if event.which == 40 #down
			moveBy(0, 1)
		else if event.which == 39 and elem.selectionEnd == elem.value.length #right
			moveBy(1, 0, -1)
		else if event.which == 37 and elem.selectionStart == 0 #left
			moveBy(-1, 0, 1)
		else
			return true
		return false
		

class CalcObject
	constructor: (@parent) ->
		@tr = $('<tr><td><input /></td><td>=</td><td><input /></td><td>=></td><td></td></tr>')
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
		catch e
			@setError(e.message)
			throw e
		@recalc()
		
	recalc: ->
		try
			get = (v) =>
				o = @parent.vars[v]
				if not o
					throw {message: "Undefined variable #{v}"}
				if (v == @name) or (@name in o.deps)
					console.log('failing', v, @name, o.deps)
					throw {message:'Recursive dependency'}
				else
					o.evaluate()
			@value = @fn(get)
			$(@td_ans).text(@value)
		catch e
			@setError(e.message)
			throw e
		try
			@parent.updated(@name)
		catch e
			true
		
		
	setError: (e) ->
		$(@td_ans).empty().append($("<span style='color:red'></span>").text(e))
	
	updateName: (name) ->
		@parent.nameChanged(this, @name, name)
		@name = name
		
		
	evaluate: -> @value

	render: ->
		@inp_name.val(@name)
		@inp_val.val(@value)
		return @tr
		
		
class Calc
	constructor: (@table) ->
		editGrid(@table)
		@vars = {}
		@final = false
		@insertFinal()
		
	updated: (name) ->
		for i of @vars
			console.log(i, @vars[i].deps)
			if @vars[i].deps and (name in @vars[i].deps)
				@vars[i].recalc()
		if name == @final.name then @insertFinal()
		
	nameChanged: (obj, oldname, newname) ->
		if oldname
			delete @vars[oldname]
			try
				@updated(oldname)
			catch e
				true
		if newname
			@vars[newname] = obj
			try
				@updated(newname)
			catch e
				true
		console.log('namechanged', newname, @vars)
	
	insertFinal: ->
		final = new CalcObject(this)
		final.updateName('r' + ($(@table).find('tr').length+1))
		@table.append(final.render())
		@final = final
		

ast_compile = (exp) ->
	deps = []
	exp_to_js = (v) ->
		switch v.arity
			when 'literal', 'number'
				""+v.value
			when 'name'
				deps.push(v.value)
				"get('#{v.value}')"
			when 'binary'
				if v.value == '^'
					"Math.pow(#{exp_to_js(v.first)}, #{exp_to_js(v.second)})"
				else
					"(#{exp_to_js(v.first)} #{v.value} #{exp_to_js(v.second)})"
			when 'function'
				if fns[v.value]
					"#{fns[v.value]}(#{exp_to_js(v.arg)})"
			else
				console.error('unknown', v.arity)
	[exp_to_js(exp), deps]
		
$ ->
	window.calc = new Calc($('#page'))				
