extends RigidBody3D

## Local X is treated as sideways slide; multiply by this each physics step (0.1 ~= 90% reduction).
@export var sideways_velocity_retention: float = 0.1

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var local_v: Vector3 = state.transform.basis.inverse() * state.linear_velocity
	local_v.x *= sideways_velocity_retention
	state.linear_velocity = state.transform.basis * local_v
