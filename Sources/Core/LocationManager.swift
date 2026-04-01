public struct LocationManager {
    public static func startTracking() {
        print("Location tracking started")
    }
    
    public static func stopTracking() {
        print("Location tracking stopped")
    }
    
    public static func getCurrentLocation() -> (latitude: Double, longitude: Double)? {
        return (latitude: 37.7749, longitude: -122.4194)
    }
}
