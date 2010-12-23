sqr = (x) -> x*x

class A
	a: () -> 2

class B extends A
	a: () ->
		sqr super()
