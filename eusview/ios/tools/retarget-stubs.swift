// retargettest 用: RobotModel.swift が使う Physics の型 (PhysicsSim.swift と同じ, ODE なしでコンパイルするため)
struct PhysLink: Codable { var mass: Double?; var com: [Double]?; var inertia: [Double]?; var shapes: [PhysShape]? }
struct PhysShape: Codable { var type: String; var size: [Double]?; var radius: Double?; var length: Double?; var pos: [Double]?; var rot: [Double]? }
struct PhysJoint: Codable { var motor: String?; var fmax: Double?; var vmax: Double?; var kp: Double? }
struct PhysWorld: Codable { var gravity: [Double]?; var dt: Double?; var erp: Double?; var cfm: Double?; var quickstep: Bool?; var iterations: Int? }
struct PhysContact: Codable { var mu: Double?; var soft_erp: Double?; var soft_cfm: Double?; var bounce: Double?; var bounce_vel: Double?; var max_contacts: Int? }
struct PhysMotor: Codable { var kp: Double?; var fmax: Double? }
struct Physics: Codable { var links: [PhysLink]?; var joints: [PhysJoint]?; var world: PhysWorld?; var contact: PhysContact?; var odedyna_motor: PhysMotor? }
