# MIT License

# Copyright (c) 2023 Master-J

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@tool
extends BoneAttachment3D
class_name  JiggleBone

## Enables the jiggle physics
@export								var enabled				: bool		= true;

## Modulates the strength applies to the bone coming from its movement
@export_range(0.0, 1.0, 0.01)		var stiffness			: float		= 0.1;
## Controls how fast the bone will return to its rest position
@export_range(0.01, 100.0, 0.01)	var damping				: float		= 1.0;
## Limits how fast the bone can move between 2 updates
@export_range(0.01, 10.0, 0.001)	var max_velocity		: float		= 1.0;

## Controls the jigglyness of the bone
## Low values = high jigglyness
## High values = low jigglyness
@export								var bone_length			: float		= 1.0;

## Global gravity direction
@export								var gravity				: Vector3	= Vector3(0.0, -1.0, 0.0);
## How much influence the gravity vector has over the bone's rest position
## 0 : The bone's rest position equals it's current position + (local forward direction * bone length)
## 1 : The bone's rest position equals it's current position + (gravity direction * bone length)
@export_range(0.0, 1.0, 0.01)		var gravity_influence	: float		= 0.0;

var skeleton					: Skeleton3D	= null;
var reference					: Node3D		= null;

var previous_position			: Vector3		= Vector3.ZERO;
var current_position			: Vector3		= Vector3.ZERO;

var target_position				: Vector3		= Vector3.ZERO;
var target_rest_position		: Vector3		= Vector3.ZERO;

var velocity					: Vector3		= Vector3.ZERO;

var bone_id						: int			= -1;
var parent_bone					: int			= -1;

func _ready() -> void:
	skeleton = get_parent() as Skeleton3D;

	bone_id = skeleton.find_bone(bone_name);
	if bone_id < 0:
		return;

	parent_bone = skeleton.get_bone_parent(bone_id);
	if parent_bone < 0:
		return;

	await get_tree().process_frame;

	#Instantiate a bone attachment that will act as a clone of the associated bone
	#Used to know where the associated bone whould be if it didn't have jiggle applied to it
	var reference_attachment : BoneAttachment3D = BoneAttachment3D.new();
	reference_attachment.name = name + "_Ref";
	skeleton.add_child(reference_attachment);
	reference_attachment.bone_name = skeleton.get_bone_name(parent_bone);

	await get_tree().process_frame;

	reference = Node3D.new();
	add_child(reference);
	reference.reparent(reference_attachment, true);

	#Initial conditions 
	current_position = global_transform.origin;
	previous_position = current_position;
	target_position = current_position + reference.global_transform.basis.y * bone_length;
	target_rest_position = target_position;

func _physics_process(delta : float) -> void:
	if enabled == false || skeleton == null || reference == null :
		return;

	#Get current rest position
	var forward : Vector3 =reference.global_transform.basis.y.lerp(gravity, gravity_influence).normalized() * bone_length;
	target_rest_position = reference.global_transform.origin + forward;

	current_position = global_transform.origin;

	var acceleration : Vector3 = Vector3.ZERO;
	#Get the strength of the bone's movement
	acceleration += ((1.0 - stiffness) * -(current_position - previous_position)) * delta;
	#Bounce back to rest postion 
	acceleration += (target_rest_position - target_position) * delta;
	#Damping
	acceleration += damping * -velocity * delta;

	#Velocity update
	velocity = velocity + acceleration;

	#Update target position
	target_position = target_position + velocity;

	#Clamp velocity
	if target_rest_position.distance_to(target_position) > max_velocity :
		target_position = target_rest_position + target_rest_position.direction_to(target_position) * max_velocity;

	previous_position = current_position;

	#Rotated Basis generation
	var x : Vector3 = Vector3.ZERO;
	var y : Vector3 = Vector3.ZERO;
	var z : Vector3 = Vector3.ZERO;

	y = current_position.direction_to(target_position);
	x = y.cross(-reference.global_transform.basis.z);
	z = y.cross(x);

	#Swap x axis to match the original basis orientation
	x = -x;

	#Generate the new bone transform oriented to the bone's target
	var bone_transform : Transform3D = Transform3D(Basis(x, y, z).orthonormalized(), reference.global_transform.origin);
	bone_transform = skeleton.global_transform.inverse() * bone_transform;
	skeleton.set_bone_global_pose_override(bone_id, bone_transform, 1.0, true);
