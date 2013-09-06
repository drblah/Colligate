require "gchart"

class Charter

	def generateImage(price, date)

		Gchart.line(:data => [0, 10, 0 ,10], :format => "file", :filename => "graph.png")
		
	end

end