using Godot;

[Tool]
public partial class JiggleBone : BoneAttachment3D
{
    [Export] public bool Enabled = true;

    [Export(PropertyHint.Range, "0.0,1.0,0.01")]
    public float Stiffness = 0.1f;

    [Export(PropertyHint.Range, "0.01,100.0,0.01")]
    public float Damping = 1;

    [Export(PropertyHint.Range, "0.01,10.0,0.001")]
    public float MaxVelocity = 1;

    [Export] public float BoneLength = 1;
    [Export] public Vector3 Gravity = Vector3.Down;

    [Export(PropertyHint.Range, "0.0,1.0,0.01")]
    public float GravityInfluence;

    private Skeleton3D _skeleton;
    private Node3D _reference;
    private Vector3 _previousPosition;
    private Vector3 _currentPosition;
    private Vector3 _targetPosition;
    private Vector3 _targetRestPosition;
    private Vector3 _velocity;
    private int _boneId;
    private int _parentBone;

    private bool _init = false;

    public override void _Ready()
    {
        _skeleton = GetParent<Skeleton3D>();
        _boneId = _skeleton.FindBone(BoneName);
        if (_boneId < 0)
        {
            _init = true;
            return;
        }

        _parentBone = _skeleton.GetBoneParent(_boneId);
        if (_parentBone < 0) _init = true;
    }


    public override void _PhysicsProcess(double delta)
    {
        if (!_init)
        {
            _init = true;

            var refAttachment = new BoneAttachment3D();
            refAttachment.Name = Name + "_Ref";
            _skeleton.AddChild(refAttachment);
            refAttachment.BoneName = _skeleton.GetBoneName(_parentBone);
            _reference = new Node3D();
            AddChild(_reference);
            _reference.Reparent(refAttachment);
            _currentPosition = GlobalTransform.Origin;
            _previousPosition = _currentPosition;
            _targetPosition = _currentPosition + _reference.GlobalTransform.Basis.Y * BoneLength;
            _targetRestPosition = _targetPosition;

            return;
        }

        if (!Enabled || _skeleton is null || _reference is null) return;
        var deltaF = (float) delta;
        var forward = _reference.GlobalTransform.Basis.Y.Lerp(Gravity, GravityInfluence).Normalized() * BoneLength;
        _targetRestPosition = _reference.GlobalTransform.Origin + forward;
        _currentPosition = GlobalTransform.Origin;
        var acceleration = Vector3.Zero;
        acceleration += ((1 - Stiffness) * -(_currentPosition - _previousPosition)) * deltaF;
        acceleration += (_targetRestPosition - _targetPosition) * deltaF;
        acceleration += Damping * -_velocity * deltaF;
        _velocity += acceleration;
        _targetPosition += _velocity;
        if (_targetRestPosition.DistanceTo(_targetPosition) > MaxVelocity)
            _targetPosition = _targetRestPosition + _targetRestPosition.DirectionTo(_targetPosition) * MaxVelocity;
        _previousPosition = _currentPosition;
        var y = _currentPosition.DirectionTo(_targetPosition);
        var x = y.Cross(-_reference.GlobalTransform.Basis.Z);
        var z = y.Cross(x);
        x = -x;
        var boneTransform = new Transform3D(new Basis(x, y, z).Orthonormalized(), _reference.GlobalTransform.Origin);
        boneTransform = _skeleton.GlobalTransform.Inverse() * boneTransform;
        _skeleton.SetBoneGlobalPoseOverride(_boneId, boneTransform, 1, true);
    }
}
