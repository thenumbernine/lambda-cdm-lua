-- searches for the minimum
return function(xL, xR, f, maxiter)
	local yL = f(xL)
	local yR = f(xR)
	for i=0,maxiter do
		local xMid = .5 * (xL + xR)
		local yMid = f(xMid)
		if yMid > yL and yMid > yR then break end
		if yMid < yL and yMid < yR then
			if yL <= yR then
				xR, yR  = xMid, yMid
			else
				xL, yL = xMid, yMid
			end
		elseif yMid < yL then
			xL, yL = xMid, yMid
		else
			xR, yR = xMid, yMid
		end
	end
	if yL < yR then
		return xL, yL
	else
		return xR, yR
	end
end
