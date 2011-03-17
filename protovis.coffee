

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
		if xsp.constructor == UnboundArgError
			xsp = xsp.arg
			
		if xsp.constructor != Linspace
			return new CalcError("x must be a function of a Linspace")
		
		
		xlo = getNumber(xsp.lolimit, bindings)
		xhi = getNumber(xsp.hilimit, bindings) 
	
		w = 250
		h = 175
		
		console.log(xlo, xhi)
		
		step = 10*(xhi-xlo)/h
		data = pv.range(xlo, xhi + step, step).map (x) ->
			b = bindings.extend(xsp, number(x))
			{x: getNumber(xvar, b), y: getNumber(yvar, b)} #TODO: units
		
		
		xmax = pv.max(data, (d)->d.x)
		xmin = pv.min(data, (d)->d.x)
		ymax = pv.max(data, (d)->d.y)
		ymin = pv.min(data, (d)->d.y)
		
		x = pv.Scale.linear(xmin, xmax).nice().range(0, w)
		y = pv.Scale.linear(ymin, ymax).nice().range(0, h)
	
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
