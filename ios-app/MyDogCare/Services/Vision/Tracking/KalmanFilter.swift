import Foundation
import CoreGraphics

/// A simple Kalman Filter for tracking bounding boxes in 2D space.
/// State vector: [cx, cy, aspect_ratio, height, vx, vy, va, vh]
/// Measurement vector: [cx, cy, aspect_ratio, height]
final class KalmanFilter {
    // State vector
    private var x: [Float]
    
    // Covariance matrix
    private var P: [[Float]]
    
    // State transition matrix (F)
    private let F: [[Float]]
    
    // Measurement matrix (H)
    private let H: [[Float]]
    
    // Process noise covariance (Q)
    private let Q: [[Float]]
    
    // Measurement noise covariance (R)
    private let R: [[Float]]
    
    init(initialBBox: CGRect) {
        // Initialize state: [cx, cy, ratio, h, 0, 0, 0, 0]
        let cx = Float(initialBBox.midX)
        let cy = Float(initialBBox.midY)
        let h = Float(initialBBox.height)
        let r = Float(initialBBox.width / initialBBox.height)
        
        self.x = [cx, cy, r, h, 0, 0, 0, 0]
        
        // Initialize Covariance P (Uncertainty)
        // High uncertainty for velocities initially
        self.P = KalmanFilter.identity(size: 8, scale: 10.0)
        for i in 4..<8 { self.P[i][i] = 1000.0 }
        
        // F: State Transition (Constant Velocity Model)
        // x' = x + v
        var f = KalmanFilter.identity(size: 8, scale: 1.0)
        for i in 0..<4 { f[i][i+4] = 1.0 }
        self.F = f
        
        // H: Measurement Matrix (We measure first 4 components)
        var hMat = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 4)
        for i in 0..<4 { hMat[i][i] = 1.0 }
        self.H = hMat
        
        // Q: Process Noise (Uncertainty in model)
        // Small position noise, larger velocity noise
        var q = KalmanFilter.identity(size: 8, scale: 1.0)
        for i in 0..<4 { q[i][i] = 0.01 } // Position noise
        for i in 4..<8 { q[i][i] = 0.1 }  // Velocity noise
        self.Q = q
        
