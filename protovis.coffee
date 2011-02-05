

class GraphContainer extends CalcConstant
	constructor: (@pv) ->
		super
		
	display: ->
		div = document.createElement('div')
		@pv.canvas(div)
		@pv.render()
		return div

plot = (bindings, xvar, yvar) -> 
		xsp = xvar.get(bindings)
		xlo = getNumber(xsp.lolimit, bindings)
		xhi = getNumber(xsp.hilimit, bindings) 
	
		w = 250
		h = 175
		
		console.log(xlo, xhi)
		
		data = pv.range(xlo, xhi, (xhi-xlo)/h).map (x) ->
			console.log(yvar.get(bindings.extend(xsp,number(x))))
			{x: x, y:getNumber(yvar, bindings.extend(xsp, number(x)))} #TODO: units
		
		ymax = pv.max(data, (d)->d.y)
			
		console.log(data)
		
		x = pv.Scale.linear(xlo, xhi).range(0, w)
		y = pv.Scale.linear(0, ymax).nice().range(0, h)
	
		vis = new pv.Panel()
			.width(w + 5)
			.height(h + 20 + 10)
			.bottom(20)
			.left(20)
			.right(10)
			.top(5);

		# X-axis ticks
		vis.add(pv.Rule)
			.data(x.ticks())
			.left(x)
			.strokeStyle((d) -> if d then "#eee" else "#000")
		  .anchor("bottom").add(pv.Label)
			.text(x.tickFormat);

		# Y-axis ticks.
		vis.add(pv.Rule)
			.data(y.ticks(5))
			.bottom(y)
			.strokeStyle((d) -> if d then "#eee" else "#000")
		  .anchor("left").add(pv.Label)
			.text(y.tickFormat);

		# The line
		vis.add(pv.Line)
			.data(data)
			.left((d) -> x(d.x))
			.bottom((d) -> y(d.y))
			.lineWidth(3);

		return new GraphContainer(vis)
