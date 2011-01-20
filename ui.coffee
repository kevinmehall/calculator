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
			return input
		
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
		else if event.which == 39 and elem.selectionEnd == elem.value.length #right
			moveBy(1, 0, -1)
		else if event.which == 37 and elem.selectionStart == 0 #left
			moveBy(-1, 0, 1)
		else if event.which == 187 and not event.shiftKey # equals
			[table, col, row] = pos()
			if col == 1
				name = $(elem).val()
				i = $(elem).closest('tr').find('input').eq(0)
				if /^[a-zA-Z0-9]+$/.test(name) and not i.val()
					$(elem).val('')
					i.val(name).change()
					return false
			moveBy(1, 0, -1)
		else
			return true
		return false
		
		
class CalcViewRow
	constructor: (@parent) ->
		@var = new CalcVarExpression()
		@var.addListener(this)
		
		@tr = $("<tr><td class='name'><input /></td><td class='eq'>=</td><td><input /></td><td class='ans_arr'>&rarr;</td><td></td></tr>")
		
		[@td_name, _, @td_value, _, @td_ans] = @tr.find('td')
		@inp_name = $(@td_name).find('input')
		@inp_name.change => 
			@changeName(@inp_name.val())
		@inp_val = $(@td_value).find('input')
		@inp_val.change =>
			@changeExp(@inp_val.val())

	update: =>
		$(@td_ans).empty().append(@var.get().display())

	changeName: (name) ->
		if not name or name is @var.name then return
		name = @parent.uniquifyName(name)
		@var.name = name
		@inp_name.val(name)
		@parent.vars[name] = @var
			
	changeExp: (exp) ->
		if not @var.name
			@changeName('r1')
		p = parse(exp)
		@var.set(expression(p, @parent))
		
	invalidateCache: ->
		setTimeout(@update, 10)

class CalcView extends Context
	constructor: (@table, scopes) ->
		super(scopes)
		editGrid @table, (elem, col, row) =>
			if col > 1 #off the side
				$(elem).change()
			if row >= $(@table).find('tr').length #off the bottom
				@newRow()
				
		@rows = {}
		@scopes = scopes ? []
		@newRow()
		
	newRow: ->
		row = new CalcViewRow(this)
		$(@table).append(row.tr)
		$(row.tr).find('input').eq(1).focus()	

$ ->
	window.calc = new CalcView($('#page'), [unitscope])
	