        // R: Measurement Noise (Uncertainty in detection)
        // Depends on detector quality.
        var rMat = KalmanFilter.identity(size: 4, scale: 1.0)
        for i in 0..<4 { rMat[i][i] = 0.1 } // Detection noise
        self.R = rMat
    }
    
    func predict() {
        // x = F * x
        x = KalmanFilter.multiply(matrix: F, vector: x)
        
        // P = F * P * F^T + Q
        let FP = KalmanFilter.multiply(matrix: F, matrix: P)
        let FT = KalmanFilter.transpose(matrix: F)
        let FPF_T = KalmanFilter.multiply(matrix: FP, matrix: FT)
        P = KalmanFilter.add(matrix: FPF_T, matrix: Q)
    }
    
    func update(measurementBBox: CGRect) {
        // z: Measurement vector
        let cx = Float(measurementBBox.midX)
        let cy = Float(measurementBBox.midY)
        let h = Float(measurementBBox.height)
        let r = Float(measurementBBox.width / measurementBBox.height)
        let z = [cx, cy, r, h]
        
        // y = z - H * x (Innovation)
        let Hx = KalmanFilter.multiply(matrix: H, vector: x)
        let y = KalmanFilter.subtract(vector: z, vector: Hx)
        
        // S = H * P * H^T + R (Innovation Covariance)
        let HP = KalmanFilter.multiply(matrix: H, matrix: P)
        let HT = KalmanFilter.transpose(matrix: H)
        let HPH_T = KalmanFilter.multiply(matrix: HP, matrix: HT)
        let S = KalmanFilter.add(matrix: HPH_T, matrix: R)
        
        // K = P * H^T * S^-1 (Kalman Gain)
        // Note: Inverting 4x4 matrix S is simplified here or we use a solver.
        // For simplicity in this mobile implementation without external math libs,
        // we will use a simplified update or diagonal assumption if full inversion is too complex.
        // However, 4x4 inversion is manageable.
        
        guard let S_inv = KalmanFilter.invert4x4(matrix: S) else { return }
        
        let PHT = KalmanFilter.multiply(matrix: P, matrix: HT)
        let K = KalmanFilter.multiply(matrix: PHT, matrix: S_inv)
        
        // x = x + K * y
        let Ky = KalmanFilter.multiply(matrix: K, vector: y)
        x = KalmanFilter.add(vector: x, vector: Ky)
        
        // P = (I - K * H) * P
        let KH = KalmanFilter.multiply(matrix: K, matrix: H)
        let I = KalmanFilter.identity(size: 8, scale: 1.0)
        let I_KH = KalmanFilter.subtract(matrix: I, matrix: KH)
        P = KalmanFilter.multiply(matrix: I_KH, matrix: P)
    }
    
    var currentState: CGRect {
        let cx = CGFloat(x[0])
        let cy = CGFloat(x[1])
        let r = CGFloat(x[2])
        let h = CGFloat(x[3])
        let w = h * r
        
        return CGRect(x: cx - w/2, y: cy - h/2, width: w, height: h)
    }
    
    // MARK: - Matrix Helpers (Simple implementation for standalone usage)
    
    private static func identity(size: Int, scale: Float) -> [[Float]] {
        var m = [[Float]](repeating: [Float](repeating: 0, count: size), count: size)
        for i in 0..<size { m[i][i] = scale }
        return m
    }
    
    private static func multiply(matrix: [[Float]], vector: [Float]) -> [Float] {
        let rows = matrix.count
        let cols = matrix[0].count
        var result = [Float](repeating: 0, count: rows)
        for i in 0..<rows {
            var sum: Float = 0
            for j in 0..<cols {
                sum += matrix[i][j] * vector[j]
            }
            result[i] = sum
        }
        return result
    }
    
    private static func multiply(matrix A: [[Float]], matrix B: [[Float]]) -> [[Float]] {
        let rowsA = A.count
        let colsA = A[0].count
        let colsB = B[0].count
        var result = [[Float]](repeating: [Float](repeating: 0, count: colsB), count: rowsA)
        
        for i in 0..<rowsA {
            for j in 0..<colsB {
                var sum: Float = 0
                for k in 0..<colsA {
                    sum += A[i][k] * B[k][j]
                }
                result[i][j] = sum
            }
        }
        return result
    }
    
    private static func add(matrix A: [[Float]], matrix B: [[Float]]) -> [[Float]] {
        let size = A.count
        var result = A
        for i in 0..<size {
            for j in 0..<size {
                result[i][j] += B[i][j]
            }
        }
        return result
    }
    
    private static func subtract(matrix A: [[Float]], matrix B: [[Float]]) -> [[Float]] {
        let size = A.count
        var result = A
        for i in 0..<size {
            for j in 0..<size {
                result[i][j] -= B[i][j]
            }
        }
        return result
    }
    
    private static func add(vector A: [Float], vector B: [Float]) -> [Float] {
        var result = A
        for i in 0..<A.count { result[i] += B[i] }
        return result
    }
    
    private static func subtract(vector A: [Float], vector B: [Float]) -> [Float] {
        var result = A
        for i in 0..<A.count { result[i] -= B[i] }
        return result
    }
    
    private static func transpose(matrix: [[Float]]) -> [[Float]] {
        let rows = matrix.count
        let cols = matrix[0].count
        var result = [[Float]](repeating: [Float](repeating: 0, count: rows), count: cols)
        for i in 0..<rows {
            for j in 0..<cols {
                result[j][i] = matrix[i][j]
            }
        }
        return result
    }
    
    // Simplified 4x4 Inversion (Cramer's rule or similar is too verbose, using a simplified approximation for diagonal dominance or small matrices)
    // For a robust implementation, we'd use Accelerate framework, but keeping it pure Swift for portability/simplicity in this snippet.
    // Since R is diagonal and HPH' is likely symmetric positive definite, we can use a simpler method.
    // For this specific use case (tracking), we can assume independence if needed, but let's try a basic Gauss-Jordan for 4x4.
    private static func invert4x4(matrix: [[Float]]) -> [[Float]]? {
        let n = 4
        var m = matrix
        var inv = identity(size: n, scale: 1.0)
        
        for i in 0..<n {
            var pivot = m[i][i]
            if abs(pivot) < 1e-6 { return nil } // Singular
            
            for j in 0..<n {
                m[i][j] /= pivot
                inv[i][j] /= pivot
            }
            
            for k in 0..<n {
                if k != i {
                    let factor = m[k][i]
                    for j in 0..<n {
                        m[k][j] -= factor * m[i][j]
                        inv[k][j] -= factor * inv[i][j]
                    }
                }
            }
        }
        return inv
    }
}
