extends Actor2D

class TestState extends AI.State:
	func _init(init_actor: Actor2D) -> void:
		name = "Test state"
		actor = init_actor
	
	func update(_delta: float) -> Event:
		print("Test state update")
		return AI.Event.NONE
	
	func enter() -> void:
		print("Test state enter")
	
	func exit() -> void:
		print("Test state exit")
