editGrid = (table, outsideBoundFn) ->
	$(table).find('input').live 'keydown', (e) ->
		elem = this
		
		moveTo = (table, col, row, cursorPos) ->
			if col<0 or row<0 then return
			tr = $(table).children().eq(row)
			input = $(tr).find('input').eq(col)
			$(elem).change()
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
		
		
class CalcViewRow
	constructor: (@parent) ->
		@value = false
		@name = false
		
		@tr = $("<tr><td class='name'><input /></td><td>=</td><td><input /></td><td>=></td><td></td></tr>")
		
		[@td_name, _, @td_value, _, @td_ans] = @tr.find('td')
		@inp_name = $(@td_name).find('input')
		@inp_name.change => 
			@changeName(@inp_name.val())
		@inp_val = $(@td_value).find('input')
		@inp_val.change =>
			@changeExp(@inp_val.val())

	update: ->
		@inp_name.val(@name)
		#@inp_val.val(@value)
		$(@td_ans).empty().append(@parent.getVar(@name).display())

	changeName: (name) ->
		if name is @name then return
		name = @parent.uniquifyName(name)
		if @name
			delete @parent.rows[@name]
		@parent.rows[name] = this	
		@name = name
		@parent.renameVar(@name, name)
	
	changeExp: (exp) ->
		if not @name
			@name = @parent.uniquifyName('r1')
			@parent.rows[@name] = this
		@value = new CalcExpression(exp)
		@parent.setVar(@name, @value)


class CalcView extends Context
	constructor: (@table, scopes) ->
		super(scopes)
		editGrid @table, (elem, col, row) =>
			console.log('offside', col, row)
			if col > 1 #off the side
				$(elem).change()
			if row >= $(@table).find('tr').length #off the bottom
				@newRow()
				
		@vars = {}
		@rows = {}
		@scopes = scopes ? []
		@newRow()
		
	newRow: ->
		row = new CalcViewRow(this)
		$(@table).append(row.tr)
		$(row.tr).find('input').eq(0).focus()
		
	update: (v, inside) ->
		super(v, inside)
		@rows[v].update()
		

$ ->
	window.calc = new CalcView($('#page'), [unitscope])
	
